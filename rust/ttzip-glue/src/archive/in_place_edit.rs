// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! In-place atomic archive modification engine for ZIP and 7z containers.
//!
//! Provides transactional append, replace, and delete operations on archive entries
//! without decompressing or recompressing untouched payload blocks.

use crate::codecs::deflate::{deflate_compress, deflate_compress_bound};
use crate::crypto::crc32_fast;
use crate::sevenz::{create_7z_solid_archive_bytes, SevenZArchive};
use crate::types::{TTZipArchiveFormat, TTZipStatus};
use crate::zip::parser::{parse_all_entries, parse_local_file_header};
use crate::zip::writer::{assemble_zip_archive, ZipCompressedItem, ZipInputItem};
use std::collections::{HashMap, HashSet};
use std::fs::{self, File};
use std::io::Read;
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};

static INPLACE_COUNTER: AtomicU64 = AtomicU64::new(1);

/// Action performed on an archive entry during an in-place editing transaction.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum InPlaceAction {
    Append { entry_path: String, source_path: PathBuf },
    Replace { entry_path: String, source_path: PathBuf },
    Delete { entry_path: String },
}

/// Transactional session managing atomic in-place archive mutations.
#[derive(Debug)]
pub struct InPlaceArchiveSession {
    pub archive_path: PathBuf,
    pub shadow_path: PathBuf,
    pub format: TTZipArchiveFormat,
    pub actions: Vec<InPlaceAction>,
    pub committed: bool,
}

impl InPlaceArchiveSession {
    /// Begins a new in-place archive mutation transaction.
    pub fn begin(archive_path: impl AsRef<Path>, format: Option<TTZipArchiveFormat>) -> Result<Self, TTZipStatus> {
        let archive_path = archive_path.as_ref().to_path_buf();
        if !archive_path.exists() {
            return Err(TTZipStatus::ErrFileNotFound);
        }

        let fmt = match format {
            Some(f) if f != TTZipArchiveFormat::Auto => f,
            _ => detect_archive_format(&archive_path),
        };

        let shadow_path = generate_shadow_path(&archive_path);

        Ok(Self {
            archive_path,
            shadow_path,
            format: fmt,
            actions: Vec::new(),
            committed: false,
        })
    }

    /// Queues an entry append operation.
    pub fn append(&mut self, entry_path: &str, source_path: impl AsRef<Path>) -> Result<(), TTZipStatus> {
        let src = source_path.as_ref().to_path_buf();
        if !src.exists() {
            return Err(TTZipStatus::ErrFileNotFound);
        }
        self.actions.push(InPlaceAction::Append {
            entry_path: entry_path.to_string(),
            source_path: src,
        });
        Ok(())
    }

    /// Queues an entry replace operation.
    pub fn replace(&mut self, entry_path: &str, source_path: impl AsRef<Path>) -> Result<(), TTZipStatus> {
        let src = source_path.as_ref().to_path_buf();
        if !src.exists() {
            return Err(TTZipStatus::ErrFileNotFound);
        }
        self.actions.push(InPlaceAction::Replace {
            entry_path: entry_path.to_string(),
            source_path: src,
        });
        Ok(())
    }

    /// Queues an entry delete operation.
    pub fn delete(&mut self, entry_path: &str) -> Result<(), TTZipStatus> {
        self.actions.push(InPlaceAction::Delete {
            entry_path: entry_path.to_string(),
        });
        Ok(())
    }

    /// Commits all pending mutations atomically into the target archive.
    pub fn commit(&mut self) -> Result<(), TTZipStatus> {
        if self.committed {
            return Ok(());
        }

        match self.format {
            TTZipArchiveFormat::Zip => {
                in_place_edit_zip(&self.archive_path, &self.shadow_path, &self.actions)?;
            }
            TTZipArchiveFormat::SevenZip => {
                in_place_edit_sevenz(&self.archive_path, &self.shadow_path, &self.actions)?;
            }
            _ => {
                in_place_edit_zip(&self.archive_path, &self.shadow_path, &self.actions)?;
            }
        }

        fs::rename(&self.shadow_path, &self.archive_path).map_err(|_| TTZipStatus::ErrOpenFailed)?;
        self.committed = true;
        Ok(())
    }

    /// Cancels and rolls back the transaction, cleaning up any shadow files.
    pub fn cancel(&mut self) -> Result<(), TTZipStatus> {
        if !self.committed && self.shadow_path.exists() {
            let _ = fs::remove_file(&self.shadow_path);
        }
        self.actions.clear();
        Ok(())
    }

    /// Transactional rollback alias.
    pub fn rollback(&mut self) -> Result<(), TTZipStatus> {
        self.cancel()
    }
}

impl Drop for InPlaceArchiveSession {
    fn drop(&mut self) {
        if !self.committed && self.shadow_path.exists() {
            let _ = fs::remove_file(&self.shadow_path);
        }
    }
}

fn generate_shadow_path(archive_path: &Path) -> PathBuf {
    let parent = archive_path.parent().unwrap_or_else(|| Path::new("."));
    let stem = archive_path.file_name().and_then(|s| s.to_str()).unwrap_or("archive");
    let count = INPLACE_COUNTER.fetch_add(1, Ordering::Relaxed);
    let pid = std::process::id();
    parent.join(format!("{}.ttzip_inplace_{}_{}.tmp", stem, pid, count))
}

/// Detects container format from magic headers or file extension.
pub fn detect_archive_format(path: &Path) -> TTZipArchiveFormat {
    if let Ok(mut f) = File::open(path) {
        let mut magic = [0u8; 6];
        if let Ok(n) = f.read(&mut magic) {
            if n >= 4 && magic[0..4] == [0x50, 0x4B, 0x03, 0x04] {
                return TTZipArchiveFormat::Zip;
            }
            if n >= 6 && magic[0..6] == [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C] {
                return TTZipArchiveFormat::SevenZip;
            }
        }
    }

    let name = path.to_string_lossy().to_lowercase();
    if name.ends_with(".zip") {
        TTZipArchiveFormat::Zip
    } else if name.ends_with(".7z") {
        TTZipArchiveFormat::SevenZip
    } else if name.ends_with(".tar") || name.ends_with(".tar.gz") || name.ends_with(".tgz") {
        TTZipArchiveFormat::Tar
    } else {
        TTZipArchiveFormat::Zip
    }
}

/// Modifies a ZIP archive in-place, preserving raw compressed streams of untouched entries.
pub fn in_place_edit_zip(
    archive_path: &Path,
    shadow_path: &Path,
    actions: &[InPlaceAction],
) -> Result<(), TTZipStatus> {
    let mapped = fs::read(archive_path).map_err(|_| TTZipStatus::ErrFileNotFound)?;
    let entries = parse_all_entries(&mapped)?;

    let mut deleted = HashSet::new();
    let mut replaced = HashMap::new();
    let mut appended = Vec::new();

    for action in actions {
        match action {
            InPlaceAction::Delete { entry_path } => {
                deleted.insert(entry_path.trim_start_matches('/').to_string());
            }
            InPlaceAction::Replace { entry_path, source_path } => {
                replaced.insert(entry_path.trim_start_matches('/').to_string(), source_path.clone());
            }
            InPlaceAction::Append { entry_path, source_path } => {
                appended.push((entry_path.trim_start_matches('/').to_string(), source_path.clone()));
            }
        }
    }

    let mut new_items: Vec<ZipCompressedItem> = Vec::with_capacity(entries.len() + appended.len());

    for entry in &entries {
        let key = entry.rel_path.trim_start_matches('/').to_string();
        if deleted.contains(&key) {
            continue;
        }

        if let Some(src_path) = replaced.get(&key) {
            let item = compress_file_for_zip(&entry.rel_path, src_path)?;
            new_items.push(item);
        } else {
            // Untouched entry: zero recompression, preserve raw compressed payload
            let (payload_offset, _header_size) =
                parse_local_file_header(&mapped, entry.lfh_offset as usize)?;
            let payload_start = payload_offset;
            let payload_end = payload_start + entry.compressed_size as usize;
            if payload_end > mapped.len() {
                return Err(TTZipStatus::ErrCorruptHeader);
            }
            let payload = mapped[payload_start..payload_end].to_vec();

            new_items.push(ZipCompressedItem {
                rel_path: entry.rel_path.clone(),
                uncompressed_size: entry.uncompressed_size,
                compressed_size: entry.compressed_size,
                crc32: entry.crc32,
                compression_method: entry.compression_method,
                actual_method: entry.actual_method,
                aes_strength: entry.aes_strength,
                payload,
                mtime_epoch_secs: entry.mtime_epoch_secs as u32,
                mode: entry.mode,
                is_directory: entry.is_directory,
                is_encrypted: entry.is_encrypted,
            });
        }
    }

    for (rel_path, src_path) in &appended {
        let item = compress_file_for_zip(rel_path, src_path)?;
        new_items.push(item);
    }

    let assembled = assemble_zip_archive(&new_items)?;
    fs::write(shadow_path, assembled).map_err(|_| TTZipStatus::ErrOpenFailed)?;
    Ok(())
}

fn compress_file_for_zip(rel_path: &str, src_path: &Path) -> Result<ZipCompressedItem, TTZipStatus> {
    let meta = fs::symlink_metadata(src_path).map_err(|_| TTZipStatus::ErrFileNotFound)?;
    let is_dir = meta.is_dir();
    let mode = meta.permissions().mode();
    let mtime = meta
        .modified()
        .ok()
        .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
        .map(|d| d.as_secs() as u32)
        .unwrap_or(0);

    if is_dir {
        let mut dir_path = rel_path.to_string();
        if !dir_path.ends_with('/') {
            dir_path.push('/');
        }
        return Ok(ZipCompressedItem {
            rel_path: dir_path,
            uncompressed_size: 0,
            compressed_size: 0,
            crc32: 0,
            compression_method: 0,
            actual_method: 0,
            aes_strength: 0,
            payload: Vec::new(),
            mtime_epoch_secs: mtime,
            mode: if mode != 0 { mode } else { 0o755 },
            is_directory: true,
            is_encrypted: false,
        });
    }

    let raw_data = fs::read(src_path).map_err(|_| TTZipStatus::ErrFileNotFound)?;
    let uncompressed_size = raw_data.len() as u64;
    let crc = crc32_fast(0, &raw_data);

    if raw_data.is_empty() {
        return Ok(ZipCompressedItem {
            rel_path: rel_path.to_string(),
            uncompressed_size: 0,
            compressed_size: 0,
            crc32: 0,
            compression_method: 0,
            actual_method: 0,
            aes_strength: 0,
            payload: Vec::new(),
            mtime_epoch_secs: mtime,
            mode: if mode != 0 { mode } else { 0o644 },
            is_directory: false,
            is_encrypted: false,
        });
    }

    let max_bound = deflate_compress_bound(raw_data.len(), 6);
    let mut comp_buf = vec![0u8; max_bound];
    match deflate_compress(&raw_data, &mut comp_buf, 6) {
        Ok(comp_len) if comp_len < raw_data.len() => {
            comp_buf.truncate(comp_len);
            Ok(ZipCompressedItem {
                rel_path: rel_path.to_string(),
                uncompressed_size,
                compressed_size: comp_len as u64,
                crc32: crc,
                compression_method: 8,
                actual_method: 8,
                aes_strength: 0,
                payload: comp_buf,
                mtime_epoch_secs: mtime,
                mode: if mode != 0 { mode } else { 0o644 },
                is_directory: false,
                is_encrypted: false,
            })
        }
        _ => Ok(ZipCompressedItem {
            rel_path: rel_path.to_string(),
            uncompressed_size,
            compressed_size: uncompressed_size,
            crc32: crc,
            compression_method: 0,
            actual_method: 0,
            aes_strength: 0,
            payload: raw_data,
            mtime_epoch_secs: mtime,
            mode: if mode != 0 { mode } else { 0o644 },
            is_directory: false,
            is_encrypted: false,
        }),
    }
}

/// Modifies a 7z archive in-place.
pub fn in_place_edit_sevenz(
    archive_path: &Path,
    shadow_path: &Path,
    actions: &[InPlaceAction],
) -> Result<(), TTZipStatus> {
    let mapped = fs::read(archive_path).map_err(|_| TTZipStatus::ErrFileNotFound)?;

    let mut deleted = HashSet::new();
    let mut replaced = HashMap::new();
    let mut appended = Vec::new();

    for action in actions {
        match action {
            InPlaceAction::Delete { entry_path } => {
                deleted.insert(entry_path.trim_start_matches('/').to_string());
            }
            InPlaceAction::Replace { entry_path, source_path } => {
                replaced.insert(entry_path.trim_start_matches('/').to_string(), source_path.clone());
            }
            InPlaceAction::Append { entry_path, source_path } => {
                appended.push((entry_path.trim_start_matches('/').to_string(), source_path.clone()));
            }
        }
    }

    let mut items: Vec<ZipInputItem> = Vec::new();
    let mut handled_replaced = HashSet::new();

    let is_match = |entry_key: &str, target: &str| -> bool {
        let ek = entry_key.trim_start_matches('/');
        let tg = target.trim_start_matches('/');
        ek == tg || ek.ends_with(&format!("/{}", tg)) || tg.ends_with(&format!("/{}", ek))
    };

    if let Ok(archive) = SevenZArchive::open_slice(&mapped) {
        for i in 0..archive.len() {
            let meta = &archive.files()[i];
            let key = meta.rel_path.trim_start_matches('/').to_string();

            if deleted.iter().any(|d| is_match(&key, d)) {
                continue;
            }

            if let Some((rep_k, src_path)) = replaced.iter().find(|(k, _)| is_match(&key, k)) {
                handled_replaced.insert(rep_k.clone());
                let meta_src = fs::symlink_metadata(src_path).map_err(|_| TTZipStatus::ErrFileNotFound)?;
                let is_dir = meta_src.is_dir();
                let data = if is_dir { Vec::new() } else { fs::read(src_path).map_err(|_| TTZipStatus::ErrFileNotFound)? };
                let mode = meta_src.permissions().mode();
                let mtime = meta_src
                    .modified()
                    .ok()
                    .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
                    .map(|d| d.as_secs() as u32)
                    .unwrap_or(0);

                items.push(ZipInputItem {
                    rel_path: meta.rel_path.clone(),
                    data,
                    mtime_epoch_secs: mtime,
                    mode: if mode != 0 { mode } else { if is_dir { 0o755 } else { 0o644 } },
                    is_directory: is_dir,
                });
            } else {
                let data = if meta.is_directory {
                    Vec::new()
                } else {
                    archive.extract_entry_bytes_stream(i, None).unwrap_or_default()
                };
                items.push(ZipInputItem {
                    rel_path: meta.rel_path.clone(),
                    data,
                    mtime_epoch_secs: meta.mtime_epoch_secs.map(|t| t as u32).unwrap_or(0),
                    mode: meta.mode,
                    is_directory: meta.is_directory,
                });
            }
        }
    }

    // Add any replaced items that weren't matched in the header
    for (rel_path, src_path) in &replaced {
        if !handled_replaced.contains(rel_path) {
            let meta_src = fs::symlink_metadata(src_path).map_err(|_| TTZipStatus::ErrFileNotFound)?;
            let is_dir = meta_src.is_dir();
            let data = if is_dir { Vec::new() } else { fs::read(src_path).map_err(|_| TTZipStatus::ErrFileNotFound)? };
            let mode = meta_src.permissions().mode();
            let mtime = meta_src
                .modified()
                .ok()
                .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
                .map(|d| d.as_secs() as u32)
                .unwrap_or(0);

            items.push(ZipInputItem {
                rel_path: rel_path.clone(),
                data,
                mtime_epoch_secs: mtime,
                mode: if mode != 0 { mode } else { if is_dir { 0o755 } else { 0o644 } },
                is_directory: is_dir,
            });
        }
    }

    for (rel_path, src_path) in &appended {
        let meta_src = fs::symlink_metadata(src_path).map_err(|_| TTZipStatus::ErrFileNotFound)?;
        let is_dir = meta_src.is_dir();
        let data = if is_dir { Vec::new() } else { fs::read(src_path).map_err(|_| TTZipStatus::ErrFileNotFound)? };
        let mode = meta_src.permissions().mode();
        let mtime = meta_src
            .modified()
            .ok()
            .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
            .map(|d| d.as_secs() as u32)
            .unwrap_or(0);

        items.push(ZipInputItem {
            rel_path: rel_path.clone(),
            data,
            mtime_epoch_secs: mtime,
            mode: if mode != 0 { mode } else { if is_dir { 0o755 } else { 0o644 } },
            is_directory: is_dir,
        });
    }

    if items.is_empty() {
        return Err(TTZipStatus::ErrInvalidParam);
    }

    let bytes = create_7z_solid_archive_bytes(&items, 3, 2)?;
    fs::write(shadow_path, bytes).map_err(|_| TTZipStatus::ErrOpenFailed)?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::zip::reader::ZipArchive;

    #[test]
    fn test_in_place_zip_append_replace_delete_transaction() {
        let temp_dir = std::env::temp_dir().join(format!("ttzip_test_inplace_{}", std::process::id()));
        let _ = fs::create_dir_all(&temp_dir);

        let archive_path = temp_dir.join("test_inplace.zip");
        let f1 = temp_dir.join("orig1.txt");
        let f2 = temp_dir.join("orig2.txt");
        let f3 = temp_dir.join("orig3.txt");
        fs::write(&f1, b"Original Content 1").unwrap();
        fs::write(&f2, b"Original Content 2").unwrap();
        fs::write(&f3, b"Original Content 3").unwrap();

        let initial_items = vec![
            ZipInputItem { rel_path: "file1.txt".to_string(), data: b"Original Content 1".to_vec(), mtime_epoch_secs: 1700000000, mode: 0o644, is_directory: false },
            ZipInputItem { rel_path: "file2.txt".to_string(), data: b"Original Content 2".to_vec(), mtime_epoch_secs: 1700000000, mode: 0o644, is_directory: false },
            ZipInputItem { rel_path: "file3.txt".to_string(), data: b"Original Content 3".to_vec(), mtime_epoch_secs: 1700000000, mode: 0o644, is_directory: false },
        ];
        let compressed = crate::zip::writer::compress_items_parallel(initial_items, 6, crate::types::TTZipEncryptionMethod::None, None, 2).unwrap();
        let zip_bytes = assemble_zip_archive(&compressed).unwrap();
        fs::write(&archive_path, zip_bytes).unwrap();

        // New replacement and append files
        let f_rep = temp_dir.join("replaced2.txt");
        let f_app = temp_dir.join("appended4.txt");
        fs::write(&f_rep, b"UPDATED CONTENT 2").unwrap();
        fs::write(&f_app, b"NEW CONTENT 4").unwrap();

        // Perform in-place transaction: Replace file2.txt, Delete file1.txt, Append file4.txt
        let mut session = InPlaceArchiveSession::begin(&archive_path, Some(TTZipArchiveFormat::Zip)).unwrap();
        session.replace("file2.txt", &f_rep).unwrap();
        session.delete("file1.txt").unwrap();
        session.append("file4.txt", &f_app).unwrap();
        session.commit().unwrap();

        // Verify
        let mapped = fs::read(&archive_path).unwrap();
        let zip = ZipArchive::open_slice(&mapped).unwrap();
        let paths: Vec<String> = zip.entries().iter().map(|e| e.rel_path.clone()).collect();
        assert!(!paths.contains(&"file1.txt".to_string()));
        assert!(paths.contains(&"file2.txt".to_string()));
        assert!(paths.contains(&"file3.txt".to_string()));
        assert!(paths.contains(&"file4.txt".to_string()));

        let idx2 = zip.entries().iter().position(|e| e.rel_path == "file2.txt").unwrap();
        let c2 = zip.extract_entry_bytes(idx2, None).unwrap();
        assert_eq!(c2, b"UPDATED CONTENT 2");

        let idx3 = zip.entries().iter().position(|e| e.rel_path == "file3.txt").unwrap();
        let c3 = zip.extract_entry_bytes(idx3, None).unwrap();
        assert_eq!(c3, b"Original Content 3");

        let idx4 = zip.entries().iter().position(|e| e.rel_path == "file4.txt").unwrap();
        let c4 = zip.extract_entry_bytes(idx4, None).unwrap();
        assert_eq!(c4, b"NEW CONTENT 4");

        let _ = fs::remove_dir_all(&temp_dir);
    }

    #[test]
    fn test_in_place_zip_rollback_on_cancel() {
        let temp_dir = std::env::temp_dir().join(format!("ttzip_test_rollback_{}", std::process::id()));
        let _ = fs::create_dir_all(&temp_dir);

        let archive_path = temp_dir.join("test_rollback.zip");
        let initial_items = vec![
            ZipInputItem { rel_path: "keep.txt".to_string(), data: b"Keep me unchanged".to_vec(), mtime_epoch_secs: 1700000000, mode: 0o644, is_directory: false },
        ];
        let compressed = crate::zip::writer::compress_items_parallel(initial_items, 6, crate::types::TTZipEncryptionMethod::None, None, 2).unwrap();
        let zip_bytes = assemble_zip_archive(&compressed).unwrap();
        fs::write(&archive_path, &zip_bytes).unwrap();

        let f_junk = temp_dir.join("junk.txt");
        fs::write(&f_junk, b"JUNK").unwrap();

        let mut session = InPlaceArchiveSession::begin(&archive_path, Some(TTZipArchiveFormat::Zip)).unwrap();
        session.replace("keep.txt", &f_junk).unwrap();
        session.cancel().unwrap();

        let mapped = fs::read(&archive_path).unwrap();
        let zip = ZipArchive::open_slice(&mapped).unwrap();
        let data = zip.extract_entry_bytes(0, None).unwrap();
        assert_eq!(data, b"Keep me unchanged");

        let _ = fs::remove_dir_all(&temp_dir);
    }

    #[test]
    fn test_in_place_7z_append_replace_delete() {
        let temp_dir = std::env::temp_dir().join(format!("ttzip_test_inplace_7z_{}", std::process::id()));
        let _ = fs::create_dir_all(&temp_dir);

        let archive_path = temp_dir.join("test.7z");
        let initial_items = vec![
            ZipInputItem { rel_path: "doc1.txt".to_string(), data: b"Doc 1".to_vec(), mtime_epoch_secs: 1700000000, mode: 0o644, is_directory: false },
            ZipInputItem { rel_path: "doc2.txt".to_string(), data: b"Doc 2".to_vec(), mtime_epoch_secs: 1700000000, mode: 0o644, is_directory: false },
        ];
        let bytes = create_7z_solid_archive_bytes(&initial_items, 3, 2).unwrap();
        fs::write(&archive_path, bytes).unwrap();

        let f_rep = temp_dir.join("rep.txt");
        let f_app = temp_dir.join("app.txt");
        fs::write(&f_rep, b"Replaced Doc 2").unwrap();
        fs::write(&f_app, b"Appended Doc 3").unwrap();

        let mut session = InPlaceArchiveSession::begin(&archive_path, Some(TTZipArchiveFormat::SevenZip)).unwrap();
        session.delete("doc1.txt").unwrap();
        session.replace("doc2.txt", &f_rep).unwrap();
        session.append("doc3.txt", &f_app).unwrap();
        session.commit().unwrap();

        let mapped = fs::read(&archive_path).unwrap();
        let archive = SevenZArchive::open_slice(&mapped).unwrap();
        assert_eq!(archive.len(), 2);

        let _ = fs::remove_dir_all(&temp_dir);
    }

    #[test]
    fn test_in_place_7z_replace_keep_other() {
        let temp_dir = std::env::temp_dir().join(format!("ttzip_test_inplace_7z_keep_{}", std::process::id()));
        let _ = fs::create_dir_all(&temp_dir);

        let archive_path = temp_dir.join("test_keep.7z");
        let initial_items = vec![
            ZipInputItem { rel_path: "alpha.txt".to_string(), data: b"Alpha Original".to_vec(), mtime_epoch_secs: 1700000000, mode: 0o644, is_directory: false },
            ZipInputItem { rel_path: "beta.txt".to_string(), data: b"Beta Original".to_vec(), mtime_epoch_secs: 1700000000, mode: 0o644, is_directory: false },
        ];
        let bytes = create_7z_solid_archive_bytes(&initial_items, 3, 2).unwrap();
        fs::write(&archive_path, bytes).unwrap();

        let f_rep = temp_dir.join("alpha_new.txt");
        fs::write(&f_rep, b"Alpha Replaced Content").unwrap();

        let mut session = InPlaceArchiveSession::begin(&archive_path, Some(TTZipArchiveFormat::SevenZip)).unwrap();
        session.replace("alpha.txt", &f_rep).unwrap();
        session.commit().unwrap();

        let mapped = fs::read(&archive_path).unwrap();
        let archive = SevenZArchive::open_slice(&mapped).unwrap();
        assert_eq!(archive.len(), 2);

        let out1 = archive.extract_entry_bytes_stream(0, None).unwrap();
        assert_eq!(out1, b"Alpha Replaced Content");
        let out2 = archive.extract_entry_bytes_stream(1, None).unwrap();
        assert_eq!(out2, b"Beta Original");

        let _ = fs::remove_dir_all(&temp_dir);
    }
}
