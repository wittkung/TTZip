// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Subcommand execution handlers: list, extract, and create.

use super::args::{VfsNodeContractDto, VfsTreeContractDto};
use super::format::{detect_archive_format, format_bytes, parse_archive_entries, ContainerFormat};
use std::ffi::CString;
use std::fs;
use std::path::{Path, PathBuf};
use std::time::Instant;
use ttzip_glue::sevenz::{create_7z_archive, SevenZArchive};
use ttzip_glue::types::{
    TTZipArchiveFormat, TTZipCompressionLevel, TTZipCreateOptions, TTZipEncryptionMethod,
    TTZipExtractOptions,
};
use ttzip_glue::zip::{create_zip_archive, ZipArchive};

/// Executes headless `list` subcommand.
pub fn execute_list(archive_path: &Path, _password: Option<&str>, json: bool) -> Result<(), String> {
    if !archive_path.exists() {
        return Err(format!("Archive file not found: {}", archive_path.display()));
    }
    let data = fs::read(archive_path).map_err(|e| format!("Failed to read archive: {}", e))?;
    let (format, entries) = parse_archive_entries(archive_path, &data)?;

    let total_uncompressed: u64 = entries.iter().map(|e| e.uncompressed_size).sum();
    let _total_compressed: u64 = entries.iter().map(|e| e.compressed_size).sum();
    let dir_count = entries.iter().filter(|e| e.is_directory).count();
    let file_count = entries.len() - dir_count;

    if json {
        let nodes: Vec<VfsNodeContractDto> = entries
            .iter()
            .map(|e| VfsNodeContractDto {
                name: e.name.clone(),
                relative_path: e.relative_path.clone(),
                is_directory: e.is_directory,
                uncompressed_size: e.uncompressed_size,
                compressed_size: e.compressed_size,
                crc32: e.crc32,
                is_encrypted: e.is_encrypted,
                match_indices: None,
            })
            .collect();

        let contract = VfsTreeContractDto {
            root_path: archive_path.to_string_lossy().to_string(),
            total_entries_count: entries.len(),
            total_uncompressed_bytes: total_uncompressed,
            nodes,
        };

        let json_str = serde_json::to_string_pretty(&contract)
            .map_err(|e| format!("Failed to serialize contract JSON: {}", e))?;
        println!("{}", json_str);
        return Ok(());
    }

    println!(
        "Archive: {} (Format: {}, Entries: {})",
        archive_path.display(),
        format.name(),
        entries.len()
    );
    println!("{:-<80}", "");
    println!(
        "{:<36} {:>12} {:>15} {:>7}  {:>10}",
        "Path", "Uncompressed", "Compressed", "Ratio", "CRC32"
    );
    println!("{:-<80}", "");

    for entry in &entries {
        let ratio = if entry.uncompressed_size > 0 {
            format!(
                "{:.1}%",
                (entry.compressed_size as f64 / entry.uncompressed_size as f64) * 100.0
            )
        } else {
            "-".to_string()
        };

        let path_display = if entry.is_directory {
            format!("{}/", entry.relative_path.trim_end_matches('/'))
        } else {
            entry.relative_path.clone()
        };

        let path_truncated = if path_display.len() > 36 {
            format!("...{}", &path_display[path_display.len() - 33..])
        } else {
            path_display
        };

        let crc_str = if entry.is_directory {
            "-".to_string()
        } else {
            format!("0x{:08X}", entry.crc32)
        };

        println!(
            "{:<36} {:>12} {:>15} {:>7}  {:>10}",
            path_truncated,
            format_bytes(entry.uncompressed_size),
            format_bytes(entry.compressed_size),
            ratio,
            crc_str
        );
    }

    println!("{:-<80}", "");
    println!(
        "Total: {} files, {} ({} directories)",
        file_count,
        format_bytes(total_uncompressed),
        dir_count
    );

    Ok(())
}

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

    let data = fs::read(archive_path).map_err(|e| format!("Failed to read archive: {}", e))?;
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

    let report = match format {
        ContainerFormat::Zip => {
            let archive = ZipArchive::open_slice(&data)
                .map_err(|e| format!("Failed to open ZIP archive: {:?}", e))?;
            archive
                .extract_all(dest_dir, &options)
                .map_err(|e| format!("ZIP extraction failed: {:?}", e))?
        }
        ContainerFormat::SevenZip => {
            let archive = SevenZArchive::open_slice(&data)
                .map_err(|e| format!("Failed to open 7z archive: {:?}", e))?;
            archive
                .extract_all(dest_dir, &options)
                .map_err(|e| format!("7z extraction failed: {:?}", e))?
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
        report.processed_entries_count,
        format_bytes(report.total_uncompressed_bytes),
        dest_dir.display(),
        elapsed
    );

    Ok(())
}

/// Executes headless `create` subcommand.
pub fn execute_create(
    archive_path: &Path,
    sources: &[PathBuf],
    format_opt: Option<&str>,
    level: u8,
    password: Option<&str>,
    threads: u32,
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
