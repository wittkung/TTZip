// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Subcommand execution handler: info / inspect.

use crate::cli::args::InfoResultDto;
use crate::cli::format::{format_bytes, parse_archive_entries, read_archive_data_auto};
use std::path::Path;

/// Executes headless `info` subcommand.
pub fn execute_info(archive_path: &Path, json: bool) -> Result<(), String> {
    if !archive_path.exists() {
        return Err(format!("Archive file not found: {}", archive_path.display()));
    }

    let (volumes, data) = read_archive_data_auto(archive_path)?;
    let (format, entries) = parse_archive_entries(archive_path, &data)?;

    let total_uncompressed: u64 = entries.iter().map(|e| e.uncompressed_size).sum();
    let total_compressed: u64 = entries.iter().map(|e| e.compressed_size).sum();
    let is_encrypted = entries.iter().any(|e| e.is_encrypted);
    let ratio = if total_uncompressed > 0 {
        (total_compressed as f64 / total_uncompressed as f64) * 100.0
    } else {
        0.0
    };

    if json {
        let dto = InfoResultDto {
            archive: archive_path.to_string_lossy().to_string(),
            format: format.name().to_string(),
            total_entries: entries.len(),
            uncompressed_size: total_uncompressed,
            compressed_size: total_compressed,
            compression_ratio: ratio,
            is_encrypted,
            is_multi_volume: volumes.len() > 1,
            volumes_count: volumes.len(),
            comment: None,
        };

        let json_str = serde_json::to_string_pretty(&dto)
            .map_err(|e| format!("Failed to serialize info JSON: {}", e))?;
        println!("{}", json_str);
        return Ok(());
    }

    println!("{:=<60}", "");
    println!("  TTZip Archive Inspection Report");
    println!("{:=<60}", "");
    println!("  Path:               {}", archive_path.display());
    println!("  Format:             {}", format.name());
    println!("  Entries Count:      {}", entries.len());
    println!("  Uncompressed Size:  {}", format_bytes(total_uncompressed));
    println!("  Compressed Size:    {}", format_bytes(total_compressed));
    println!("  Compression Ratio:  {:.2}%", ratio);
    println!("  Encryption:         {}", if is_encrypted { "Yes (AES/ZipCrypto)" } else { "None" });
    println!("  Multi-Volume:       {}", if volumes.len() > 1 { format!("Yes ({} parts)", volumes.len()) } else { "No".to_string() });
    println!("{:=<60}", "");

    Ok(())
}
