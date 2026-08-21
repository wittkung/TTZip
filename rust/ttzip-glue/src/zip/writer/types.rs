// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! ZIP archive writer data types, DOS timestamp conversion, and item collection.

use crate::types::TTZipStatus;
use std::fs;
use std::path::Path;

/// Input item descriptor for ZIP compression.
#[derive(Debug, Clone)]
pub struct ZipInputItem {
    pub rel_path: String,
    pub data: Vec<u8>,
    pub mtime_epoch_secs: u32,
    pub mode: u32,
    pub is_directory: bool,
}

/// Compressed item result ready for binary layout.
#[derive(Debug, Clone)]
pub struct ZipCompressedItem {
    pub rel_path: String,
    pub uncompressed_size: u64,
    pub compressed_size: u64,
    pub crc32: u32,
    pub compression_method: u16,
    pub actual_method: u16,
    pub aes_strength: u8,
    pub payload: Vec<u8>,
    pub mtime_epoch_secs: u32,
    pub mode: u32,
    pub is_directory: bool,
    pub is_encrypted: bool,
}

/// Detailed report from an archive creation operation.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct ZipCreateReport {
    pub total_entries: usize,
    pub total_uncompressed_bytes: u64,
    pub total_compressed_bytes: u64,
    pub duration_ms: u64,
}

/// Converts Unix epoch seconds to DOS time (time: u16, date: u16).
pub fn unix_to_dos_time(epoch_secs: u32) -> (u16, u16) {
    // Simple DOS timestamp conversion
    let days_since_1970 = (epoch_secs / 86400) as i64;
    let secs_of_day = epoch_secs % 86400;

    let hour = (secs_of_day / 3600) as u16;
    let min = ((secs_of_day % 3600) / 60) as u16;
    let sec = ((secs_of_day % 60) / 2) as u16;
    let dos_time = (hour << 11) | (min << 5) | sec;

    // Approximate year/month/day
    let mut year = 1970;
    let mut days_left = days_since_1970;
    loop {
        let leap = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
        let days_in_year = if leap { 366 } else { 365 };
        if days_left < days_in_year {
            break;
        }
        days_left -= days_in_year;
        year += 1;
    }

    let month_days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    let leap = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
    let mut month = 1u16;
    for &d in &month_days {
        let dim = if month == 2 && leap { d + 1 } else { d };
        if days_left < dim as i64 {
            break;
        }
        days_left -= dim as i64;
        month += 1;
    }
    let day = (days_left + 1) as u16;
    let dos_year = (year.max(1980) - 1980).clamp(0, 127) as u16;
    let dos_date = (dos_year << 9) | (month << 5) | day;

    (dos_time, dos_date)
}

/// Recursively collects files and directories into `ZipInputItem` list.
pub fn collect_zip_input_items(
    base_src: &Path,
    rel_prefix: &str,
    out_items: &mut Vec<ZipInputItem>,
) -> Result<(), TTZipStatus> {
    let metadata = fs::symlink_metadata(base_src).map_err(|_| TTZipStatus::ErrFileNotFound)?;

    let is_dir = metadata.is_dir();
    let mtime_secs = metadata
        .modified()
        .ok()
        .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
        .map(|d| d.as_secs() as u32)
        .unwrap_or(0);

    #[cfg(unix)]
    let mode = {
        use std::os::unix::fs::MetadataExt;
        metadata.mode()
    };
    #[cfg(not(unix))]
    let mode = if is_dir { 0o755 } else { 0o644 };

    let mut item_rel = rel_prefix.to_string();
    if is_dir && !item_rel.is_empty() && !item_rel.ends_with('/') {
        item_rel.push('/');
    }

    if !item_rel.is_empty() {
        if is_dir {
            out_items.push(ZipInputItem {
                rel_path: item_rel.clone(),
                data: Vec::new(),
                mtime_epoch_secs: mtime_secs,
                mode,
                is_directory: true,
            });
        } else {
            let data = fs::read(base_src).map_err(|_| TTZipStatus::ErrOpenFailed)?;
            out_items.push(ZipInputItem {
                rel_path: item_rel,
                data,
                mtime_epoch_secs: mtime_secs,
                mode,
                is_directory: false,
            });
        }
    }

    if is_dir {
        let entries = fs::read_dir(base_src).map_err(|_| TTZipStatus::ErrOpenFailed)?;
        for entry in entries.flatten() {
            let path = entry.path();
            let file_name = path.file_name().unwrap_or_default().to_string_lossy();
            let child_rel = if rel_prefix.is_empty() {
                file_name.to_string()
            } else {
                format!("{}/{}", rel_prefix.trim_end_matches('/'), file_name)
            };
            collect_zip_input_items(&path, &child_rel, out_items)?;
        }
    }

    Ok(())
}
