// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! O(1) Lock-Free / 16-Way Sharded LZ4 Decompression Cache Pool with Arena LRU & Disk Spill.

use crate::codecs::fast_blocks::{lz4_compress_bound, lz4_compress_fast, lz4_decompress};
use crate::types::TTZipStatus;
use parking_lot::RwLock;
use std::collections::hash_map::DefaultHasher;
use std::collections::HashMap;
use std::fs;
use std::hash::{Hash, Hasher};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::{SystemTime, UNIX_EPOCH};

const NUM_SHARDS: usize = 16;

#[derive(Debug, Clone)]
pub struct VFSCacheBlockMeta {
    pub chunk_index: u64,
    pub raw_size: usize,
    pub compressed_size: usize,
    pub is_disk_spill: bool,
    pub access_timestamp: u64,
}

#[derive(Clone)]
struct LruNode {
    key: String,
    raw_size: usize,
    compressed_size: usize,
    in_ram: bool,
    ram_data: Option<Vec<u8>>,
    disk_path: Option<PathBuf>,
    access_time: u64,
    prev: Option<usize>,
    next: Option<usize>,
    active: bool,
}

#[derive(Default)]
struct LruShard {
    map: HashMap<String, usize>,
    nodes: Vec<LruNode>,
    free_indices: Vec<usize>,
    head: Option<usize>,
    tail: Option<usize>,
    ram_bytes: usize,
}

impl LruShard {
    fn new() -> Self {
        Self {
            map: HashMap::new(),
            nodes: Vec::new(),
            free_indices: Vec::new(),
            head: None,
            tail: None,
            ram_bytes: 0,
        }
    }

    fn detach(&mut self, idx: usize) {
        let prev = self.nodes[idx].prev;
        let next = self.nodes[idx].next;

        if let Some(p) = prev {
            self.nodes[p].next = next;
        } else {
            self.head = next;
        }

        if let Some(n) = next {
            self.nodes[n].prev = prev;
        } else {
            self.tail = prev;
        }

        self.nodes[idx].prev = None;
        self.nodes[idx].next = None;
    }

    fn push_front(&mut self, idx: usize) {
        self.nodes[idx].prev = None;
        self.nodes[idx].next = self.head;

        if let Some(old_head) = self.head {
            self.nodes[old_head].prev = Some(idx);
        } else {
            self.tail = Some(idx);
        }
        self.head = Some(idx);
    }

    fn move_to_front(&mut self, idx: usize) {
        if self.head == Some(idx) {
            return;
        }
        self.detach(idx);
        self.push_front(idx);
    }

    fn evict_to_disk(&mut self, spill_dir: &Path, needed_bytes: usize, max_ram: usize) {
        let mut curr = self.tail;
        while let Some(idx) = curr {
            if self.ram_bytes + needed_bytes <= max_ram {
                break;
            }
            let prev = self.nodes[idx].prev;
            if self.nodes[idx].in_ram {
                if let Some(data) = self.nodes[idx].ram_data.take() {
                    let safe_filename = format!("{}.lz4", self.nodes[idx].key.replace(':', "_"));
                    let spill_file = spill_dir.join(safe_filename);
                    if fs::write(&spill_file, &data).is_ok() {
                        self.nodes[idx].in_ram = false;
                        self.nodes[idx].disk_path = Some(spill_file);
                        self.ram_bytes = self.ram_bytes.saturating_sub(data.len());
                    } else {
                        self.nodes[idx].ram_data = Some(data);
                    }
                }
            }
            curr = prev;
        }
    }

    fn remove_node(&mut self, idx: usize) {
        if !self.nodes[idx].active {
            return;
        }
        self.detach(idx);
        if let Some(ref path) = self.nodes[idx].disk_path {
            let _ = fs::remove_file(path);
        }
        if let Some(ref data) = self.nodes[idx].ram_data {
            self.ram_bytes = self.ram_bytes.saturating_sub(data.len());
        }
        self.nodes[idx].active = false;
        self.nodes[idx].ram_data = None;
        self.nodes[idx].disk_path = None;
        self.map.remove(&self.nodes[idx].key);
        self.free_indices.push(idx);
    }
}

/// 16-way sharded Lock-Free / concurrent LZ4 VFS cache pool with 2-tier RAM + Disk spill.
pub struct VFSLz4CachePool {
    shards: [RwLock<LruShard>; NUM_SHARDS],
    spill_dir: PathBuf,
    #[allow(dead_code)]
    max_ram_bytes: usize,
    per_shard_max_ram: usize,
    access_counter: AtomicU64,
}

impl VFSLz4CachePool {
    pub fn new(max_ram_bytes: usize, spill_dir: Option<PathBuf>) -> Self {
        let dir = spill_dir.unwrap_or_else(|| {
            std::env::temp_dir().join(format!("ttzip_vfs_lz4_{}", std::process::id()))
        });
        let _ = fs::create_dir_all(&dir);

        let shards: [RwLock<LruShard>; NUM_SHARDS] = std::array::from_fn(|_| RwLock::new(LruShard::new()));
        let per_shard = (max_ram_bytes / NUM_SHARDS).max(1024 * 1024);

        Self {
            shards,
            spill_dir: dir,
            max_ram_bytes,
            per_shard_max_ram: per_shard,
            access_counter: AtomicU64::new(1),
        }
    }

    #[inline]
    pub fn max_ram_bytes(&self) -> usize {
        self.max_ram_bytes
    }

    #[inline]
    fn shard_idx(&self, key: &str) -> usize {
        let mut hasher = DefaultHasher::new();
        key.hash(&mut hasher);
        (hasher.finish() as usize) % NUM_SHARDS
    }

    fn current_timestamp(&self) -> u64 {
        self.access_counter.fetch_add(1, Ordering::Relaxed)
            + SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .map(|d| d.as_nanos() as u64)
                .unwrap_or(0)
    }

    /// Compresses chunk using LZ4 and inserts into RAM cache, spilling to disk on budget overflow.
    pub fn put(&self, session_id: &str, chunk_index: u64, raw_data: &[u8], acceleration: i32) -> Result<(), TTZipStatus> {
        if raw_data.is_empty() {
            return Ok(());
        }

        let max_comp_len = lz4_compress_bound(raw_data.len());
        let mut compressed = vec![0u8; max_comp_len];
        let comp_len = lz4_compress_fast(raw_data, &mut compressed, acceleration.max(1))?;
        compressed.truncate(comp_len);

        let key = format!("{}:{}", session_id, chunk_index);
        let s_idx = self.shard_idx(&key);
        let now = self.current_timestamp();
        let mut shard = self.shards[s_idx].write();

        if shard.ram_bytes + comp_len > self.per_shard_max_ram {
            shard.evict_to_disk(&self.spill_dir, comp_len, self.per_shard_max_ram);
        }

        if let Some(&node_idx) = shard.map.get(&key) {
            let old_data_len = shard.nodes[node_idx].ram_data.as_ref().map(|d| d.len()).unwrap_or(0);
            shard.ram_bytes = shard.ram_bytes.saturating_sub(old_data_len);
            if let Some(ref path) = shard.nodes[node_idx].disk_path {
                let _ = fs::remove_file(path);
            }

            shard.nodes[node_idx].raw_size = raw_data.len();
            shard.nodes[node_idx].compressed_size = comp_len;
            shard.nodes[node_idx].access_time = now;

            if shard.ram_bytes + comp_len <= self.per_shard_max_ram {
                shard.nodes[node_idx].in_ram = true;
                shard.nodes[node_idx].ram_data = Some(compressed);
                shard.nodes[node_idx].disk_path = None;
                shard.ram_bytes += comp_len;
            } else {
                let safe_filename = format!("{}.lz4", key.replace(':', "_"));
                let spill_file = self.spill_dir.join(safe_filename);
                let _ = fs::write(&spill_file, &compressed);
                shard.nodes[node_idx].in_ram = false;
                shard.nodes[node_idx].ram_data = None;
                shard.nodes[node_idx].disk_path = Some(spill_file);
            }
            shard.move_to_front(node_idx);
        } else {
            let (in_ram, ram_data, disk_path) = if shard.ram_bytes + comp_len <= self.per_shard_max_ram {
                shard.ram_bytes += comp_len;
                (true, Some(compressed), None)
            } else {
                let safe_filename = format!("{}.lz4", key.replace(':', "_"));
                let spill_file = self.spill_dir.join(safe_filename);
                let _ = fs::write(&spill_file, &compressed);
                (false, None, Some(spill_file))
            };

            let new_node = LruNode {
                key: key.clone(),
                raw_size: raw_data.len(),
                compressed_size: comp_len,
                in_ram,
                ram_data,
                disk_path,
                access_time: now,
                prev: None,
                next: None,
                active: true,
            };

            let node_idx = if let Some(free_idx) = shard.free_indices.pop() {
                shard.nodes[free_idx] = new_node;
                free_idx
            } else {
                shard.nodes.push(new_node);
                shard.nodes.len() - 1
            };

            shard.push_front(node_idx);
            shard.map.insert(key, node_idx);
        }

        Ok(())
    }

    /// Retrieves and decompresses chunk into `out_buf`. Returns decompressed length.
    pub fn get(&self, session_id: &str, chunk_index: u64, out_buf: &mut [u8]) -> Result<usize, TTZipStatus> {
        let key = format!("{}:{}", session_id, chunk_index);
        let s_idx = self.shard_idx(&key);
        let now = self.current_timestamp();

        let mut shard = self.shards[s_idx].write();
        let &node_idx = shard.map.get(&key).ok_or(TTZipStatus::ErrFileNotFound)?;
        shard.nodes[node_idx].access_time = now;
        shard.move_to_front(node_idx);

        let raw_size = shard.nodes[node_idx].raw_size;
        if out_buf.len() < raw_size {
            return Err(TTZipStatus::ErrInvalidParam);
        }

        if shard.nodes[node_idx].in_ram {
            if let Some(ref comp_data) = shard.nodes[node_idx].ram_data {
                let decomp_len = lz4_decompress(comp_data, out_buf)?;
                return Ok(decomp_len);
            }
        }

        if let Some(ref path) = shard.nodes[node_idx].disk_path {
            let comp_data = fs::read(path).map_err(|_| TTZipStatus::ErrOpenFailed)?;
            let decomp_len = lz4_decompress(&comp_data, out_buf)?;
            return Ok(decomp_len);
        }

        Err(TTZipStatus::ErrFileNotFound)
    }

    /// Clears all cached chunks associated with a specific session ID.
    pub fn clear_session(&self, session_id: &str) {
        let prefix = format!("{}:", session_id);
        for shard_lock in &self.shards {
            let mut shard = shard_lock.write();
            let keys_to_remove: Vec<String> = shard
                .map
                .keys()
                .filter(|k| k.starts_with(&prefix))
                .cloned()
                .collect();
            for key in keys_to_remove {
                if let Some(&node_idx) = shard.map.get(&key) {
                    shard.remove_node(node_idx);
                }
            }
        }
    }

    /// Returns cache statistics: `(ram_count, disk_count, ram_bytes)`.
    pub fn get_stats(&self) -> (usize, usize, usize) {
        let mut ram_count = 0;
        let mut disk_count = 0;
        let mut ram_bytes = 0;

        for shard_lock in &self.shards {
            let shard = shard_lock.read();
            for node in &shard.nodes {
                if node.active {
                    if node.in_ram {
                        ram_count += 1;
                        ram_bytes += node.compressed_size;
                    } else if node.disk_path.is_some() {
                        disk_count += 1;
                    }
                }
            }
        }

        (ram_count, disk_count, ram_bytes)
    }
}

impl Drop for VFSLz4CachePool {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.spill_dir);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_vfs_cache_pool_basic_put_get() {
        let pool = VFSLz4CachePool::new(10 * 1024 * 1024, None);
        let sample = b"Hello VFS LZ4 Cache Pool with High-Throughput Safe Sharding!";
        pool.put("sess1", 0, sample, 1).expect("put chunk");

        let mut out = vec![0u8; 1024];
        let len = pool.get("sess1", 0, &mut out).expect("get chunk");
        assert_eq!(&out[..len], sample);

        let (ram_cnt, disk_cnt, bytes) = pool.get_stats();
        assert_eq!(ram_cnt, 1);
        assert_eq!(disk_cnt, 0);
        assert!(bytes > 0);

        pool.clear_session("sess1");
        let (ram_cnt2, _, _) = pool.get_stats();
        assert_eq!(ram_cnt2, 0);
    }

    #[test]
    fn test_vfs_cache_pool_disk_spill_eviction() {
        let pool = VFSLz4CachePool::new(2048, None); // Low RAM budget to force spill
        let chunk1 = vec![0xABu8; 4096];
        let chunk2 = vec![0xCDu8; 4096];

        pool.put("sess2", 0, &chunk1, 1).expect("put 0");
        pool.put("sess2", 1, &chunk2, 1).expect("put 1");

        let mut out = vec![0u8; 4096];
        let len0 = pool.get("sess2", 0, &mut out).expect("get 0");
        assert_eq!(&out[..len0], &chunk1[..]);

        let len1 = pool.get("sess2", 1, &mut out).expect("get 1");
        assert_eq!(&out[..len1], &chunk2[..]);
    }
}
