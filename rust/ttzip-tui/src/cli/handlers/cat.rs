// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Subcommand execution handler: cat / view.

use crate::cli::format::{detect_archive_format, read_archive_data_auto, ContainerFormat};
use std::ffi::CString;
use std::io::Write;
use std::path::Path;
use ttzip_glue::archive::tar::TarArchive;
use ttzip_glue::sevenz::SevenZArchive;
use ttzip_glue::zip::ZipArchive;

/// Executes headless `cat` subcommand, writing entry payload to stdout.
pub fn execute_cat(
    archive_path: &Path,
    entry_path: &str,
    password: Option<&str>,
) -> Result<(), String> {
    if !archive_path.exists() {
        return Err(format!("Archive file not found: {}", archive_path.display()));
    }

    let (_volumes, data) = read_archive_data_auto(archive_path)?;
    let format = detect_archive_format(archive_path, &data);

    let password_c = password.map(|p| CString::new(p).unwrap_or_default());
    let _password_ptr = password_c.as_ref().map(|c| c.as_ptr()).unwrap_or(std::ptr::null());

    let normalized_target = entry_path.trim_start_matches('/');

    let payload: Vec<u8> = match format {
        ContainerFormat::Zip => {
            let archive = ZipArchive::open_slice(&data)
                .map_err(|e| format!("Failed to open ZIP archive: {:?}", e))?;
            let mut found_data = None;
            for (i, entry) in archive.entries().iter().enumerate() {
                let entry_name = entry.rel_path.trim_start_matches('/');
                if entry_name == normalized_target {
                    let decompressed = archive.extract_entry_bytes(i, password)
                        .map_err(|e| format!("Failed to decompress entry {}: {:?}", entry_path, e))?;
                    found_data = Some(decompressed);
                    break;
                }
            }
            found_data.ok_or_else(|| format!("Entry {} not found in ZIP archive", entry_path))?
        }
        ContainerFormat::SevenZip => {
            let archive = SevenZArchive::open_slice(&data)
                .map_err(|e| format!("Failed to open 7z archive: {:?}", e))?;
            let mut found_data = None;
            for (i, file) in archive.files().iter().enumerate() {
                let entry_name = file.rel_path.trim_start_matches('/');
                if entry_name == normalized_target {
                    let decompressed = archive.extract_entry_bytes(i, password)
                        .map_err(|e| format!("Failed to decompress entry {}: {:?}", entry_path, e))?;
                    found_data = Some(decompressed);
                    break;
                }
            }
            found_data.ok_or_else(|| format!("Entry {} not found in 7z archive", entry_path))?
        }
        ContainerFormat::Tar => {
            let archive = TarArchive::open_slice(&data)
                .map_err(|e| format!("Failed to open TAR archive: {:?}", e))?;
            let mut found_data = None;
            for (i, entry) in archive.entries().iter().enumerate() {
                let entry_name = entry.path.trim_start_matches('/');
                if entry_name == normalized_target {
                    let decompressed = archive.extract_entry_bytes(i)
                        .map_err(|e| format!("Failed to extract TAR entry {}: {:?}", entry_path, e))?;
                    found_data = Some(decompressed.to_vec());
                    break;
                }
            }
            found_data.ok_or_else(|| format!("Entry {} not found in TAR archive", entry_path))?
        }
        _ => {
            return Err(format!("Direct cat not supported for format {:?}", format.name()));
        }
    };

    let mut stdout = std::io::stdout().lock();
    stdout.write_all(&payload)
        .map_err(|e| format!("Failed to write payload to stdout: {}", e))?;
    stdout.flush()
        .map_err(|e| format!("Failed to flush stdout: {}", e))?;

    Ok(())
}
