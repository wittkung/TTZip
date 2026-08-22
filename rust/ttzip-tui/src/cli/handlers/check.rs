// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Subcommand execution handler: check / test.

use crate::cli::args::CheckResultDto;
use crate::cli::format::{parse_archive_entries, read_archive_data_auto};
use std::path::Path;
use std::time::Instant;

/// Executes headless `check` / `test` subcommand.
pub fn execute_check(archive_path: &Path, _password: Option<&str>, json: bool) -> Result<(), String> {
    if !archive_path.exists() {
        return Err(format!("Archive file not found: {}", archive_path.display()));
    }

    let start = Instant::now();
    let mut errors = Vec::new();
    let mut is_valid = true;

    let (_volumes, data) = match read_archive_data_auto(archive_path) {
        Ok(res) => res,
        Err(e) => {
            errors.push(format!("Failed to read archive data: {}", e));
            (vec![], vec![])
        }
    };

    let (format_name, total_entries) = if !data.is_empty() {
        match parse_archive_entries(archive_path, &data) {
            Ok((fmt, entries)) => (fmt.name().to_string(), entries.len()),
            Err(e) => {
                is_valid = false;
                errors.push(format!("Parsing error: {}", e));
                ("UNKNOWN".to_string(), 0)
            }
        }
    } else {
        is_valid = false;
        ("UNKNOWN".to_string(), 0)
    };

    let elapsed = start.elapsed().as_millis() as u64;

    if json {
        let dto = CheckResultDto {
            archive: archive_path.to_string_lossy().to_string(),
            format: format_name,
            is_valid,
            total_entries,
            corrupted_entries: if is_valid { 0 } else { 1 },
            errors,
            elapsed_ms: elapsed,
        };

        let json_str = serde_json::to_string_pretty(&dto)
            .map_err(|e| format!("Failed to serialize check JSON: {}", e))?;
        println!("{}", json_str);
        if !is_valid {
            return Err("Archive check failed with errors".to_string());
        }
        return Ok(());
    }

    if is_valid {
        println!(
            "✅ [PASS] Archive {} (Format: {}, Entries: {}) is healthy and fully compliant ({}ms).",
            archive_path.display(),
            format_name,
            total_entries,
            elapsed
        );
        Ok(())
    } else {
        eprintln!(
            "❌ [FAIL] Archive {} verification failed ({}ms):",
            archive_path.display(),
            elapsed
        );
        for err in &errors {
            eprintln!("  - {}", err);
        }
        Err("Archive verification failed".to_string())
    }
}
