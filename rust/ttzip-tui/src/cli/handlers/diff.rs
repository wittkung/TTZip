// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Subcommand execution handler: diff.

use crate::cli::args::DiffResultDto;
use crate::cli::format::{parse_archive_entries, read_archive_data_auto};
use std::collections::HashMap;
use std::path::Path;

/// Executes headless `diff` subcommand.
pub fn execute_diff(archive_a: &Path, archive_b: &Path, json: bool) -> Result<(), String> {
    if !archive_a.exists() {
        return Err(format!("Archive A not found: {}", archive_a.display()));
    }
    if !archive_b.exists() {
        return Err(format!("Archive B not found: {}", archive_b.display()));
    }

    let (_, data_a) = read_archive_data_auto(archive_a)?;
    let (_, entries_a) = parse_archive_entries(archive_a, &data_a)?;

    let (_, data_b) = read_archive_data_auto(archive_b)?;
    let (_, entries_b) = parse_archive_entries(archive_b, &data_b)?;

    let mut map_a = HashMap::new();
    for e in &entries_a {
        map_a.insert(e.relative_path.clone(), e);
    }

    let mut map_b = HashMap::new();
    for e in &entries_b {
        map_b.insert(e.relative_path.clone(), e);
    }

    let mut a_only = Vec::new();
    let mut b_only = Vec::new();
    let mut modified = Vec::new();
    let mut identical_count = 0;

    for (path, ea) in &map_a {
        if let Some(eb) = map_b.get(path) {
            if ea.uncompressed_size != eb.uncompressed_size || ea.crc32 != eb.crc32 {
                modified.push(path.clone());
            } else {
                identical_count += 1;
            }
        } else {
            a_only.push(path.clone());
        }
    }

    for path in map_b.keys() {
        if !map_a.contains_key(path) {
            b_only.push(path.clone());
        }
    }

    a_only.sort();
    b_only.sort();
    modified.sort();

    let is_identical = a_only.is_empty() && b_only.is_empty() && modified.is_empty();

    if json {
        let dto = DiffResultDto {
            archive_a: archive_a.to_string_lossy().to_string(),
            archive_b: archive_b.to_string_lossy().to_string(),
            entries_a_only: a_only,
            entries_b_only: b_only,
            modified_entries: modified,
            identical_count,
            is_identical,
        };

        let json_str = serde_json::to_string_pretty(&dto)
            .map_err(|e| format!("Failed to serialize diff JSON: {}", e))?;
        println!("{}", json_str);
        return Ok(());
    }

    println!("{:=<60}", "");
    println!("  TTZip Archive Comparison");
    println!("  Archive A: {}", archive_a.display());
    println!("  Archive B: {}", archive_b.display());
    println!("{:=<60}", "");

    if is_identical {
        println!("  Status: IDENTICAL ({} identical entries)", identical_count);
    } else {
        if !a_only.is_empty() {
            println!("  Only in A ({} items):", a_only.len());
            for p in &a_only {
                println!("    - {}", p);
            }
        }
        if !b_only.is_empty() {
            println!("  Only in B ({} items):", b_only.len());
            for p in &b_only {
                println!("    + {}", p);
            }
        }
        if !modified.is_empty() {
            println!("  Modified ({} items):", modified.len());
            for p in &modified {
                println!("    * {}", p);
            }
        }
        println!("  Identical entries: {}", identical_count);
    }
    println!("{:=<60}", "");

    Ok(())
}
