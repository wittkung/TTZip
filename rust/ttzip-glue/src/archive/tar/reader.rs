// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Zero-copy memory-mapped TAR Archive Reader and safe extraction engine.
//!
//! Provides zero-copy payload slicing, Rayon/multi-core parallel disk extraction,
//! ZipSlip-immune path validation, APFS extent preallocation, and two-stage bottom-up metadata restoration.

use super::scanner::{TarEntry, TarSeekScanner};
use crate::fs::apfs::apfs_preallocate;
use crate::fs::safe_extract::{sanitize_and_validate_path, SafeExtractEngine};
use crate::types::{TTZipExtractOptions, TTZipStatus};
use rayon::prelude::*;
use std::ffi::CString;
use std::fs::{self, File};
use std::io::Write;
use std::os::unix::io::AsRawFd;
use std::path::Path;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::Arc;

/// Extraction report summarizing processed entries and byte counts.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct TarExtractReport {
    pub processed_entries_count: usize,
    pub total_uncompressed_bytes: u64,
    pub duration_ms: u64,
}

/// Zero-copy memory-mapped TAR Archive parser and extractor.
pub struct TarArchive<'a> {
    data: &'a [u8],
    entries: Vec<TarEntry<'a>>,
}

impl<'a> TarArchive<'a> {
    /// Opens and indexes all entries in a TAR archive from an in-memory slice.
    pub fn open_slice(data: &'a [u8]) -> Result<Self, TTZipStatus> {
        let mut scanner = TarSeekScanner::new(data);
        let entries = scanner.scan_all()?;
        Ok(Self { data, entries })
    }

    /// Returns reference to all parsed TAR entry descriptors.
    #[inline]
    pub fn entries(&self) -> &[TarEntry<'a>] {
        &self.entries
    }

    /// Returns the number of entries in the archive.
    #[inline]
    pub fn len(&self) -> usize {
        self.entries.len()
    }

    /// Returns true if the archive contains zero entries.
    #[inline]
    pub fn is_empty(&self) -> bool {
        self.entries.is_empty()
    }

    /// Extracts payload data for an entry zero-copy as a subslice of the underlying archive.
    pub fn extract_entry_bytes(&self, entry_idx: usize) -> Result<&'a [u8], TTZipStatus> {
        let entry = self
            .entries
            .get(entry_idx)
            .ok_or(TTZipStatus::ErrInvalidOffset)?;

        if entry.is_directory || entry.size == 0 {
            return Ok(&[]);
        }

        let start = entry.data_offset;
        let end = start + (entry.size as usize);

        if end > self.data.len() {
            return Err(TTZipStatus::ErrCorruptHeader);
        }

        Ok(&self.data[start..end])
    }

    /// Extracts all archive entries to `dest_dir` with security validation and hardware acceleration.
    pub fn extract_all(
        &self,
        dest_dir: &Path,
        options: &TTZipExtractOptions,
    ) -> Result<TarExtractReport, TTZipStatus> {
        let start_time = std::time::Instant::now();
        fs::create_dir_all(dest_dir).map_err(|_| TTZipStatus::ErrOpenFailed)?;

        let mut engine = SafeExtractEngine::new();
        let mut total_uncomp_bytes = 0u64;

        // Stage 1: Register all entries with SafeExtractEngine & create directories
        for entry in &self.entries {
            total_uncomp_bytes += entry.size;
            let safe_path = sanitize_and_validate_path(dest_dir, &entry.path)?;

            engine.register_entry(
                safe_path.clone(),
                entry.mode,
                entry.mtime_epoch_secs,
                entry.mtime_nanos,
                entry.is_directory,
            );

            if entry.is_directory {
                fs::create_dir_all(&safe_path).map_err(|_| TTZipStatus::ErrExtractionFailed)?;
            }
        }

        if options.dry_run {
            return Ok(TarExtractReport {
                processed_entries_count: self.entries.len(),
                total_uncompressed_bytes: total_uncomp_bytes,
                duration_ms: start_time.elapsed().as_millis() as u64,
            });
        }

        // Collect non-directory file indices
        let file_indices: Vec<usize> = self
            .entries
            .iter()
            .enumerate()
            .filter(|(_, e)| !e.is_directory)
            .map(|(i, _)| i)
            .collect();

        let thread_budget = (options.thread_budget as usize).clamp(1, 64);
        let processed_bytes = Arc::new(AtomicU64::new(0));
        let cancel_flag = Arc::new(AtomicBool::new(false));

        if thread_budget <= 1 || file_indices.len() <= 4 {
            // Single-threaded path
            for &idx in &file_indices {
                let entry = &self.entries[idx];
                let safe_path = sanitize_and_validate_path(dest_dir, &entry.path)?;

                if entry.is_symlink {
                    if let Some(target) = &entry.link_target {
                        if let Some(parent) = safe_path.parent() {
                            let _ = fs::create_dir_all(parent);
                        }
                        if safe_path.exists() || fs::symlink_metadata(&safe_path).is_ok() {
                            let _ = fs::remove_file(&safe_path);
                        }
                        let _ = std::os::unix::fs::symlink(target.as_ref(), &safe_path);
                    }
                } else {
                    if let Some(parent) = safe_path.parent() {
                        let _ = fs::create_dir_all(parent);
                    }

                    let payload = self.extract_entry_bytes(idx)?;
                    let mut file = File::create(&safe_path).map_err(|_| TTZipStatus::ErrExtractionFailed)?;
                    if entry.size > 0 {
                        let _ = apfs_preallocate(file.as_raw_fd(), entry.size as i64);
                        file.write_all(payload).map_err(|_| TTZipStatus::ErrExtractionFailed)?;
                    }
                }

                let current_done = processed_bytes.fetch_add(entry.size, Ordering::Relaxed) + entry.size;
                if let Some(cb) = options.progress_callback {
                    let c_path = CString::new(entry.path.as_ref()).unwrap_or_default();
                    let should_continue = unsafe {
                        cb(current_done, total_uncomp_bytes, c_path.as_ptr(), options.user_data)
                    };
                    if !should_continue {
                        return Err(TTZipStatus::Cancelled);
                    }
                }
            }
        } else {
            // Rayon multi-core parallel extraction
            let pool = rayon::ThreadPoolBuilder::new()
                .num_threads(thread_budget)
                .build()
                .map_err(|_| TTZipStatus::ErrArchiveInitFailed)?;

            let par_res = pool.install(|| {
                file_indices.par_iter().try_for_each(|&idx| -> Result<(), TTZipStatus> {
                    if cancel_flag.load(Ordering::Relaxed) {
                        return Err(TTZipStatus::Cancelled);
                    }

                    let entry = &self.entries[idx];
                    let safe_path = sanitize_and_validate_path(dest_dir, &entry.path)?;

                    if entry.is_symlink {
                        if let Some(target) = &entry.link_target {
                            if let Some(parent) = safe_path.parent() {
                                let _ = fs::create_dir_all(parent);
                            }
                            if safe_path.exists() || fs::symlink_metadata(&safe_path).is_ok() {
                                let _ = fs::remove_file(&safe_path);
                            }
                            let _ = std::os::unix::fs::symlink(target.as_ref(), &safe_path);
                        }
                    } else {
                        if let Some(parent) = safe_path.parent() {
                            let _ = fs::create_dir_all(parent);
                        }

                        let payload = self.extract_entry_bytes(idx)?;
                        let mut file = File::create(&safe_path)
                            .map_err(|_| TTZipStatus::ErrExtractionFailed)?;
                        if entry.size > 0 {
                            let _ = apfs_preallocate(file.as_raw_fd(), entry.size as i64);
                            file.write_all(payload)
                                .map_err(|_| TTZipStatus::ErrExtractionFailed)?;
                        }
                    }

                    processed_bytes.fetch_add(entry.size, Ordering::Relaxed);
                    Ok(())
                })
            });

            par_res?;
        }

        // Stage 2: Apply deferred metadata bottom-up
        if options.preserve_permissions {
            engine.apply_all()?;
        }

        Ok(TarExtractReport {
            processed_entries_count: self.entries.len(),
            total_uncompressed_bytes: total_uncomp_bytes,
            duration_ms: start_time.elapsed().as_millis() as u64,
        })
    }
}
