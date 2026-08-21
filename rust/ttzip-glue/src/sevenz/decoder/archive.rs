// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Zero-copy 7z Archive reader and extraction engine.

use super::payload::decode_7z_solid_payload;
use super::stream::extract_entry_bytes_stream;
use crate::crypto::crc32::crc32_fast;
use crate::fs::safe_extract::{sanitize_and_validate_path, SafeExtractEngine};
use crate::sevenz::header::{parse_7z_metadata, SevenZFileMeta, SevenZHeaderInfo, SevenZSeekIndex};
use crate::types::{TTZipExtractOptions, TTZipStatus};
use crate::zip::reader::ZipExtractReport;
use std::ffi::CString;
use std::fs::{self, File};
use std::io::Write;
use std::path::Path;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;

/// Zero-copy 7z Archive reader and extractor.
pub struct SevenZArchive<'a> {
    data: &'a [u8],
    info: SevenZHeaderInfo,
    seek_index: SevenZSeekIndex,
}

impl<'a> SevenZArchive<'a> {
    /// Opens and parses a 7z archive from in-memory slice.
    pub fn open_slice(data: &'a [u8]) -> Result<Self, TTZipStatus> {
        let info = parse_7z_metadata(data)?;
        let seek_index = SevenZSeekIndex::build(&info);
        Ok(Self {
            data,
            info,
            seek_index,
        })
    }

    /// Returns reference to parsed 7z metadata header.
    #[inline]
    pub fn info(&self) -> &SevenZHeaderInfo {
        &self.info
    }

    /// Returns reference to pre-built random-access seek index.
    #[inline]
    pub fn seek_index(&self) -> &SevenZSeekIndex {
        &self.seek_index
    }

    /// Returns list of files in the 7z archive.
    #[inline]
    pub fn files(&self) -> &[SevenZFileMeta] {
        &self.info.files
    }

    /// Returns the number of files in the archive.
    #[inline]
    pub fn len(&self) -> usize {
        self.info.files.len()
    }

    /// Returns true if the archive is empty.
    #[inline]
    pub fn is_empty(&self) -> bool {
        self.info.files.is_empty()
    }

    /// Decompresses and extracts a single file from the 7z solid stream using Early Termination.
    #[inline]
    pub fn extract_entry_bytes_stream(
        &self,
        entry_idx: usize,
        password: Option<&str>,
    ) -> Result<Vec<u8>, TTZipStatus> {
        extract_entry_bytes_stream(self.data, &self.info, &self.seek_index, entry_idx, password)
    }

    /// Decompresses and extracts a single file from the 7z solid stream.
    #[inline]
    pub fn extract_entry_bytes(
        &self,
        entry_idx: usize,
        password: Option<&str>,
    ) -> Result<Vec<u8>, TTZipStatus> {
        self.extract_entry_bytes_stream(entry_idx, password)
    }

    /// Extracts all files in the 7z archive to the destination directory.
    pub fn extract_all(
        &self,
        dest_dir: &Path,
        options: &TTZipExtractOptions,
    ) -> Result<ZipExtractReport, TTZipStatus> {
        let start_time = std::time::Instant::now();
        fs::create_dir_all(dest_dir).map_err(|_| TTZipStatus::ErrOpenFailed)?;

        let password_str = if !options.password.is_null() {
            unsafe { std::ffi::CStr::from_ptr(options.password) }
                .to_str()
                .ok()
        } else {
            None
        };

        let mut engine = SafeExtractEngine::new();
        let mut total_uncomp_bytes = 0u64;

        for file in &self.info.files {
            let safe_path = sanitize_and_validate_path(dest_dir, &file.rel_path)?;
            engine.register_entry(
                safe_path.clone(),
                file.mode,
                file.mtime_epoch_secs.unwrap_or(0),
                0,
                file.is_directory,
            );

            if file.is_directory {
                fs::create_dir_all(&safe_path).map_err(|_| TTZipStatus::ErrExtractionFailed)?;
            }
        }

        for &sz in &self.info.stream_sizes {
            total_uncomp_bytes += sz;
        }

        if options.dry_run {
            return Ok(ZipExtractReport {
                processed_entries_count: self.info.files.len(),
                total_uncompressed_bytes: total_uncomp_bytes,
                total_compressed_bytes: self.info.payload_len as u64,
                duration_ms: start_time.elapsed().as_millis() as u64,
            });
        }

        let solid_buf = decode_7z_solid_payload(
            self.data,
            &self.info,
            password_str,
            options.thread_budget.max(1),
        )?;

        let mut offset = 0usize;
        let mut stream_idx = 0usize;
        let processed_bytes = Arc::new(AtomicU64::new(0));

        for file in &self.info.files {
            if file.is_directory {
                continue;
            }

            let safe_path = sanitize_and_validate_path(dest_dir, &file.rel_path)?;
            if let Some(parent) = safe_path.parent() {
                fs::create_dir_all(parent).map_err(|_| TTZipStatus::ErrExtractionFailed)?;
            }

            if file.is_empty_stream {
                File::create(&safe_path).map_err(|_| TTZipStatus::ErrExtractionFailed)?;
                continue;
            }

            let fsize = if stream_idx < self.info.stream_sizes.len() {
                self.info.stream_sizes[stream_idx] as usize
            } else {
                solid_buf.len().saturating_sub(offset)
            };

            if offset + fsize > solid_buf.len() {
                return Err(TTZipStatus::ErrCorruptHeader);
            }

            let file_data = &solid_buf[offset..offset + fsize];

            if let Some(&expected_crc) = self.info.stream_crcs.get(stream_idx) {
                if expected_crc != 0 {
                    let computed = crc32_fast(0, file_data);
                    if computed != expected_crc {
                        return Err(TTZipStatus::ErrInvalidPassword);
                    }
                }
            }

            let mut out_file = File::create(&safe_path).map_err(|_| TTZipStatus::ErrExtractionFailed)?;
            out_file.write_all(file_data).map_err(|_| TTZipStatus::ErrExtractionFailed)?;

            offset += fsize;
            stream_idx += 1;

            let current_done = processed_bytes.fetch_add(fsize as u64, Ordering::Relaxed) + fsize as u64;

            if let Some(cb) = options.progress_callback {
                let c_path = CString::new(file.rel_path.as_str()).unwrap_or_default();
                let should_continue = unsafe {
                    cb(
                        current_done,
                        total_uncomp_bytes,
                        c_path.as_ptr(),
                        options.user_data,
                    )
                };
                if !should_continue {
                    return Err(TTZipStatus::Cancelled);
                }
            }
        }

        if options.preserve_permissions {
            engine.apply_all()?;
        }

        Ok(ZipExtractReport {
            processed_entries_count: self.info.files.len(),
            total_uncompressed_bytes: total_uncomp_bytes,
            total_compressed_bytes: self.info.payload_len as u64,
            duration_ms: start_time.elapsed().as_millis() as u64,
        })
    }
}
