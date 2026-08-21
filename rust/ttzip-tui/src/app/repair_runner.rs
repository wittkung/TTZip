// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Hardware NEON SIMD-accelerated Damaged Archive Salvage Scanner & TOC Reconstruction Engine.

use std::fs::{self, File};
use std::io::Write;
use std::path::{Path, PathBuf};
use ttzip_glue::archive::repair::find_next_pk_signature;
use ttzip_glue::types::TTZipStatus;
use ttzip_glue::zip::writer::{assemble_zip_archive, ZipCompressedItem};

/// Salvaged archive entry descriptor extracted by SIMD stream scanner.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SalvagedEntry {
    pub rel_path: String,
    pub uncompressed_size: u64,
    pub compressed_size: u64,
    pub crc32: u32,
    pub compression_method: u16,
    pub is_directory: bool,
    pub header_offset: usize,
    pub payload_offset: usize,
    pub mtime_epoch_secs: u32,
    pub is_selected: bool,
}

impl SalvagedEntry {
    /// Returns human-readable compression method algorithm name.
    pub fn method_name(&self) -> &'static str {
        match self.compression_method {
            0 => "Store",
            8 => "Deflate",
            9 => "Deflate64",
            12 => "BZIP2",
            14 => "LZMA",
            93 => "ZSTD",
            95 => "XZ",
            _ => "Unknown",
        }
    }
}

/// Repair state lifecycle stage.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum RepairStatus {
    Ready,
    Rebuilding,
    Success(usize),
    Error(String),
}

/// Interactive Corrupted Archive Repair & Salvage Wizard state machine.
#[derive(Debug, Clone)]
pub struct RepairState {
    pub damaged_path: PathBuf,
    pub output_path_input: String,
    pub is_editing_path: bool,
    pub salvaged_entries: Vec<SalvagedEntry>,
    pub selected_table_index: usize,
    pub table_scroll: usize,
    pub status: RepairStatus,
    pub detected_format: String,
    pub damaged_bytes: u64,
    pub all_selected_toggle: bool,
}

impl RepairState {
    /// Initializes repair state and executes instant NEON SIMD salvage scan.
    pub fn new(damaged_path: PathBuf, raw_data: &[u8]) -> Self {
        let (detected_format, salvaged_entries) = scan_archive_for_salvage(raw_data, &damaged_path);
        let damaged_bytes = raw_data.len() as u64;

        let default_output = if let Some(stem) = damaged_path.file_stem().and_then(|s| s.to_str()) {
            let ext = damaged_path
                .extension()
                .and_then(|s| s.to_str())
                .unwrap_or(if detected_format == "TAR" { "tar" } else { "zip" });
            let parent = damaged_path.parent().unwrap_or_else(|| Path::new("."));
            parent.join(format!("{}_repaired.{}", stem, ext)).to_string_lossy().to_string()
        } else {
            "repaired_archive.zip".to_string()
        };

        Self {
            damaged_path,
            output_path_input: default_output,
            is_editing_path: false,
            salvaged_entries,
            selected_table_index: 0,
            table_scroll: 0,
            status: RepairStatus::Ready,
            detected_format,
            damaged_bytes,
            all_selected_toggle: true,
        }
    }
}

/// Scans damaged ZIP stream using NEON SIMD signature matching and extracts valid Local Headers.
pub fn scan_salvageable_zip_entries(raw_data: &[u8]) -> Vec<SalvagedEntry> {
    let mut entries = Vec::new();
    let total_len = raw_data.len();
    let mut offset = 0;

    while let Some(pk_pos) = find_next_pk_signature(raw_data, offset) {
        if pk_pos + 30 > total_len {
            break;
        }

        let method = u16::from_le_bytes([raw_data[pk_pos + 8], raw_data[pk_pos + 9]]);
        let _mtime_dos = u16::from_le_bytes([raw_data[pk_pos + 10], raw_data[pk_pos + 11]]);
        let mdate_dos = u16::from_le_bytes([raw_data[pk_pos + 12], raw_data[pk_pos + 13]]);
        let crc32 = u32::from_le_bytes([
            raw_data[pk_pos + 14],
            raw_data[pk_pos + 15],
            raw_data[pk_pos + 16],
            raw_data[pk_pos + 17],
        ]);
        let comp_size = u32::from_le_bytes([
            raw_data[pk_pos + 18],
            raw_data[pk_pos + 19],
            raw_data[pk_pos + 20],
            raw_data[pk_pos + 21],
        ]) as usize;
        let uncomp_size = u32::from_le_bytes([
            raw_data[pk_pos + 22],
            raw_data[pk_pos + 23],
            raw_data[pk_pos + 24],
            raw_data[pk_pos + 25],
        ]) as u64;
        let fn_len = u16::from_le_bytes([raw_data[pk_pos + 26], raw_data[pk_pos + 27]]) as usize;
        let extra_len = u16::from_le_bytes([raw_data[pk_pos + 28], raw_data[pk_pos + 29]]) as usize;

        let header_len = 30 + fn_len + extra_len;
        if fn_len > 0 && pk_pos + header_len <= total_len {
            let fn_bytes = &raw_data[pk_pos + 30..pk_pos + 30 + fn_len];
            let name_str = String::from_utf8_lossy(fn_bytes).to_string();
            let clean_name = name_str.trim_matches('\0').to_string();

            if !clean_name.is_empty() {
                let payload_start = pk_pos + header_len;
                let max_payload_len = total_len.saturating_sub(payload_start);
                let actual_comp_len = comp_size.min(max_payload_len);

                let is_dir = clean_name.ends_with('/');
                let mut epoch_secs = 1700000000u32;
                let yr = ((mdate_dos >> 9) & 0x7F) as u32 + 1980;
                let mo = ((mdate_dos >> 5) & 0x0F) as u32;
                let dy = (mdate_dos & 0x1F) as u32;
                if yr >= 1980 && mo >= 1 && mo <= 12 && dy >= 1 && dy <= 31 {
                    epoch_secs = (yr - 1970) * 31536000 + mo * 2592000 + dy * 86400;
                }

                entries.push(SalvagedEntry {
                    rel_path: clean_name,
                    uncompressed_size: if uncomp_size > 0 { uncomp_size } else { actual_comp_len as u64 },
                    compressed_size: actual_comp_len as u64,
                    crc32,
                    compression_method: method,
                    is_directory: is_dir,
                    header_offset: pk_pos,
                    payload_offset: payload_start,
                    mtime_epoch_secs: epoch_secs,
                    is_selected: true,
                });
            }
        }

        let jump = 30 + fn_len + extra_len + comp_size;
        offset = pk_pos + jump.max(4);
    }

    entries
}

/// Scans raw TAR stream and extracts valid 512-byte header block entries.
pub fn scan_salvageable_tar_entries(raw_data: &[u8]) -> Vec<SalvagedEntry> {
    let mut entries = Vec::new();
    let total_len = raw_data.len();
    let mut offset = 0;

    while offset + 512 <= total_len {
        let block = &raw_data[offset..offset + 512];
        if block.iter().all(|&b| b == 0) {
            offset += 512;
            continue;
        }

        let chk_bytes = &block[148..156];
        let chk_str = std::str::from_utf8(chk_bytes).unwrap_or("").trim_matches(&['\0', ' '][..]);
        let expected_chk = u32::from_str_radix(chk_str, 8).unwrap_or(0);

        let mut calc_chk = 0u32;
        for (i, &b) in block.iter().enumerate() {
            if (148..156).contains(&i) {
                calc_chk += b' ' as u32;
            } else {
                calc_chk += b as u32;
            }
        }

        if expected_chk != 0 && (expected_chk == calc_chk || expected_chk == calc_chk.wrapping_sub(0x100)) {
            let name_bytes = &block[0..100];
            let name_str = String::from_utf8_lossy(name_bytes).trim_matches('\0').to_string();
            let size_bytes = &block[124..136];
            let size_str = std::str::from_utf8(size_bytes).unwrap_or("").trim_matches(&['\0', ' '][..]);
            let file_size = usize::from_str_radix(size_str, 8).unwrap_or(0);
            let payload_blocks = (file_size + 511) / 512;

            if !name_str.is_empty() {
                let is_dir = name_str.ends_with('/') || block[156] == b'5';
                entries.push(SalvagedEntry {
                    rel_path: name_str,
                    uncompressed_size: file_size as u64,
                    compressed_size: file_size as u64,
                    crc32: 0,
                    compression_method: 0,
                    is_directory: is_dir,
                    header_offset: offset,
                    payload_offset: offset + 512,
                    mtime_epoch_secs: 1700000000,
                    is_selected: true,
                });
            }
            offset += 512 + (payload_blocks * 512);
        } else {
            offset += 512;
        }
    }

    entries
}

/// Identifies stream format and performs salvage scanning.
pub fn scan_archive_for_salvage(raw_data: &[u8], path: &Path) -> (String, Vec<SalvagedEntry>) {
    let zip_entries = scan_salvageable_zip_entries(raw_data);
    if !zip_entries.is_empty() {
        return ("ZIP".to_string(), zip_entries);
    }

    let is_tar = path
        .file_name()
        .and_then(|s| s.to_str())
        .map(|s| s.to_lowercase().ends_with(".tar"))
        .unwrap_or(false);

    let tar_entries = scan_salvageable_tar_entries(raw_data);
    if !tar_entries.is_empty() || is_tar {
        return ("TAR".to_string(), tar_entries);
    }

    ("ZIP".to_string(), Vec::new())
}

/// Reconstructs a healthy archive at `output_path` using selected salvaged entries.
pub fn reconstruct_salvaged_archive(
    raw_data: &[u8],
    entries: &[SalvagedEntry],
    output_path: &Path,
    format_name: &str,
) -> Result<usize, TTZipStatus> {
    let selected: Vec<&SalvagedEntry> = entries.iter().filter(|e| e.is_selected).collect();
    if selected.is_empty() {
        return Err(TTZipStatus::ErrCorruptHeader);
    }

    if let Some(parent) = output_path.parent() {
        if !parent.as_os_str().is_empty() {
            let _ = fs::create_dir_all(parent);
        }
    }

    if format_name.eq_ignore_ascii_case("TAR") {
        let mut out_file = File::create(output_path).map_err(|_| TTZipStatus::ErrCompressionFailed)?;
        let total_len = raw_data.len();
        let mut count = 0;

        for entry in &selected {
            if entry.header_offset + 512 <= total_len {
                let header = &raw_data[entry.header_offset..entry.header_offset + 512];
                out_file.write_all(header).map_err(|_| TTZipStatus::ErrCompressionFailed)?;

                let payload_len = entry.uncompressed_size as usize;
                if payload_len > 0 && entry.payload_offset < total_len {
                    let avail = total_len.saturating_sub(entry.payload_offset);
                    let write_len = payload_len.min(avail);
                    let payload = &raw_data[entry.payload_offset..entry.payload_offset + write_len];
                    out_file.write_all(payload).map_err(|_| TTZipStatus::ErrCompressionFailed)?;

                    let pad = (512 - (write_len % 512)) % 512;
                    if pad > 0 {
                        out_file.write_all(&vec![0u8; pad]).map_err(|_| TTZipStatus::ErrCompressionFailed)?;
                    }
                }
                count += 1;
            }
        }
        out_file.write_all(&[0u8; 1024]).map_err(|_| TTZipStatus::ErrCompressionFailed)?;
        out_file.flush().map_err(|_| TTZipStatus::ErrCompressionFailed)?;
        Ok(count)
    } else {
        // ZIP TOC Central Directory Reconstruction
        let total_len = raw_data.len();
        let mut items = Vec::new();

        for entry in &selected {
            let payload_start = entry.payload_offset;
            let comp_len = entry.compressed_size as usize;
            let avail = total_len.saturating_sub(payload_start);
            let actual_len = comp_len.min(avail);
            let payload = raw_data[payload_start..payload_start + actual_len].to_vec();

            items.push(ZipCompressedItem {
                rel_path: entry.rel_path.clone(),
                uncompressed_size: entry.uncompressed_size,
                compressed_size: payload.len() as u64,
                crc32: entry.crc32,
                compression_method: entry.compression_method,
                actual_method: entry.compression_method,
                aes_strength: 0,
                payload,
                mtime_epoch_secs: entry.mtime_epoch_secs,
                mode: if entry.is_directory { 0o755 } else { 0o644 },
                is_directory: entry.is_directory,
                is_encrypted: false,
            });
        }

        let count = items.len();
        let assembled_bytes = assemble_zip_archive(&items)?;
        fs::write(output_path, &assembled_bytes).map_err(|_| TTZipStatus::ErrCompressionFailed)?;
        Ok(count)
    }
}
