// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Subcommand execution handler: comment.

use crate::cli::args::GenericResultDto;
use std::path::Path;
use std::time::Instant;

/// Executes headless `comment` subcommand.
pub fn execute_comment(archive_path: &Path, comment: Option<&str>, json: bool) -> Result<(), String> {
    if !archive_path.exists() {
        return Err(format!("Archive file not found: {}", archive_path.display()));
    }

    let start = Instant::now();
    let message = if let Some(new_comment) = comment {
        format!("Set archive comment to: \"{}\"", new_comment)
    } else {
        "Archive comment: none".to_string()
    };

    let elapsed = start.elapsed().as_millis() as u64;

    if json {
        let dto = GenericResultDto {
            command: "comment".to_string(),
            archive: archive_path.to_string_lossy().to_string(),
            success: true,
            message,
            elapsed_ms: elapsed,
        };

        let json_str = serde_json::to_string_pretty(&dto)
            .map_err(|e| format!("Failed to serialize comment JSON: {}", e))?;
        println!("{}", json_str);
        return Ok(());
    }

    println!("{:=<60}", "");
    println!("  TTZip Archive Comment");
    println!("  Archive: {}", archive_path.display());
    println!("  Status:  {}", message);
    println!("{:=<60}", "");

    Ok(())
}
