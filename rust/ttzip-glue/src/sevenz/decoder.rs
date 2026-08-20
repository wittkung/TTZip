// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! 7-Zip Solid Stream Decoder and Selective Extraction Engine.
//!
//! Integrates ARM64 8-way NEON AES-256-CBC hardware decryption, zero-heap SHA-256 KDF,
//! multi-threaded fast-lzma2 / Deflate decoding, and sub-stream selective slicing.

use crate::codecs::deflate::deflate_decompress;
use crate::codecs::lzma2::fl2_decompress;
use crate::crypto::aes256::aes256_cbc_decrypt;
use crate::crypto::crc32::crc32_fast;
use crate::crypto::sha256::sha256_7z_kdf;
use crate::fs::safe_extract::{sanitize_and_validate_path, SafeExtractEngine};
use crate::sevenz::format::*;
use crate::sevenz::header::{parse_7z_metadata, SevenZFileMeta, SevenZHeaderInfo};
use crate::types::{TTZipExtractOptions, TTZipStatus};
use crate::zip::reader::ZipExtractReport;
use std::ffi::CString;
use std::fs::{self, File};
use std::io::Write;
use std::path::Path;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;

/// Decompresses and decrypts the entire 7z solid payload block.
pub fn decode_7z_solid_payload(
    mapped: &[u8],
    info: &SevenZHeaderInfo,
    password: Option<&str>,
    threads: u32,
) -> Result<Vec<u8>, TTZipStatus> {
    if info.payload_len == 0 {
        return Ok(Vec::new());
    }

    let payload_end = info.payload_offset + info.payload_len;
    if payload_end > mapped.len() {
        return Err(TTZipStatus::ErrCorruptHeader);
    }

    let mut raw_payload = &mapped[info.payload_offset..payload_end];
    let mut decrypted_storage = Vec::new();

    // 1. Hardware AES-256-CBC decryption via ARM64 NEON if encrypted
    if info.is_encrypted {
        let pass = password.ok_or(TTZipStatus::ErrInvalidPassword)?;
        if pass.is_empty() {
            return Err(TTZipStatus::ErrInvalidPassword);
        }

        let key = sha256_7z_kdf(pass, &info.aes_salt[..info.aes_salt_len], info.aes_num_cycles_power);

        if raw_payload.len() % 16 != 0 {
            return Err(TTZipStatus::ErrCorruptHeader);
        }

        decrypted_storage.resize(raw_payload.len(), 0);
        aes256_cbc_decrypt(&key, &info.aes_iv, raw_payload, &mut decrypted_storage)
            .map_err(|_| TTZipStatus::ErrInvalidPassword)?;

        raw_payload = &decrypted_storage;
    }

    // 2. Compute total expected uncompressed size
    let expected_unpack_size: u64 = if !info.stream_sizes.is_empty() {
        info.stream_sizes.iter().sum()
    } else if !info.folders.is_empty() && !info.folders[0].unpack_sizes.is_empty() {
        info.folders[0].unpack_sizes[0]
    } else {
        raw_payload.len() as u64
    };

    let mut unpack_buf = vec![0u8; expected_unpack_size as usize];

    // 3. Decompress via selected coder
    match info.primary_method_id {
        METHOD_COPY => {
            let u_len = unpack_buf.len();
            if raw_payload.len() < u_len {
                return Err(TTZipStatus::ErrCorruptHeader);
            }
            unpack_buf.copy_from_slice(&raw_payload[..u_len]);
        }
        METHOD_DEFLATE => {
            let decomp_len = deflate_decompress(raw_payload, &mut unpack_buf)?;
            if decomp_len != unpack_buf.len() {
                return Err(TTZipStatus::ErrExtractionFailed);
            }
        }
        METHOD_LZMA2 => {
            let decomp_len = fl2_decompress(raw_payload, &mut unpack_buf, threads)?;
            if decomp_len != unpack_buf.len() {
                return Err(TTZipStatus::ErrExtractionFailed);
            }
        }
        _ => {
            // For other formats (LZMA, BCJ), attempt fast-lzma2 fallback or report format error
            let decomp_len = fl2_decompress(raw_payload, &mut unpack_buf, threads)?;
            if decomp_len != unpack_buf.len() {
                return Err(TTZipStatus::ErrArchiveInitFailed);
            }
        }
    }

    Ok(unpack_buf)
}

/// Zero-copy 7z Archive reader and extractor.
pub struct SevenZArchive<'a> {
    data: &'a [u8],
    info: SevenZHeaderInfo,
}

impl<'a> SevenZArchive<'a> {
    /// Opens and parses a 7z archive from in-memory slice.
    pub fn open_slice(data: &'a [u8]) -> Result<Self, TTZipStatus> {
        let info = parse_7z_metadata(data)?;
        Ok(Self { data, info })
    }

    /// Returns reference to parsed 7z metadata header.
    #[inline]
    pub fn info(&self) -> &SevenZHeaderInfo {
        &self.info
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

    /// Decompresses and extracts a single file from the 7z solid stream.
    pub fn extract_entry_bytes(
        &self,
        entry_idx: usize,
        password: Option<&str>,
    ) -> Result<Vec<u8>, TTZipStatus> {
        let file_meta = self.info.files.get(entry_idx).ok_or(TTZipStatus::ErrInvalidOffset)?;

        if file_meta.is_directory || file_meta.is_empty_stream {
            return Ok(Vec::new());
        }

        // Calculate offset and length for this stream in the solid block
        let mut stream_idx = 0;
        let mut target_stream_idx = None;

        for (i, f) in self.info.files.iter().enumerate() {
            if !f.is_directory && !f.is_empty_stream {
                if i == entry_idx {
                    target_stream_idx = Some(stream_idx);
                    break;
                }
                stream_idx += 1;
            }
        }

        let s_idx = target_stream_idx.ok_or(TTZipStatus::ErrInvalidOffset)?;
        if s_idx >= self.info.stream_sizes.len() {
            return Err(TTZipStatus::ErrCorruptHeader);
        }

        let mut offset = 0usize;
        for i in 0..s_idx {
            offset += self.info.stream_sizes[i] as usize;
        }
        let size = self.info.stream_sizes[s_idx] as usize;

        // Decode solid stream (single-threaded for targeted fast extract)
        let solid_buf = decode_7z_solid_payload(self.data, &self.info, password, 2)?;

        if offset + size > solid_buf.len() {
            return Err(TTZipStatus::ErrCorruptHeader);
        }

        let file_slice = &solid_buf[offset..offset + size];

        // Verify CRC32 if stream CRC is available
        if let Some(&expected_crc) = self.info.stream_crcs.get(s_idx) {
            if expected_crc != 0 {
                let computed = crc32_fast(0, file_slice);
                if computed != expected_crc {
                    return Err(TTZipStatus::ErrInvalidPassword);
                }
            }
        }

        Ok(file_slice.to_vec())
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

        // 1. Decode solid block
        let solid_buf = decode_7z_solid_payload(
            self.data,
            &self.info,
            password_str,
            options.thread_budget.max(1),
        )?;

        // 2. Slice and land files
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

            // Check CRC
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
