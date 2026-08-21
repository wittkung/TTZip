// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Archive container format detection, unified entry info, byte size formatting,
//! Snappy/Brotli codec parsing, and transparent multi-volume chain detection.

use std::fs;
use std::io::Read;
use std::path::{Path, PathBuf};
use ttzip_glue::archive::split::{detect_volume_chain as glue_detect_volume_chain, VirtualMultiVolumeReader};
use ttzip_glue::archive::tar::TarArchive;
use ttzip_glue::codecs::brotli::brotli_decompress_to_vec;
use ttzip_glue::codecs::snappy::snappy_frame_decode_to_vec;
use ttzip_glue::crypto::crc32::crc32_fast;
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
    Tar,
    Snappy,
    Brotli,
    TarBrotli,
    Unknown,
}

impl ContainerFormat {
    pub fn name(&self) -> &'static str {
        match self {
            ContainerFormat::Zip => "ZIP",
            ContainerFormat::SevenZip => "7Z",
            ContainerFormat::Tar => "TAR",
            ContainerFormat::Snappy => "SNAPPY",
            ContainerFormat::Brotli => "BROTLI",
            ContainerFormat::TarBrotli => "TAR.BR",
            ContainerFormat::Unknown => "UNKNOWN",
        }
    }
}

/// Automatically detects multi-volume chain segments from any seed volume path.
pub fn detect_volume_chain(path: &Path) -> std::io::Result<Vec<PathBuf>> {
    glue_detect_volume_chain(path)
}

/// Reads archive data, transparently concatenating multi-volume streams if part of a chain.
pub fn read_archive_data_auto(path: &Path) -> Result<(Vec<PathBuf>, Vec<u8>), String> {
    let chain = detect_volume_chain(path).unwrap_or_else(|_| vec![path.to_path_buf()]);
    if chain.len() > 1 {
        let mut reader = VirtualMultiVolumeReader::from_volumes(chain.clone())
            .map_err(|e| format!("Failed to open multi-volume chain: {}", e))?;
        let mut data = Vec::with_capacity(reader.total_size() as usize);
        reader
            .read_to_end(&mut data)
            .map_err(|e| format!("Failed to read multi-volume stream: {}", e))?;
        Ok((chain, data))
    } else {
        let data = fs::read(path).map_err(|e| format!("Failed to read archive {}: {}", path.display(), e))?;
        Ok((chain, data))
    }
}

/// Detects archive container format from file extension and magic signature bytes.
pub fn detect_archive_format(path: &Path, data: &[u8]) -> ContainerFormat {
    if data.len() >= 6 && &data[0..6] == b"7z\xBC\xAF\x27\x1C" {
        return ContainerFormat::SevenZip;
    }
    if data.len() >= 10 && &data[0..10] == b"\xFF\x06\x00\x00sNaPpY" {
        return ContainerFormat::Snappy;
    }
    if data.len() >= 265
        && (&data[257..262] == b"ustar"
            || &data[257..265] == b"ustar  \0"
            || &data[257..263] == b"ustar\0")
    {
        return ContainerFormat::Tar;
    }
    if data.len() >= 4
        && (&data[0..4] == b"PK\x03\x04"
            || &data[0..4] == b"PK\x05\x06"
            || &data[0..4] == b"PK\x07\x08")
    {
        return ContainerFormat::Zip;
    }

    let filename_lower = path
        .file_name()
        .and_then(|s| s.to_str())
        .map(|s| s.to_lowercase())
        .unwrap_or_default();

    if filename_lower.ends_with(".tar.br") || filename_lower.ends_with(".tbr") {
        return ContainerFormat::TarBrotli;
    }
    if filename_lower.ends_with(".br") {
        return ContainerFormat::Brotli;
    }
    if filename_lower.ends_with(".sz") || filename_lower.ends_with(".snappy") {
        return ContainerFormat::Snappy;
    }
    if filename_lower.ends_with(".tar") || filename_lower.contains(".tar.") {
        return ContainerFormat::Tar;
    }
    if filename_lower.ends_with(".7z") || filename_lower.ends_with(".cb7") || filename_lower.contains(".7z.") {
        return ContainerFormat::SevenZip;
    }
    if filename_lower.ends_with(".zip")
        || filename_lower.ends_with(".jar")
        || filename_lower.ends_with(".apk")
        || filename_lower.ends_with(".cbz")
        || filename_lower.contains(".zip.")
        || filename_lower.ends_with(".z01")
        || filename_lower.ends_with(".z02")
    {
        return ContainerFormat::Zip;
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

fn extract_tar_entries(tar: &TarArchive) -> Vec<ArchiveEntryInfo> {
    tar.entries()
        .iter()
        .map(|entry| {
            let name = Path::new(entry.path.as_ref())
                .file_name()
                .map(|n| n.to_string_lossy().to_string())
                .unwrap_or_else(|| entry.path.to_string());
            ArchiveEntryInfo {
                name,
                relative_path: entry.path.to_string(),
                is_directory: entry.is_directory,
                uncompressed_size: entry.size,
                compressed_size: entry.size,
                crc32: 0,
                is_encrypted: false,
            }
        })
        .collect()
}

/// Parses archive metadata and returns unified entry records.
pub fn parse_archive_entries(
    path: &Path,
    data: &[u8],
) -> Result<(ContainerFormat, Vec<ArchiveEntryInfo>), String> {
    let format = detect_archive_format(path, data);
    match format {
        ContainerFormat::Zip => {
            let archive =
                ZipArchive::open_slice(data).map_err(|e| format!("Failed to parse ZIP archive: {:?}", e))?;
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
            let archive =
                SevenZArchive::open_slice(data).map_err(|e| format!("Failed to parse 7z archive: {:?}", e))?;
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
                    compressed_size: if u_sz > 0 {
                        info.payload_len as u64 / info.stream_sizes.len().max(1) as u64
                    } else {
                        0
                    },
                    crc32: crc,
                    is_encrypted: is_archive_enc,
                });
            }
            Ok((format, entries))
        }
        ContainerFormat::Tar => {
            let archive =
                TarArchive::open_slice(data).map_err(|e| format!("Failed to parse TAR archive: {:?}", e))?;
            Ok((format, extract_tar_entries(&archive)))
        }
        ContainerFormat::Snappy => {
            let decompressed = snappy_frame_decode_to_vec(data, 1024 * 1024 * 512)
                .map_err(|e| format!("Failed to decompress Snappy stream: {:?}", e))?;

            let file_name = path
                .file_name()
                .and_then(|s| s.to_str())
                .unwrap_or("decompressed.bin");
            let is_tar = file_name.to_lowercase().contains(".tar.");

            if is_tar {
                if let Ok(tar) = TarArchive::open_slice(&decompressed) {
                    if !tar.is_empty() {
                        return Ok((format, extract_tar_entries(&tar)));
                    }
                }
            }

            let inner_name = file_name
                .strip_suffix(".sz")
                .or_else(|| file_name.strip_suffix(".snappy"))
                .unwrap_or(file_name)
                .to_string();

            let crc = crc32_fast(0, &decompressed);
            let entry = ArchiveEntryInfo {
                name: inner_name.clone(),
                relative_path: inner_name,
                is_directory: false,
                uncompressed_size: decompressed.len() as u64,
                compressed_size: data.len() as u64,
                crc32: crc,
                is_encrypted: false,
            };
            Ok((format, vec![entry]))
        }
        ContainerFormat::Brotli | ContainerFormat::TarBrotli => {
            let decompressed = brotli_decompress_to_vec(data, 1024 * 1024 * 512)
                .map_err(|e| format!("Failed to decompress Brotli stream: {:?}", e))?;

            let file_name = path
                .file_name()
                .and_then(|s| s.to_str())
                .unwrap_or("decompressed.bin");
            let is_tar = format == ContainerFormat::TarBrotli
                || file_name.to_lowercase().contains(".tar.")
                || file_name.to_lowercase().ends_with(".tbr");

            if is_tar {
                if let Ok(tar) = TarArchive::open_slice(&decompressed) {
                    if !tar.is_empty() {
                        return Ok((format, extract_tar_entries(&tar)));
                    }
                }
            }

            let inner_name = file_name
                .strip_suffix(".br")
                .unwrap_or(file_name)
                .to_string();

            let crc = crc32_fast(0, &decompressed);
            let entry = ArchiveEntryInfo {
                name: inner_name.clone(),
                relative_path: inner_name,
                is_directory: false,
                uncompressed_size: decompressed.len() as u64,
                compressed_size: data.len() as u64,
                crc32: crc,
                is_encrypted: false,
            };
            Ok((format, vec![entry]))
        }
        ContainerFormat::Unknown => Err(format!(
            "Unsupported or unrecognized archive format for: {}",
            path.display()
        )),
    }
}
