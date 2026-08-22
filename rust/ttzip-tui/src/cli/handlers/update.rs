// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Subcommand execution handler: update.

use crate::cli::args::GenericResultDto;
use std::path::{Path, PathBuf};
use std::time::Instant;
use ttzip_glue::archive::in_place_edit::InPlaceArchiveSession;

/// Executes headless `update` subcommand.
pub fn execute_update(
    archive_path: &Path,
    sources: &[PathBuf],
    _level: u8,
    json: bool,
) -> Result<(), String> {
    if !archive_path.exists() {
        return Err(format!("Archive file not found: {}", archive_path.display()));
    }

    let start = Instant::now();
    let mut session = InPlaceArchiveSession::begin(archive_path, None)
        .map_err(|e| format!("Failed to begin in-place update session: {:?}", e))?;

    for src in sources {
        let entry_name = src
            .file_name()
            .map(|s| s.to_string_lossy().to_string())
            .unwrap_or_else(|| "unnamed".to_string());

        session.replace(&entry_name, src)
            .map_err(|e| format!("Failed to stage update for {}: {:?}", entry_name, e))?;
    }

    session
        .commit()
        .map_err(|e| format!("Failed to commit in-place update: {:?}", e))?;

    let elapsed = start.elapsed().as_millis() as u64;
    let message = format!("Updated {} source items into {}", sources.len(), archive_path.display());

    if json {
        let dto = GenericResultDto {
            command: "update".to_string(),
            archive: archive_path.to_string_lossy().to_string(),
            success: true,
            message,
            elapsed_ms: elapsed,
        };

        let json_str = serde_json::to_string_pretty(&dto)
            .map_err(|e| format!("Failed to serialize update JSON: {}", e))?;
        println!("{}", json_str);
        return Ok(());
    }

    println!("{:=<60}", "");
    println!("  TTZip In-Place Update");
    println!("  Archive: {}", archive_path.display());
    println!("  Items Synchronized: {}", sources.len());
    println!("  Elapsed: {} ms", elapsed);
    println!("{:=<60}", "");

    Ok(())
}
