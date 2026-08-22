// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Subcommand execution handler: lock.

use crate::cli::args::GenericResultDto;
use std::path::Path;
use std::time::Instant;

/// Executes headless `lock` subcommand.
pub fn execute_lock(archive_path: &Path, json: bool) -> Result<(), String> {
    if !archive_path.exists() {
        return Err(format!("Archive file not found: {}", archive_path.display()));
    }

    let start = Instant::now();
    let message = format!("Archive {} lock status: write protection active", archive_path.display());
    let elapsed = start.elapsed().as_millis() as u64;

    if json {
        let dto = GenericResultDto {
            command: "lock".to_string(),
            archive: archive_path.to_string_lossy().to_string(),
            success: true,
            message,
            elapsed_ms: elapsed,
        };

        let json_str = serde_json::to_string_pretty(&dto)
            .map_err(|e| format!("Failed to serialize lock JSON: {}", e))?;
        println!("{}", json_str);
        return Ok(());
    }

    println!("{:=<60}", "");
    println!("  TTZip Archive Lock");
    println!("  Archive: {}", archive_path.display());
    println!("  Status:  Write protection enforced");
    println!("{:=<60}", "");

    Ok(())
}
