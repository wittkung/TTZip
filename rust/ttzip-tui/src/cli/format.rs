// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Archive container format detection, unified entry info, byte size formatting, and metadata parsing.

use std::path::Path;
use ttzip_glue::sevenz::SevenZArchive;
use ttzip_glue::zip::ZipArchive;

/// Unified entry metadata extracted from any supported archive format.
#[derive(Debug, Clone)]
pub struct ArchiveEntryInfo {
    pub name: String,
    pub relative_path: String,
    pub is_directory: bool,
    pub uncompressed_size: u64,
    pub compressed_size: u64,
    pub crc32: u32,
    pub is_encrypted: bool,
}

/// Detected archive container format.
#[derive(Debug, Copy, Clone, PartialEq, Eq)]
pub enum ContainerFormat {
    Zip,
    SevenZip,
    Unknown,
}

impl ContainerFormat {
    pub fn name(&self) -> &'static str {
        match self {
            ContainerFormat::Zip => "ZIP",
            ContainerFormat::SevenZip => "7Z",
            ContainerFormat::Unknown => "UNKNOWN",
        }
    }
}

/// Detects archive container format from file extension and magic signature bytes.
pub fn detect_archive_format(path: &Path, data: &[u8]) -> ContainerFormat {
    if data.len() >= 6 && &data[0..6] == b"7z\xBC\xAF\x27\x1C" {
        return ContainerFormat::SevenZip;
    }
    if data.len() >= 4 && (&data[0..4] == b"PK\x03\x04" || &data[0..4] == b"PK\x05\x06" || &data[0..4] == b"PK\x07\x08") {
        return ContainerFormat::Zip;
    }
    if let Some(ext) = path.extension().and_then(|s| s.to_str()) {
        let ext_lower = ext.to_lowercase();
        if ext_lower == "7z" || ext_lower == "cb7" {
            return ContainerFormat::SevenZip;
        }
        if ext_lower == "zip" || ext_lower == "jar" || ext_lower == "apk" || ext_lower == "cbz" {
            return ContainerFormat::Zip;
        }
    }
    ContainerFormat::Unknown
}

/// Formats byte sizes into human-readable strings.
pub fn format_bytes(bytes: u64) -> String {
    const KB: u64 = 1024;
    const MB: u64 = KB * 1024;
    const GB: u64 = MB * 1024;

    if bytes < KB {
        format!("{} B", bytes)
    } else if bytes < MB {
        format!("{:.1} KB", bytes as f64 / KB as f64)
    } else if bytes < GB {
        format!("{:.1} MB", bytes as f64 / MB as f64)
    } else {
        format!("{:.2} GB", bytes as f64 / GB as f64)
    }
}

/// Parses archive metadata and returns unified entry records.
pub fn parse_archive_entries(path: &Path, data: &[u8]) -> Result<(ContainerFormat, Vec<ArchiveEntryInfo>), String> {
    let format = detect_archive_format(path, data);
    match format {
        ContainerFormat::Zip => {
            let archive = ZipArchive::open_slice(data).map_err(|e| format!("Failed to parse ZIP archive: {:?}", e))?;
            let mut entries = Vec::with_capacity(archive.len());
            for entry in archive.entries() {
                let name = Path::new(&entry.rel_path)
                    .file_name()
                    .map(|n| n.to_string_lossy().to_string())
                    .unwrap_or_else(|| entry.rel_path.clone());
                entries.push(ArchiveEntryInfo {
                    name,
                    relative_path: entry.rel_path.clone(),
                    is_directory: entry.is_directory,
                    uncompressed_size: entry.uncompressed_size,
                    compressed_size: entry.compressed_size,
                    crc32: entry.crc32,
                    is_encrypted: entry.is_encrypted,
                });
            }
            Ok((format, entries))
        }
        ContainerFormat::SevenZip => {
            let archive = SevenZArchive::open_slice(data).map_err(|e| format!("Failed to parse 7z archive: {:?}", e))?;
            let mut entries = Vec::with_capacity(archive.len());
            let info = archive.info();
            let is_archive_enc = info.is_encrypted;
            let mut stream_idx = 0usize;
            for file in &info.files {
                let (u_sz, crc) = if !file.is_directory && !file.is_empty_stream {
                    let sz = info.stream_sizes.get(stream_idx).copied().unwrap_or(0);
                    let c = info.stream_crcs.get(stream_idx).copied().unwrap_or(0);
                    stream_idx += 1;
                    (sz, c)
                } else {
                    (0, 0)
                };

                let name = Path::new(&file.rel_path)
                    .file_name()
                    .map(|n| n.to_string_lossy().to_string())
                    .unwrap_or_else(|| file.rel_path.clone());
                entries.push(ArchiveEntryInfo {
                    name,
                    relative_path: file.rel_path.clone(),
                    is_directory: file.is_directory,
                    uncompressed_size: u_sz,
                    compressed_size: if u_sz > 0 { info.payload_len as u64 / info.stream_sizes.len().max(1) as u64 } else { 0 },
                    crc32: crc,
                    is_encrypted: is_archive_enc,
                });
            }
            Ok((format, entries))
        }
        ContainerFormat::Unknown => Err(format!(
            "Unsupported or unrecognized archive format for: {}",
            path.display()
        )),
    }
}
