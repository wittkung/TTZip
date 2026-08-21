// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Subcommand execution handlers: split and join.

use crate::cli::args::JoinResultDto;
use crate::cli::format::format_bytes;
use std::fs::{self, File};
use std::io::{Read, Write};
use std::path::Path;
use std::time::Instant;
use ttzip_glue::archive::split::{SplitVolumeWriter, VirtualMultiVolumeReader, VolumeNamingScheme};

/// Parses human-readable size string (e.g. "10M", "500KB", "1G", "1048576") into byte count.
pub fn parse_size_bytes(s: &str) -> Result<u64, String> {
    let trimmed = s.trim();
    if trimmed.is_empty() {
        return Err("Volume size string cannot be empty".to_string());
    }

    let mut num_end = 0;
    for (i, c) in trimmed.char_indices() {
        if c.is_ascii_digit() || c == '.' {
            num_end = i + c.len_utf8();
        } else {
            break;
        }
    }

    if num_end == 0 {
        return Err(format!("Invalid volume size number format: {}", s));
    }

    let num_str = &trimmed[..num_end];
    let unit_str = trimmed[num_end..].trim().to_uppercase();

    let value: f64 = num_str
        .parse()
        .map_err(|e| format!("Failed to parse size number '{}': {}", num_str, e))?;

    if value <= 0.0 {
        return Err("Volume size must be strictly greater than 0".to_string());
    }

    let multiplier: u64 = match unit_str.as_str() {
        "" | "B" => 1,
        "K" | "KB" | "KIB" => 1024,
        "M" | "MB" | "MIB" => 1024 * 1024,
        "G" | "GB" | "GIB" => 1024 * 1024 * 1024,
        "T" | "TB" | "TIB" => 1024 * 1024 * 1024 * 1024,
        other => return Err(format!("Unknown size unit '{}' in '{}'", other, s)),
    };

    let total_bytes = (value * multiplier as f64) as u64;
    if total_bytes == 0 {
        return Err("Calculated volume size in bytes must be > 0".to_string());
    }

    Ok(total_bytes)
}

/// Executes headless `split` subcommand.
pub fn execute_split(
    source_archive: &Path,
    volume_size_str: &str,
    output_dir: Option<&Path>,
    naming_opt: Option<&str>,
) -> Result<(), String> {
    if !source_archive.exists() {
        return Err(format!(
            "Source archive file not found: {}",
            source_archive.display()
        ));
    }

    let chunk_size = parse_size_bytes(volume_size_str)?;
    let naming_scheme = match naming_opt.map(|s| s.to_lowercase()).as_deref() {
        Some("pkzip") | Some("zip") => VolumeNamingScheme::PkzipSpanned,
        Some("raw") => VolumeNamingScheme::RawSplit,
        _ => VolumeNamingScheme::NumberedExtension,
    };

    let base_path = if let Some(out_dir) = output_dir {
        fs::create_dir_all(out_dir)
            .map_err(|e| format!("Failed to create output directory {}: {}", out_dir.display(), e))?;
        let filename = source_archive
            .file_name()
            .ok_or_else(|| "Invalid source archive file name".to_string())?;
        out_dir.join(filename)
    } else {
        source_archive.to_path_buf()
    };

    let start_time = Instant::now();
    let mut writer = SplitVolumeWriter::new(&base_path, chunk_size, naming_scheme)
        .map_err(|e| format!("Failed to initialize SplitVolumeWriter: {}", e))?;

    let mut source_file = File::open(source_archive)
        .map_err(|e| format!("Failed to open source archive: {}", e))?;
    let mut buffer = vec![0u8; 256 * 1024];

    loop {
        let bytes_read = source_file
            .read(&mut buffer)
            .map_err(|e| format!("Failed to read source file: {}", e))?;
        if bytes_read == 0 {
            break;
        }
        writer
            .write_all(&buffer[..bytes_read])
            .map_err(|e| format!("Failed to write split volume: {}", e))?;
    }

    let volumes = writer
        .close()
        .map_err(|e| format!("Failed to finalize split volumes: {}", e))?;
    let elapsed = start_time.elapsed();

    println!(
        "Split {} into {} volumes ({}) in {:.2?}",
        source_archive.display(),
        volumes.len(),
        format_bytes(writer.total_bytes()),
        elapsed
    );
    for vol in &volumes {
        println!("  - {}", vol.display());
    }

    Ok(())
}

/// Executes headless `join` subcommand.
pub fn execute_join(first_volume: &Path, output: &Path, json: bool) -> Result<(), String> {
    if !first_volume.exists() {
        return Err(format!(
            "First volume file not found: {}",
            first_volume.display()
        ));
    }

    let start_time = Instant::now();
    let mut reader = VirtualMultiVolumeReader::open_from_any_volume(first_volume)
        .map_err(|e| format!("Failed to open multi-volume reader: {}", e))?;

    if let Some(parent) = output.parent() {
        if !parent.as_os_str().is_empty() {
            fs::create_dir_all(parent)
                .map_err(|e| format!("Failed to create output directory {}: {}", parent.display(), e))?;
        }
    }

    let mut out_file = File::create(output)
        .map_err(|e| format!("Failed to create output file {}: {}", output.display(), e))?;

    let total_copied = std::io::copy(&mut reader, &mut out_file)
        .map_err(|e| format!("Failed to copy recombined stream: {}", e))?;
    let elapsed = start_time.elapsed();

    let volume_paths = reader.volume_paths();

    if json {
        let dto = JoinResultDto {
            first_volume: first_volume.to_string_lossy().to_string(),
            output: output.to_string_lossy().to_string(),
            volume_count: volume_paths.len(),
            total_bytes: total_copied,
            volumes: volume_paths
                .iter()
                .map(|p| p.to_string_lossy().to_string())
                .collect(),
            elapsed_ms: elapsed.as_millis() as u64,
        };
        let json_str = serde_json::to_string_pretty(&dto)
            .map_err(|e| format!("Failed to serialize JSON: {}", e))?;
        println!("{}", json_str);
        return Ok(());
    }

    println!(
        "Recombined {} volumes ({}) into {} in {:.2?}",
        volume_paths.len(),
        format_bytes(total_copied),
        output.display(),
        elapsed
    );

    Ok(())
}
