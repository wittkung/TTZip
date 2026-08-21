// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Subcommand execution handler: extract.

use crate::cli::format::{detect_archive_format, format_bytes, read_archive_data_auto, ContainerFormat};
use std::ffi::CString;
use std::fs::{self, File};
use std::io::Write;
use std::path::Path;
use std::time::Instant;
use ttzip_glue::archive::tar::TarArchive;
use ttzip_glue::codecs::brotli::brotli_decompress_to_vec;
use ttzip_glue::codecs::snappy::snappy_frame_decode_to_vec;
use ttzip_glue::sevenz::SevenZArchive;
use ttzip_glue::types::TTZipExtractOptions;
use ttzip_glue::zip::ZipArchive;

/// Executes headless `extract` subcommand.
pub fn execute_extract(
    archive_path: &Path,
    output_dir: Option<&Path>,
    password: Option<&str>,
    threads: u32,
    _verbose: bool,
) -> Result<(), String> {
    if !archive_path.exists() {
        return Err(format!("Archive file not found: {}", archive_path.display()));
    }

    let start_time = Instant::now();
    let dest_dir = output_dir.unwrap_or_else(|| Path::new("."));
    fs::create_dir_all(dest_dir)
        .map_err(|e| format!("Failed to create output directory {}: {}", dest_dir.display(), e))?;

    let (_volumes, data) = read_archive_data_auto(archive_path)?;
    let format = detect_archive_format(archive_path, &data);

    let password_c = password.map(|p| CString::new(p).unwrap_or_default());
    let password_ptr = password_c.as_ref().map(|c| c.as_ptr()).unwrap_or(std::ptr::null());

    let options = TTZipExtractOptions {
        destination_path: std::ptr::null(),
        password: password_ptr,
        thread_budget: threads.max(1),
        overwrite_existing: true,
        preserve_permissions: true,
        dry_run: false,
        progress_callback: None,
        user_data: std::ptr::null_mut(),
    };

    let (entries_count, total_uncompressed_bytes) = match format {
        ContainerFormat::Zip => {
            let archive = ZipArchive::open_slice(&data)
                .map_err(|e| format!("Failed to open ZIP archive: {:?}", e))?;
            let rep = archive
                .extract_all(dest_dir, &options)
                .map_err(|e| format!("ZIP extraction failed: {:?}", e))?;
            (rep.processed_entries_count, rep.total_uncompressed_bytes)
        }
        ContainerFormat::SevenZip => {
            let archive = SevenZArchive::open_slice(&data)
                .map_err(|e| format!("Failed to open 7z archive: {:?}", e))?;
            let rep = archive
                .extract_all(dest_dir, &options)
                .map_err(|e| format!("7z extraction failed: {:?}", e))?;
            (rep.processed_entries_count, rep.total_uncompressed_bytes)
        }
        ContainerFormat::Tar => {
            let archive = TarArchive::open_slice(&data)
                .map_err(|e| format!("Failed to open TAR archive: {:?}", e))?;
            let rep = archive
                .extract_all(dest_dir, &options)
                .map_err(|e| format!("TAR extraction failed: {:?}", e))?;
            (rep.processed_entries_count, rep.total_uncompressed_bytes)
        }
        ContainerFormat::Snappy => {
            let decompressed = snappy_frame_decode_to_vec(&data, 1024 * 1024 * 512)
                .map_err(|e| format!("Failed to decompress Snappy stream: {:?}", e))?;
            if let Ok(tar) = TarArchive::open_slice(&decompressed) {
                let rep = tar
                    .extract_all(dest_dir, &options)
                    .map_err(|e| format!("Snappy TAR extraction failed: {:?}", e))?;
                (rep.processed_entries_count, rep.total_uncompressed_bytes)
            } else {
                let filename = archive_path
                    .file_name()
                    .and_then(|s| s.to_str())
                    .unwrap_or("decompressed.bin");
                let inner_name = filename
                    .strip_suffix(".sz")
                    .or_else(|| filename.strip_suffix(".snappy"))
                    .unwrap_or(filename);
                let out_file_path = dest_dir.join(inner_name);
                let mut out_file = File::create(&out_file_path)
                    .map_err(|e| format!("Failed to write decompressed Snappy file: {}", e))?;
                out_file
                    .write_all(&decompressed)
                    .map_err(|e| format!("Failed to write decompressed Snappy data: {}", e))?;
                (1, decompressed.len() as u64)
            }
        }
        ContainerFormat::Brotli | ContainerFormat::TarBrotli => {
            let decompressed = brotli_decompress_to_vec(&data, 1024 * 1024 * 512)
                .map_err(|e| format!("Failed to decompress Brotli stream: {:?}", e))?;
            if format == ContainerFormat::TarBrotli || TarArchive::open_slice(&decompressed).is_ok() {
                if let Ok(tar) = TarArchive::open_slice(&decompressed) {
                    let rep = tar
                        .extract_all(dest_dir, &options)
                        .map_err(|e| format!("Brotli TAR extraction failed: {:?}", e))?;
                    (rep.processed_entries_count, rep.total_uncompressed_bytes)
                } else {
                    return Err("Failed to parse inner TAR archive".to_string());
                }
            } else {
                let filename = archive_path
                    .file_name()
                    .and_then(|s| s.to_str())
                    .unwrap_or("decompressed.bin");
                let inner_name = filename.strip_suffix(".br").unwrap_or(filename);
                let out_file_path = dest_dir.join(inner_name);
                let mut out_file = File::create(&out_file_path)
                    .map_err(|e| format!("Failed to write decompressed Brotli file: {}", e))?;
                out_file
                    .write_all(&decompressed)
                    .map_err(|e| format!("Failed to write decompressed Brotli data: {}", e))?;
                (1, decompressed.len() as u64)
            }
        }
        ContainerFormat::Unknown => {
            return Err(format!(
                "Cannot extract unrecognized archive: {}",
                archive_path.display()
            ));
        }
    };

    let elapsed = start_time.elapsed();
    println!(
        "Extracted {} entries ({}) to {} in {:.2?}",
        entries_count,
        format_bytes(total_uncompressed_bytes),
        dest_dir.display(),
        elapsed
    );

    Ok(())
}
