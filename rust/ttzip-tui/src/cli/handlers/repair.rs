// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Subcommand execution handler: repair.

use crate::cli::args::RepairResultDto;
use std::fs;
use std::path::Path;
use std::time::Instant;
use ttzip_glue::archive::repair::{repair_damaged_tar, repair_damaged_zip};

/// Executes headless `repair` subcommand for self-healing corrupt archives.
pub fn execute_repair(
    damaged_archive: &Path,
    output: &Path,
    format_opt: Option<&str>,
    json: bool,
) -> Result<(), String> {
    if !damaged_archive.exists() {
        return Err(format!(
            "Damaged archive file not found: {}",
            damaged_archive.display()
        ));
    }

    if let Some(parent) = output.parent() {
        if !parent.as_os_str().is_empty() {
            fs::create_dir_all(parent)
                .map_err(|e| format!("Failed to create output directory {}: {}", parent.display(), e))?;
        }
    }

    let start_time = Instant::now();

    // Determine target repair engine (ZIP vs TAR)
    let is_tar = if let Some(fmt) = format_opt {
        fmt.eq_ignore_ascii_case("tar")
    } else {
        let name_lower = damaged_archive
            .file_name()
            .and_then(|s| s.to_str())
            .map(|s| s.to_lowercase())
            .unwrap_or_default();
        name_lower.ends_with(".tar")
    };

    let (format_name, salvaged_count) = if is_tar {
        let count = repair_damaged_tar(damaged_archive, output)
            .map_err(|e| format!("TAR repair failed: {:?}", e))?;
        ("TAR", count)
    } else {
        match repair_damaged_zip(damaged_archive, output) {
            Ok(count) => ("ZIP", count),
            Err(e) => {
                // If zip failed and no format was explicitly given, try tar
                if format_opt.is_none() {
                    if let Ok(tar_count) = repair_damaged_tar(damaged_archive, output) {
                        ("TAR", tar_count)
                    } else {
                        return Err(format!("ZIP self-healing repair failed: {:?}", e));
                    }
                } else {
                    return Err(format!("ZIP self-healing repair failed: {:?}", e));
                }
            }
        }
    };

    let elapsed = start_time.elapsed();

    if json {
        let dto = RepairResultDto {
            damaged_archive: damaged_archive.to_string_lossy().to_string(),
            repaired_archive: output.to_string_lossy().to_string(),
            format: format_name.to_string(),
            salvaged_entries: salvaged_count,
            elapsed_ms: elapsed.as_millis() as u64,
        };
        let json_str = serde_json::to_string_pretty(&dto)
            .map_err(|e| format!("Failed to serialize repair JSON: {}", e))?;
        println!("{}", json_str);
        return Ok(());
    }

    println!("{:=<80}", "");
    println!("TTZip Archive Self-Healing Repair Report");
    println!("{:=<80}", "");
    println!("Damaged Source:  {}", damaged_archive.display());
    println!("Repaired Output: {}", output.display());
    println!("Archive Format:  {}", format_name);
    println!("Salvaged Files:  {}", salvaged_count);
    println!("Duration:        {:.2?}", elapsed);
    println!("Status:          SUCCESS (Healthy structure restored)");
    println!("{:=<80}", "");

    Ok(())
}
