// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Subcommand execution handler: tree.

use crate::cli::args::{VfsNodeContractDto, VfsTreeContractDto};
use crate::cli::format::{format_bytes, parse_archive_entries, read_archive_data_auto};
use std::path::Path;

/// Executes headless `tree` subcommand.
pub fn execute_tree(archive_path: &Path, max_depth: Option<usize>, json: bool) -> Result<(), String> {
    if !archive_path.exists() {
        return Err(format!("Archive file not found: {}", archive_path.display()));
    }

    let (_volumes, data) = read_archive_data_auto(archive_path)?;
    let (format, entries) = parse_archive_entries(archive_path, &data)?;

    let total_uncompressed: u64 = entries.iter().map(|e| e.uncompressed_size).sum();

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

    println!("{}/ ({})", archive_path.display(), format.name());
    let depth_limit = max_depth.unwrap_or(usize::MAX);

    for (idx, entry) in entries.iter().enumerate() {
        let parts: Vec<&str> = entry.relative_path.trim_matches('/').split('/').collect();
        let depth = parts.len();
        if depth > depth_limit {
            continue;
        }

        let prefix = "  ".repeat(depth.saturating_sub(1));
        let is_last = idx == entries.len() - 1;
        let branch = if is_last { "└── " } else { "├── " };

        if entry.is_directory {
            println!("{}{}{}/", prefix, branch, entry.name);
        } else {
            println!("{}{}{} ({})", prefix, branch, entry.name, format_bytes(entry.uncompressed_size));
        }
    }

    let dir_count = entries.iter().filter(|e| e.is_directory).count();
    let file_count = entries.len() - dir_count;
    println!("
{} directories, {} files ({})", dir_count, file_count, format_bytes(total_uncompressed));

    Ok(())
}
