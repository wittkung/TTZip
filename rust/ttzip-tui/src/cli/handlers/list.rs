// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Subcommand execution handler: list.

use crate::cli::args::{VfsNodeContractDto, VfsTreeContractDto};
use crate::cli::format::{format_bytes, parse_archive_entries, read_archive_data_auto};
use std::path::Path;

/// Executes headless `list` subcommand.
pub fn execute_list(archive_path: &Path, _password: Option<&str>, json: bool) -> Result<(), String> {
    if !archive_path.exists() {
        return Err(format!("Archive file not found: {}", archive_path.display()));
    }

    let (volumes, data) = read_archive_data_auto(archive_path)?;
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

    if volumes.len() > 1 {
        println!(
            "Archive: {} (Format: {}, Multi-volume: {} parts, Entries: {})",
            archive_path.display(),
            format.name(),
            volumes.len(),
            entries.len()
        );
    } else {
        println!(
            "Archive: {} (Format: {}, Entries: {})",
            archive_path.display(),
            format.name(),
            entries.len()
        );
    }
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
