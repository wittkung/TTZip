// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Subcommand execution handler: create (with optional multi-volume splitting).

use super::split::parse_size_bytes;
use crate::cli::format::{format_bytes, ContainerFormat};
use std::ffi::CString;
use std::fs::{self, File};
use std::io::{Read, Write};
use std::path::{Path, PathBuf};
use std::time::Instant;
use ttzip_glue::archive::split::{SplitVolumeWriter, VolumeNamingScheme};
use ttzip_glue::sevenz::create_7z_archive;
use ttzip_glue::types::{
    TTZipArchiveFormat, TTZipCompressionLevel, TTZipCreateOptions, TTZipEncryptionMethod,
};
use ttzip_glue::zip::create_zip_archive;

/// Executes headless `create` subcommand with optional multi-volume chunk splitting.
pub fn execute_create(
    archive_path: &Path,
    sources: &[PathBuf],
    format_opt: Option<&str>,
    level: u8,
    password: Option<&str>,
    threads: u32,
    volume_size: Option<&str>,
) -> Result<(), String> {
    if sources.is_empty() {
        return Err("No source files specified for archive creation".to_string());
    }

    for src in sources {
        if !src.exists() {
            return Err(format!("Source file/directory not found: {}", src.display()));
        }
    }

    let start_time = Instant::now();

    // Determine target format
    let target_format = if let Some(fmt) = format_opt {
        match fmt.to_lowercase().as_str() {
            "7z" | "sevenzip" => ContainerFormat::SevenZip,
            "zip" => ContainerFormat::Zip,
            other => return Err(format!("Unsupported format: {}", other)),
        }
    } else if let Some(ext) = archive_path.extension().and_then(|s| s.to_str()) {
        if ext.eq_ignore_ascii_case("7z") {
            ContainerFormat::SevenZip
        } else {
            ContainerFormat::Zip
        }
    } else {
        ContainerFormat::Zip
    };

    let compression_level = match level {
        0 => TTZipCompressionLevel::Store,
        1..=2 => TTZipCompressionLevel::Fastest,
        3..=5 => TTZipCompressionLevel::Fast,
        6..=8 => TTZipCompressionLevel::Normal,
        9..=11 => TTZipCompressionLevel::Maximum,
        _ => TTZipCompressionLevel::Ultra,
    };

    let password_c = password.map(|p| CString::new(p).unwrap_or_default());
    let password_ptr = password_c.as_ref().map(|c| c.as_ptr()).unwrap_or(std::ptr::null());

    let encryption_method = if password.is_some() {
        TTZipEncryptionMethod::Aes256
    } else {
        TTZipEncryptionMethod::None
    };

    let options = TTZipCreateOptions {
        format: match target_format {
            ContainerFormat::Zip => TTZipArchiveFormat::Zip,
            ContainerFormat::SevenZip => TTZipArchiveFormat::SevenZip,
            _ => TTZipArchiveFormat::Zip,
        },
        level: compression_level,
        encryption: encryption_method,
        password: password_ptr,
        thread_budget: threads.max(1),
        solid_block_size_mb: 64,
        progress_callback: None,
        user_data: std::ptr::null_mut(),
    };

    if let Some(v_size_str) = volume_size {
        let chunk_size = parse_size_bytes(v_size_str)?;
        let temp_archive_path = archive_path.with_extension(format!("tmp_{}", std::process::id()));

        let report = match target_format {
            ContainerFormat::Zip => create_zip_archive(&temp_archive_path, sources, &options)
                .map_err(|e| format!("Failed to create ZIP archive: {:?}", e))?,
            ContainerFormat::SevenZip => create_7z_archive(&temp_archive_path, sources, &options)
                .map_err(|e| format!("Failed to create 7z archive: {:?}", e))?,
            _ => return Err("Invalid format".to_string()),
        };

        // Split created archive into multi-volumes
        let naming_scheme = match target_format {
            ContainerFormat::Zip => VolumeNamingScheme::NumberedExtension,
            _ => VolumeNamingScheme::NumberedExtension,
        };

        let mut writer = SplitVolumeWriter::new(archive_path, chunk_size, naming_scheme)
            .map_err(|e| format!("Failed to initialize multi-volume writer: {}", e))?;

        let mut temp_file = File::open(&temp_archive_path)
            .map_err(|e| format!("Failed to open temp archive: {}", e))?;
        let mut buffer = vec![0u8; 256 * 1024];
        loop {
            let bytes_read = temp_file
                .read(&mut buffer)
                .map_err(|e| format!("Failed to read temp archive: {}", e))?;
            if bytes_read == 0 {
                break;
            }
            writer
                .write_all(&buffer[..bytes_read])
                .map_err(|e| format!("Failed to write volume segment: {}", e))?;
        }

        let volumes = writer
            .close()
            .map_err(|e| format!("Failed to close split volumes: {}", e))?;
        let _ = fs::remove_file(&temp_archive_path);

        let elapsed = start_time.elapsed();
        println!(
            "Created {} multi-volume archive {} ({} volumes) with {} entries ({} -> {}) in {:.2?}",
            target_format.name(),
            archive_path.display(),
            volumes.len(),
            report.total_entries,
            format_bytes(report.total_uncompressed_bytes),
            format_bytes(report.total_compressed_bytes),
            elapsed
        );
        for vol in &volumes {
            println!("  - {}", vol.display());
        }

        return Ok(());
    }

    let report = match target_format {
        ContainerFormat::Zip => create_zip_archive(archive_path, sources, &options)
            .map_err(|e| format!("Failed to create ZIP archive: {:?}", e))?,
        ContainerFormat::SevenZip => create_7z_archive(archive_path, sources, &options)
            .map_err(|e| format!("Failed to create 7z archive: {:?}", e))?,
        _ => return Err("Invalid format".to_string()),
    };

    let elapsed = start_time.elapsed();
    println!(
        "Created {} archive {} with {} entries ({} -> {}) in {:.2?}",
        target_format.name(),
        archive_path.display(),
        report.total_entries,
        format_bytes(report.total_uncompressed_bytes),
        format_bytes(report.total_compressed_bytes),
        elapsed
    );

    Ok(())
}
