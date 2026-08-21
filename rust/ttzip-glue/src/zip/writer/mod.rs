// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! ZIP Archive Parallel Compression and Writing Engine.
//!
//! Supports Store, Deflate (Levels 1..12 via `libdeflate`), WinZip AES-256 hardware encryption,
//! and automatic Zip64 extension promotion for large files (>4GB) and large catalogs (>65535 files).

pub mod assemble;
pub mod parallel;
pub mod store_stream;
pub mod types;

pub use assemble::*;
pub use parallel::*;
pub use store_stream::*;
pub use types::*;

use crate::types::{TTZipCompressionLevel, TTZipCreateOptions, TTZipEncryptionMethod, TTZipStatus};
use std::fs::{self, File};
use std::io::Write;
use std::path::{Path, PathBuf};

/// Creates a ZIP archive file directly from input source paths.
pub fn create_zip_archive(
    dest_path: &Path,
    source_paths: &[PathBuf],
    options: &TTZipCreateOptions,
) -> Result<ZipCreateReport, TTZipStatus> {
    if options.level == TTZipCompressionLevel::Store && options.encryption == TTZipEncryptionMethod::None {
        return create_zip_store_parallel(dest_path, source_paths, options);
    }

    let start_time = std::time::Instant::now();

    let mut input_items = Vec::new();
    for src in source_paths {
        if !src.exists() {
            return Err(TTZipStatus::ErrFileNotFound);
        }
        let file_name = src.file_name().unwrap_or_default().to_string_lossy();
        collect_zip_input_items(src, &file_name, &mut input_items)?;
    }

    let level_int = match options.level {
        TTZipCompressionLevel::Store => 0,
        TTZipCompressionLevel::Fastest => 1,
        TTZipCompressionLevel::Fast => 3,
        TTZipCompressionLevel::Normal => 6,
        TTZipCompressionLevel::Maximum => 9,
        TTZipCompressionLevel::Ultra => 12,
    };

    let password_str = if !options.password.is_null() {
        unsafe { std::ffi::CStr::from_ptr(options.password) }
            .to_str()
            .ok()
    } else {
        None
    };

    let compressed_items = compress_items_parallel(
        input_items,
        level_int,
        options.encryption,
        password_str,
        options.thread_budget,
    )?;

    let mut total_uncomp_bytes = 0u64;
    let mut total_comp_bytes = 0u64;
    for item in &compressed_items {
        total_uncomp_bytes += item.uncompressed_size;
        total_comp_bytes += item.compressed_size;
    }

    let binary_bytes = assemble_zip_archive(&compressed_items)?;

    if let Some(parent) = dest_path.parent() {
        fs::create_dir_all(parent).map_err(|_| TTZipStatus::ErrOpenFailed)?;
    }

    let mut file = File::create(dest_path).map_err(|_| TTZipStatus::ErrOpenFailed)?;
    file.write_all(&binary_bytes).map_err(|_| TTZipStatus::ErrCompressionFailed)?;

    Ok(ZipCreateReport {
        total_entries: compressed_items.len(),
        total_uncompressed_bytes: total_uncomp_bytes,
        total_compressed_bytes: total_comp_bytes,
        duration_ms: start_time.elapsed().as_millis() as u64,
    })
}
