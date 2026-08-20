// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! ZIP Archive Decompression and Extraction Engine.
//!
//! Features multi-core parallel extraction, libdeflate thread-local handle pooling,
//! WinZip AES-256 hardware decryption passthrough, and ZipSlip-immune safe file landing.

use crate::codecs::deflate::with_thread_local_decompressor;
use crate::crypto::crc32::crc32_fast;
use crate::crypto::sha1::winzip_aes256_decrypt_and_verify;
use crate::fs::safe_extract::{sanitize_and_validate_path, SafeExtractEngine};
use crate::types::{TTZipExtractOptions, TTZipStatus};
use crate::zip::parser::{parse_all_entries, parse_local_file_header, ZipEntry};
use std::ffi::CString;
use std::fs::{self, File};
use std::io::Write;
use std::path::Path;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::Arc;
use std::thread;

/// Detailed report from an archive extraction operation.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct ZipExtractReport {
    pub processed_entries_count: usize,
    pub total_uncompressed_bytes: u64,
    pub total_compressed_bytes: u64,
    pub duration_ms: u64,
}

/// Zero-copy memory-mapped ZIP Archive reader.
pub struct ZipArchive<'a> {
    data: &'a [u8],
    entries: Vec<ZipEntry>,
}

impl<'a> ZipArchive<'a> {
    /// Opens and parses a ZIP archive from an in-memory slice.
    pub fn open_slice(data: &'a [u8]) -> Result<Self, TTZipStatus> {
        let entries = parse_all_entries(data)?;
        Ok(Self { data, entries })
    }

    /// Returns reference to all parsed Central Directory entries.
    #[inline]
    pub fn entries(&self) -> &[ZipEntry] {
        &self.entries
    }

    /// Returns the number of entries in the archive.
    #[inline]
    pub fn len(&self) -> usize {
        self.entries.len()
    }

    /// Returns true if the archive contains no entries.
    #[inline]
    pub fn is_empty(&self) -> bool {
        self.entries.is_empty()
    }

    /// Decompresses and extracts a single entry into a byte vector.
    pub fn extract_entry_bytes(
        &self,
        entry_idx: usize,
        password: Option<&str>,
    ) -> Result<Vec<u8>, TTZipStatus> {
        let entry = self
            .entries
            .get(entry_idx)
            .ok_or(TTZipStatus::ErrInvalidOffset)?;

        if entry.is_directory {
            return Ok(Vec::new());
        }

        if entry.uncompressed_size == 0 {
            return Ok(Vec::new());
        }

        let lfh_offset = entry.lfh_offset as usize;
        let (payload_offset, _) = parse_local_file_header(self.data, lfh_offset)?;
        let comp_size = entry.compressed_size as usize;

        if payload_offset + comp_size > self.data.len() {
            return Err(TTZipStatus::ErrCorruptHeader);
        }

        let raw_payload = &self.data[payload_offset..payload_offset + comp_size];
        let mut decrypted_storage = Vec::new();

        let effective_payload = if entry.is_encrypted {
            let pass = password.ok_or(TTZipStatus::ErrInvalidPassword)?;
            if pass.is_empty() {
                return Err(TTZipStatus::ErrInvalidPassword);
            }

            if comp_size < 28 {
                return Err(TTZipStatus::ErrCorruptHeader);
            }

            let cipher_len = comp_size - 28;
            decrypted_storage.resize(cipher_len, 0);
            let dec_len = winzip_aes256_decrypt_and_verify(pass, raw_payload, &mut decrypted_storage)?;
            &decrypted_storage[..dec_len]
        } else {
            raw_payload
        };

        let uncomp_size = entry.uncompressed_size as usize;
        let mut out_buffer = vec![0u8; uncomp_size];

        match entry.actual_method {
            0 => {
                // Store (uncompressed)
                if effective_payload.len() != uncomp_size {
                    return Err(TTZipStatus::ErrCorruptHeader);
                }
                out_buffer.copy_from_slice(effective_payload);
            }
            8 => {
                // Deflate
                let decomp_size = with_thread_local_decompressor(|dec| {
                    dec.decompress(effective_payload, &mut out_buffer)
                })?;
                if decomp_size != uncomp_size {
                    return Err(TTZipStatus::ErrCorruptHeader);
                }
            }
            _ => {
                return Err(TTZipStatus::ErrArchiveInitFailed);
            }
        }

        // Verify CRC32 if not WinZip AES AE-2
        if !entry.is_encrypted || entry.crc32 != 0 {
            let computed_crc = crc32_fast(0, &out_buffer);
            if computed_crc != entry.crc32 {
                return Err(TTZipStatus::ErrCorruptHeader);
            }
        }

        Ok(out_buffer)
    }

    /// Extracts all entries to the destination directory.
    pub fn extract_all(
        &self,
        dest_dir: &Path,
        options: &TTZipExtractOptions,
    ) -> Result<ZipExtractReport, TTZipStatus> {
        let start_time = std::time::Instant::now();
        fs::create_dir_all(dest_dir).map_err(|_| TTZipStatus::ErrOpenFailed)?;

        let mut engine = SafeExtractEngine::new();
        let num_entries = self.entries.len();
        let mut total_uncomp_bytes = 0u64;
        let mut total_comp_bytes = 0u64;

        let password_str = if !options.password.is_null() {
            unsafe { std::ffi::CStr::from_ptr(options.password) }
                .to_str()
                .ok()
        } else {
            None
        };

        // First pass: register directories and metadata with SafeExtractEngine
        for entry in &self.entries {
            total_uncomp_bytes += entry.uncompressed_size;
            total_comp_bytes += entry.compressed_size;

            let safe_path = sanitize_and_validate_path(dest_dir, &entry.rel_path)?;
            engine.register_entry(
                safe_path.clone(),
                entry.mode,
                entry.mtime_epoch_secs,
                0,
                entry.is_directory,
            );

            if entry.is_directory {
                fs::create_dir_all(&safe_path).map_err(|_| TTZipStatus::ErrExtractionFailed)?;
            }
        }

        if options.dry_run {
            return Ok(ZipExtractReport {
                processed_entries_count: num_entries,
                total_uncompressed_bytes: total_uncomp_bytes,
                total_compressed_bytes: total_comp_bytes,
                duration_ms: start_time.elapsed().as_millis() as u64,
            });
        }

        // Collect non-directory tasks
        let mut file_indices = Vec::new();
        for (idx, entry) in self.entries.iter().enumerate() {
            if !entry.is_directory {
                file_indices.push(idx);
            }
        }

        let thread_count = (options.thread_budget as usize)
            .clamp(1, 64)
            .min(file_indices.len().max(1));

        let processed_bytes = Arc::new(AtomicU64::new(0));
        let cancel_flag = Arc::new(AtomicBool::new(false));

        if thread_count <= 1 || file_indices.len() <= 4 {
            // Single-threaded path
            for &idx in &file_indices {
                let entry = &self.entries[idx];
                let safe_path = sanitize_and_validate_path(dest_dir, &entry.rel_path)?;

                if let Some(parent) = safe_path.parent() {
                    fs::create_dir_all(parent).map_err(|_| TTZipStatus::ErrExtractionFailed)?;
                }

                if entry.uncompressed_size == 0 {
                    File::create(&safe_path).map_err(|_| TTZipStatus::ErrExtractionFailed)?;
                } else {
                    let bytes = self.extract_entry_bytes(idx, password_str)?;
                    let mut file = File::create(&safe_path).map_err(|_| TTZipStatus::ErrExtractionFailed)?;
                    file.write_all(&bytes).map_err(|_| TTZipStatus::ErrExtractionFailed)?;
                }

                let current_done = processed_bytes.fetch_add(entry.uncompressed_size, Ordering::Relaxed)
                    + entry.uncompressed_size;

                if let Some(cb) = options.progress_callback {
                    let c_path = CString::new(entry.rel_path.as_str()).unwrap_or_default();
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
        } else {
            // Multi-threaded parallel extraction
            let chunk_size = (file_indices.len() + thread_count - 1) / thread_count;
            let dest_dir_buf = dest_dir.to_path_buf();
            let password_owned = password_str.map(|s| s.to_string());

            let scope_res: Result<(), TTZipStatus> = thread::scope(|s| {
                let mut handles = Vec::new();

                for chunk in file_indices.chunks(chunk_size) {
                    let chunk_indices = chunk.to_vec();
                    let dest_dir_cloned = dest_dir_buf.clone();
                    let pwd_cloned = password_owned.clone();
                    let proc_bytes_cloned = Arc::clone(&processed_bytes);
                    let cancel_cloned = Arc::clone(&cancel_flag);

                    let handle = s.spawn(move || -> Result<(), TTZipStatus> {
                        for &idx in &chunk_indices {
                            if cancel_cloned.load(Ordering::Relaxed) {
                                return Err(TTZipStatus::Cancelled);
                            }

                            let entry = &self.entries[idx];
                            let safe_path = sanitize_and_validate_path(&dest_dir_cloned, &entry.rel_path)?;

                            if let Some(parent) = safe_path.parent() {
                                let _ = fs::create_dir_all(parent);
                            }

                            if entry.uncompressed_size == 0 {
                                File::create(&safe_path).map_err(|_| TTZipStatus::ErrExtractionFailed)?;
                            } else {
                                let bytes = self.extract_entry_bytes(idx, pwd_cloned.as_deref())?;
                                let mut file = File::create(&safe_path)
                                    .map_err(|_| TTZipStatus::ErrExtractionFailed)?;
                                file.write_all(&bytes)
                                    .map_err(|_| TTZipStatus::ErrExtractionFailed)?;
                            }

                            proc_bytes_cloned.fetch_add(entry.uncompressed_size, Ordering::Relaxed);
                        }
                        Ok(())
                    });

                    handles.push(handle);
                }

                for handle in handles {
                    match handle.join() {
                        Ok(res) => res?,
                        Err(_) => return Err(TTZipStatus::ErrPanicCaught),
                    }
                }
                Ok(())
            });
            scope_res?;
        }

        // Apply two-stage bottom-up permissions and timestamp restoration
        if options.preserve_permissions {
            engine.apply_all()?;
        }

        Ok(ZipExtractReport {
            processed_entries_count: num_entries,
            total_uncompressed_bytes: total_uncomp_bytes,
            total_compressed_bytes: total_comp_bytes,
            duration_ms: start_time.elapsed().as_millis() as u64,
        })
    }
}
