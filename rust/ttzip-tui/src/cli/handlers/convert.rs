// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Subcommand execution handler: convert.

use crate::cli::handlers::create::execute_create;
use crate::cli::handlers::extract::execute_extract;
use std::path::Path;
use std::time::Instant;

/// Executes headless `convert` subcommand.
pub fn execute_convert(
    source_archive: &Path,
    destination_archive: &Path,
    format: Option<&str>,
    level: u8,
) -> Result<(), String> {
    if !source_archive.exists() {
        return Err(format!("Source archive not found: {}", source_archive.display()));
    }

    let start = Instant::now();
    let unique_name = format!("ttzip_conv_{}_{}", std::process::id(), start.elapsed().as_nanos());
    let staging_path = std::env::temp_dir().join(unique_name);
    std::fs::create_dir_all(&staging_path)
        .map_err(|e| format!("Failed to create staging directory for conversion: {}", e))?;

    println!("-> Extracting source archive {}...", source_archive.display());
    let extract_res = execute_extract(source_archive, Some(&staging_path), None, 4, false);
    if let Err(e) = extract_res {
        let _ = std::fs::remove_dir_all(&staging_path);
        return Err(e);
    }

    println!("-> Recompressing into destination {} (level: {})...", destination_archive.display(), level);
    let sources = vec![staging_path.clone()];
    let create_res = execute_create(
        destination_archive,
        &sources,
        format,
        level,
        None,
        4,
        None,
    );
    let _ = std::fs::remove_dir_all(&staging_path);
    create_res?;

    let elapsed = start.elapsed().as_millis();
    println!("✅ Converted {} -> {} successfully ({}ms).", source_archive.display(), destination_archive.display(), elapsed);

    Ok(())
}
