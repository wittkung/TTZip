// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Zero-allocation magic sniffer and SFX / compound extension deduction engine.

use std::fs::File;
use std::io::{self, Read, Seek, SeekFrom};
use std::path::Path;

use super::anchors::Anchor;
use super::signatures::{CompoundFormat, DetectedFormat, PRIORITIZED_SIGNATURES};

/// Maximum scan window for Self-Extracting (SFX) archive detection (64 KB).
const SFX_SCAN_LIMIT: usize = 65536;

/// Detailed result of format sniffing.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SniffResult {
    pub format: DetectedFormat,
    pub compound_format: Option<CompoundFormat>,
    pub is_sfx: bool,
    pub sfx_offset: usize,
    pub description: &'static str,
    pub mime_type: &'static str,
    pub primary_extension: &'static str,
    pub confidence: u8,
}

impl SniffResult {
    /// Constructs an unknown format result.
    pub const fn unknown() -> Self {
        Self {
            format: DetectedFormat::Unknown,
            compound_format: None,
            is_sfx: false,
            sfx_offset: 0,
            description: "Unknown Binary Stream",
            mime_type: "application/octet-stream",
            primary_extension: "bin",
            confidence: 0,
        }
    }
}

/// Detects the archive format directly from an in-memory byte buffer.
///
/// Performs zero heap allocations during magic inspection.
pub fn detect_format_buffer(buffer: &[u8], filename_hint: Option<&str>) -> SniffResult {
    if buffer.is_empty() {
        return SniffResult::unknown();
    }

    // 1. Direct signature matching across prioritized table
    for entry in PRIORITIZED_SIGNATURES {
        if buffer.len() < entry.min_total_size {
            continue;
        }

        if let Some(slice) = entry.anchor.slice_buffer(buffer, entry.magic.len()) {
            if slice == entry.magic {
                let compound = deduce_compound_format(entry.format, filename_hint);
                return SniffResult {
                    format: entry.format,
                    compound_format: compound,
                    is_sfx: false,
                    sfx_offset: 0,
                    description: entry.description,
                    mime_type: entry.format.mime_type(),
                    primary_extension: compound
                        .map(|c| c.primary_extension())
                        .unwrap_or_else(|| entry.format.primary_extension()),
                    confidence: 100,
                };
            }
        }
    }

    // 2. Trailing EOCD search for ZIP if header was corrupted or spanned
    if let Some(zip_res) = scan_trailing_zip_eocd(buffer, filename_hint) {
        return zip_res;
    }

    // 3. Self-Extracting (SFX) archive scan (MZ/PE header prefix)
    if let Some(sfx_res) = scan_sfx_archive(buffer, filename_hint) {
        return sfx_res;
    }

    SniffResult::unknown()
}

/// Detects archive format from a filesystem path without loading entire file into memory.
pub fn detect_format_file<P: AsRef<Path>>(path: P) -> io::Result<SniffResult> {
    let path_ref = path.as_ref();
    let filename_hint = path_ref.file_name().and_then(|n| n.to_str());

    let mut file = File::open(path_ref)?;
    let file_len = file.metadata()?.len() as usize;

    if file_len == 0 {
        return Ok(SniffResult::unknown());
    }

    // Read up to 64KB prefix
    let prefix_len = file_len.min(SFX_SCAN_LIMIT);
    let mut prefix_buf = vec![0u8; prefix_len];
    file.read_exact(&mut prefix_buf)?;

    // Check prefix against standard signatures
    for entry in PRIORITIZED_SIGNATURES {
        if file_len < entry.min_total_size {
            continue;
        }

        match entry.anchor {
            Anchor::Head(_) | Anchor::TarOffset(_) => {
                if let Some(slice) = entry.anchor.slice_buffer(&prefix_buf, entry.magic.len()) {
                    if slice == entry.magic {
                        let compound = deduce_compound_format(entry.format, filename_hint);
                        return Ok(SniffResult {
                            format: entry.format,
                            compound_format: compound,
                            is_sfx: false,
                            sfx_offset: 0,
                            description: entry.description,
                            mime_type: entry.format.mime_type(),
                            primary_extension: compound
                                .map(|c| c.primary_extension())
                                .unwrap_or_else(|| entry.format.primary_extension()),
                            confidence: 100,
                        });
                    }
                }
            }
            Anchor::Sector(16) => {
                if file_len >= 32768 + 2048 && prefix_len >= 0x8001 + 5 && &prefix_buf[0x8001..0x8001 + 5] == b"CD001" {
                    return Ok(SniffResult {
                        format: DetectedFormat::Iso,
                        compound_format: None,
                        is_sfx: false,
                        sfx_offset: 0,
                        description: "ISO 9660 Disk Image",
                        mime_type: DetectedFormat::Iso.mime_type(),
                        primary_extension: "iso",
                        confidence: 100,
                    });
                }
            }
            Anchor::Tail(512) => {
                if file_len >= 512 {
                    let mut tail_buf = [0u8; 512];
                    file.seek(SeekFrom::End(-512))?;
                    file.read_exact(&mut tail_buf)?;
                    if &tail_buf[0..4] == b"koly" {
                        return Ok(SniffResult {
                            format: DetectedFormat::Dmg,
                            compound_format: None,
                            is_sfx: false,
                            sfx_offset: 0,
                            description: "Apple Disk Image (UDIF DMG)",
                            mime_type: DetectedFormat::Dmg.mime_type(),
                            primary_extension: "dmg",
                            confidence: 100,
                        });
                    }
                }
            }
            _ => {}
        }
    }

    // Check SFX scan on prefix
    if let Some(sfx_res) = scan_sfx_archive(&prefix_buf, filename_hint) {
        return Ok(sfx_res);
    }

    // Fallback: check trailing ZIP EOCD
    if file_len >= 22 {
        let eocd_window = file_len.min(65557);
        let mut eocd_buf = vec![0u8; eocd_window];
        file.seek(SeekFrom::End(-(eocd_window as i64)))?;
        file.read_exact(&mut eocd_buf)?;
        if let Some(zip_res) = scan_trailing_zip_eocd(&eocd_buf, filename_hint) {
            return Ok(zip_res);
        }
    }

    Ok(SniffResult::unknown())
}

/// Deduces compound archive format from compression type and filename extension.
fn deduce_compound_format(format: DetectedFormat, filename_hint: Option<&str>) -> Option<CompoundFormat> {
    let name = filename_hint?.to_lowercase();
    match format {
        DetectedFormat::Gzip if name.ends_with(".tar.gz") || name.ends_with(".tgz") => Some(CompoundFormat::TarGz),
        DetectedFormat::Bzip2 if name.ends_with(".tar.bz2") || name.ends_with(".tbz2") || name.ends_with(".tbz") => Some(CompoundFormat::TarBz2),
        DetectedFormat::Xz if name.ends_with(".tar.xz") || name.ends_with(".txz") => Some(CompoundFormat::TarXz),
        DetectedFormat::Zstd if name.ends_with(".tar.zst") || name.ends_with(".tzst") => Some(CompoundFormat::TarZstd),
        DetectedFormat::Lz4 if name.ends_with(".tar.lz4") => Some(CompoundFormat::TarLz4),
        _ => None,
    }
}

/// Scans for Self-Extracting (SFX) archives embedded inside PE / MZ executables.
fn scan_sfx_archive(buffer: &[u8], filename_hint: Option<&str>) -> Option<SniffResult> {
    if buffer.len() < 64 || buffer[0] != b'M' || buffer[1] != b'Z' {
        return None;
    }

    let scan_limit = buffer.len().min(SFX_SCAN_LIMIT);
    let scan_window = &buffer[..scan_limit];
    let mut offset = 64;

    while offset + 8 <= scan_window.len() {
        if scan_window[offset..].starts_with(b"7z\xBC\xAF\x27\x1C") {
            return Some(SniffResult {
                format: DetectedFormat::SevenZip,
                compound_format: None,
                is_sfx: true,
                sfx_offset: offset,
                description: "7-Zip Self-Extracting Archive (SFX)",
                mime_type: DetectedFormat::SevenZip.mime_type(),
                primary_extension: "exe",
                confidence: 95,
            });
        }
        if scan_window[offset..].starts_with(b"PK\x03\x04") {
            let compound = deduce_compound_format(DetectedFormat::Zip, filename_hint);
            return Some(SniffResult {
                format: DetectedFormat::Zip,
                compound_format: compound,
                is_sfx: true,
                sfx_offset: offset,
                description: "ZIP Self-Extracting Archive (SFX)",
                mime_type: DetectedFormat::Zip.mime_type(),
                primary_extension: "exe",
                confidence: 95,
            });
        }
        if scan_window[offset..].starts_with(b"Rar!\x1A\x07\x00") || scan_window[offset..].starts_with(b"Rar!\x1A\x07\x01\x00") {
            return Some(SniffResult {
                format: DetectedFormat::Rar,
                compound_format: None,
                is_sfx: true,
                sfx_offset: offset,
                description: "RAR Self-Extracting Archive (SFX)",
                mime_type: DetectedFormat::Rar.mime_type(),
                primary_extension: "exe",
                confidence: 95,
            });
        }
        offset += 4;
    }
    None
}

/// Scans trailing portion of buffer for ZIP End of Central Directory (EOCD).
fn scan_trailing_zip_eocd(buffer: &[u8], filename_hint: Option<&str>) -> Option<SniffResult> {
    if buffer.len() < 22 {
        return None;
    }

    let scan_len = buffer.len().min(65557);
    let start = buffer.len() - scan_len;
    let window = &buffer[start..];

    for i in (0..=window.len() - 22).rev() {
        if &window[i..i + 4] == b"PK\x05\x06" {
            let comment_len = u16::from_le_bytes([window[i + 20], window[i + 21]]) as usize;
            if i + 22 + comment_len <= window.len() {
                let compound = deduce_compound_format(DetectedFormat::Zip, filename_hint);
                return Some(SniffResult {
                    format: DetectedFormat::Zip,
                    compound_format: compound,
                    is_sfx: false,
                    sfx_offset: 0,
                    description: "ZIP Archive (EOCD Verified)",
                    mime_type: DetectedFormat::Zip.mime_type(),
                    primary_extension: "zip",
                    confidence: 90,
                });
            }
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_detect_zip_and_compound() {
        let mut zip_header = vec![0u8; 30];
        zip_header[0..4].copy_from_slice(b"PK\x03\x04");
        let result = detect_format_buffer(&zip_header, Some("archive.zip"));
        assert_eq!(result.format, DetectedFormat::Zip);
        assert_eq!(result.is_sfx, false);

        let mut gz_header = vec![0u8; 10];
        gz_header[0..2].copy_from_slice(b"\x1F\x8B");
        let result_gz = detect_format_buffer(&gz_header, Some("source.tar.gz"));
        assert_eq!(result_gz.format, DetectedFormat::Gzip);
        assert_eq!(result_gz.compound_format, Some(CompoundFormat::TarGz));
    }

    #[test]
    fn test_detect_sfx_and_dmg() {
        let mut sfx_stub = vec![0u8; 1024];
        sfx_stub[0] = b'M';
        sfx_stub[1] = b'Z';
        sfx_stub[256..262].copy_from_slice(b"7z\xBC\xAF\x27\x1C");
        let result = detect_format_buffer(&sfx_stub, Some("setup.exe"));
        assert_eq!(result.format, DetectedFormat::SevenZip);
        assert_eq!(result.is_sfx, true);
        assert_eq!(result.sfx_offset, 256);

        let mut dmg_tail = vec![0u8; 1024];
        dmg_tail[512..516].copy_from_slice(b"koly");
        let result_dmg = detect_format_buffer(&dmg_tail, Some("Installer.dmg"));
        assert_eq!(result_dmg.format, DetectedFormat::Dmg);
    }
}
