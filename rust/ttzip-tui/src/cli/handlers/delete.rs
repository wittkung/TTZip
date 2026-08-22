// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Subcommand execution handler: delete.

use crate::cli::args::GenericResultDto;
use std::path::Path;
use std::time::Instant;
use ttzip_glue::archive::in_place_edit::InPlaceArchiveSession;

/// Executes headless `delete` subcommand.
pub fn execute_delete(archive_path: &Path, entries: &[String], json: bool) -> Result<(), String> {
    if !archive_path.exists() {
        return Err(format!("Archive file not found: {}", archive_path.display()));
    }

    let start = Instant::now();
    let mut session = InPlaceArchiveSession::begin(archive_path, None)
        .map_err(|e| format!("Failed to begin in-place session: {:?}", e))?;

    for entry in entries {
        session.delete(entry)
            .map_err(|e| format!("Failed to stage delete for {}: {:?}", entry, e))?;
    }

    session
        .commit()
        .map_err(|e| format!("Failed to commit in-place deletion: {:?}", e))?;

    let elapsed = start.elapsed().as_millis() as u64;
    let message = format!("Deleted {} entries from {}", entries.len(), archive_path.display());

    if json {
        let dto = GenericResultDto {
            command: "delete".to_string(),
            archive: archive_path.to_string_lossy().to_string(),
            success: true,
            message,
            elapsed_ms: elapsed,
        };

        let json_str = serde_json::to_string_pretty(&dto)
            .map_err(|e| format!("Failed to serialize delete JSON: {}", e))?;
        println!("{}", json_str);
        return Ok(());
    }

    println!("{:=<60}", "");
    println!("  TTZip In-Place Deletion");
    println!("  Archive: {}", archive_path.display());
    println!("  Entries Deleted: {}", entries.len());
    println!("  Elapsed: {} ms", elapsed);
    println!("{:=<60}", "");

    Ok(())
}
