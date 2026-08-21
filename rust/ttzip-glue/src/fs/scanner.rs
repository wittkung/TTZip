// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Parallel filesystem directory scanner with Rayon work-stealing and 64-sharded cycle detector.

use parking_lot::RwLock;
use rayon::prelude::*;
use std::collections::HashSet;
use std::fs;
use std::os::unix::fs::MetadataExt;
use std::path::Path;

use crate::fs::apfs::is_mac_junk_file;

const SHARD_COUNT: usize = 64;

/// 64-sharded lock-free/low-contention (dev, inode) cycle detector to prevent infinite loops.
pub struct CycleDetector {
    shards: [RwLock<HashSet<(u64, u64)>>; SHARD_COUNT],
}

impl Default for CycleDetector {
    fn default() -> Self {
        Self::new()
    }
}

impl CycleDetector {
    /// Creates a new 64-sharded cycle detector.
    pub fn new() -> Self {
        Self {
            shards: std::array::from_fn(|_| RwLock::new(HashSet::with_capacity(128))),
        }
    }

    #[inline]
    fn shard_index(dev: u64, ino: u64) -> usize {
        let h = dev.wrapping_mul(0x9E3779B97F4A7C15) ^ ino.wrapping_mul(0x517CC1B727220A95);
        ((h >> 58) as usize) & (SHARD_COUNT - 1)
    }

    /// Attempts to record a (dev, ino) pair. Returns true if first visit, false if cycle detected.
    pub fn visit(&self, dev: u64, ino: u64) -> bool {
        let idx = Self::shard_index(dev, ino);
        let mut shard = self.shards[idx].write();
        shard.insert((dev, ino))
    }
}

/// Configuration options for parallel directory scanning.
#[derive(Debug, Clone)]
pub struct ScanOptions {
    pub include_hidden: bool,
    pub skip_mac_junk: bool,
    pub max_depth: u32,
    pub thread_budget: u32,
}

impl Default for ScanOptions {
    fn default() -> Self {
        Self {
            include_hidden: false,
            skip_mac_junk: true,
            max_depth: 0,
            thread_budget: 0,
        }
    }
}

/// Discovered filesystem entry ready for archive packaging or statistics calculation.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ScannedFsItem {
    pub src_path: String,
    pub rel_path: String,
    pub file_size: u64,
    pub mtime_epoch_secs: i64,
    pub mode: u32,
    pub is_directory: bool,
}

/// Scans a root path recursively using Rayon parallel work-stealing.
pub fn scan_directory_parallel(root_path: &Path, options: &ScanOptions) -> Vec<ScannedFsItem> {
    let detector = CycleDetector::new();
    let root_canon = match root_path.canonicalize() {
        Ok(p) => p,
        Err(_) => root_path.to_path_buf(),
    };

    let meta = match fs::symlink_metadata(&root_canon) {
        Ok(m) => m,
        Err(_) => return Vec::new(),
    };

    let base_name = match root_path.file_name() {
        Some(n) => n.to_string_lossy().to_string(),
        None => root_canon.file_name().map(|n| n.to_string_lossy().to_string()).unwrap_or_else(|| "root".to_string()),
    };

    if options.skip_mac_junk && is_mac_junk_file(&base_name) {
        return Vec::new();
    }

    if meta.is_dir() {
        detector.visit(meta.dev(), meta.ino());
        let root_item = ScannedFsItem {
            src_path: root_canon.to_string_lossy().to_string(),
            rel_path: base_name.clone(),
            file_size: 0,
            mtime_epoch_secs: meta.mtime(),
            mode: meta.mode(),
            is_directory: true,
        };

        let mut results = vec![root_item];
        let sub_items = scan_dir_recursive_parallel(&root_canon, &base_name, 1, options, &detector);
        results.extend(sub_items);
        results
    } else {
        vec![ScannedFsItem {
            src_path: root_canon.to_string_lossy().to_string(),
            rel_path: base_name,
            file_size: meta.len(),
            mtime_epoch_secs: meta.mtime(),
            mode: meta.mode(),
            is_directory: false,
        }]
    }
}

fn scan_dir_recursive_parallel(
    dir_path: &Path,
    rel_prefix: &str,
    current_depth: u32,
    options: &ScanOptions,
    detector: &CycleDetector,
) -> Vec<ScannedFsItem> {
    if options.max_depth > 0 && current_depth > options.max_depth {
        return Vec::new();
    }

    let entries = match fs::read_dir(dir_path) {
        Ok(rd) => rd,
        Err(_) => return Vec::new(),
    };

    let mut direct_files = Vec::with_capacity(32);
    let mut sub_dirs = Vec::with_capacity(16);

    for entry in entries.flatten() {
        let file_name = entry.file_name().to_string_lossy().to_string();
        if !options.include_hidden && file_name.starts_with('.') {
            continue;
        }
        if options.skip_mac_junk && is_mac_junk_file(&file_name) {
            continue;
        }

        let entry_path = entry.path();
        let meta = match entry.metadata() {
            Ok(m) => m,
            Err(_) => continue,
        };

        let rel_path = if rel_prefix.is_empty() {
            file_name.clone()
        } else {
            format!("{}/{}", rel_prefix, file_name)
        };

        if meta.is_dir() {
            if detector.visit(meta.dev(), meta.ino()) {
                direct_files.push(ScannedFsItem {
                    src_path: entry_path.to_string_lossy().to_string(),
                    rel_path: rel_path.clone(),
                    file_size: 0,
                    mtime_epoch_secs: meta.mtime(),
                    mode: meta.mode(),
                    is_directory: true,
                });
                sub_dirs.push((entry_path, rel_path));
            }
        } else {
            direct_files.push(ScannedFsItem {
                src_path: entry_path.to_string_lossy().to_string(),
                rel_path,
                file_size: meta.len(),
                mtime_epoch_secs: meta.mtime(),
                mode: meta.mode(),
                is_directory: false,
            });
        }
    }

    let recursive_sub_items: Vec<ScannedFsItem> = sub_dirs
        .into_par_iter()
        .flat_map(|(sub_path, sub_rel)| {
            scan_dir_recursive_parallel(&sub_path, &sub_rel, current_depth + 1, options, detector)
        })
        .collect();

    direct_files.extend(recursive_sub_items);
    direct_files
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    #[test]
    fn test_cycle_detector_sharding() {
        let detector = CycleDetector::new();
        assert!(detector.visit(1, 100));
        assert!(!detector.visit(1, 100));
        assert!(detector.visit(1, 101));
        assert!(detector.visit(2, 100));
    }

    #[test]
    fn test_parallel_directory_scanner() {
        let dir = tempdir().unwrap();
        let root = dir.path();

        fs::create_dir_all(root.join("sub1/sub2")).unwrap();
        fs::write(root.join("file1.txt"), b"hello").unwrap();
        fs::write(root.join("sub1/file2.txt"), b"world!").unwrap();
        fs::write(root.join("sub1/sub2/file3.txt"), b"deep").unwrap();
        fs::write(root.join(".hidden"), b"secret").unwrap();
        fs::write(root.join(".DS_Store"), b"junk").unwrap();

        let default_opts = ScanOptions::default();
        let items = scan_directory_parallel(root, &default_opts);
        assert!(!items.iter().any(|i| i.rel_path.contains(".DS_Store")));
        assert!(!items.iter().any(|i| i.rel_path.contains(".hidden")));
        assert!(items.iter().any(|i| i.rel_path.ends_with("file1.txt")));
        assert!(items.iter().any(|i| i.rel_path.ends_with("file2.txt")));
        assert!(items.iter().any(|i| i.rel_path.ends_with("file3.txt")));

        let mut hidden_opts = ScanOptions::default();
        hidden_opts.include_hidden = true;
        let items_hidden = scan_directory_parallel(root, &hidden_opts);
        assert!(items_hidden.iter().any(|i| i.rel_path.ends_with(".hidden")));

        let mut depth_opts = ScanOptions::default();
        depth_opts.max_depth = 1;
        let items_depth = scan_directory_parallel(root, &depth_opts);
        assert!(!items_depth.iter().any(|i| i.rel_path.ends_with("file3.txt")));
    }
}
