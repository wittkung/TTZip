// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Format detection and format resolution submodule for Unified Orchestrator.

use std::path::Path;
use crate::standards::signatures::{CompoundFormat, DetectedFormat};
use crate::standards::sniffer::detect_format_file;
use crate::types::{TTZipArchiveFormat, TTZipStatus};

/// Detects format of an archive from file headers with extension fallback.
pub fn detect_format(path: &Path) -> Result<(DetectedFormat, Option<CompoundFormat>), TTZipStatus> {
    let sniff = detect_format_file(path).map_err(|_| TTZipStatus::ErrFileNotFound)?;
    if sniff.format != DetectedFormat::Unknown {
        return Ok((sniff.format, sniff.compound_format));
    }

    // Extension fallback
    let ext_str = path.file_name().and_then(|n| n.to_str()).unwrap_or("");
    let lower = ext_str.to_lowercase();
    if lower.ends_with(".zip") {
        Ok((DetectedFormat::Zip, None))
    } else if lower.ends_with(".7z") || lower.ends_with(".cb7") {
        Ok((DetectedFormat::SevenZip, None))
    } else if lower.ends_with(".tar.gz") || lower.ends_with(".tgz") {
        Ok((DetectedFormat::Gzip, Some(CompoundFormat::TarGz)))
    } else if lower.ends_with(".tar.bz2") || lower.ends_with(".tbz2") {
        Ok((DetectedFormat::Bzip2, Some(CompoundFormat::TarBz2)))
    } else if lower.ends_with(".tar.xz") || lower.ends_with(".txz") {
        Ok((DetectedFormat::Xz, Some(CompoundFormat::TarXz)))
    } else if lower.ends_with(".tar.zst") || lower.ends_with(".tzst") {
        Ok((DetectedFormat::Zstd, Some(CompoundFormat::TarZstd)))
    } else if lower.ends_with(".tar") {
        Ok((DetectedFormat::Tar, None))
    } else if lower.ends_with(".rar") {
        Ok((DetectedFormat::Rar, None))
    } else if lower.ends_with(".cab") {
        Ok((DetectedFormat::Cab, None))
    } else if lower.ends_with(".iso") {
        Ok((DetectedFormat::Iso, None))
    } else if lower.ends_with(".dmg") {
        Ok((DetectedFormat::Dmg, None))
    } else if lower.ends_with(".xar") || lower.ends_with(".pkg") {
        Ok((DetectedFormat::Xar, None))
    } else if lower.ends_with(".lzh") || lower.ends_with(".lha") {
        Ok((DetectedFormat::Lzh, None))
    } else if lower.ends_with(".ar") || lower.ends_with(".deb") {
        Ok((DetectedFormat::Ar, None))
    } else if lower.ends_with(".lzfse") {
        Ok((DetectedFormat::Lzfse, None))
    } else if lower.ends_with(".sz") || lower.ends_with(".snappy") {
        Ok((DetectedFormat::Snappy, None))
    } else if lower.ends_with(".lz") || lower.ends_with(".lzip") {
        Ok((DetectedFormat::Lzip, None))
    } else {
        Ok((DetectedFormat::Unknown, None))
    }
}

/// Resolves target archive creation format from explicit format and destination path.
pub fn resolve_create_format(format: TTZipArchiveFormat, dest_path: &Path) -> TTZipArchiveFormat {
    if format != TTZipArchiveFormat::Auto {
        return format;
    }

    let name = dest_path
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or("")
        .to_lowercase();

    if name.ends_with(".tar.gz") || name.ends_with(".tgz") || name.ends_with(".gz") {
        TTZipArchiveFormat::TarGz
    } else if name.ends_with(".tar.bz2") || name.ends_with(".tbz2") || name.ends_with(".bz2") {
        TTZipArchiveFormat::TarBz2
    } else if name.ends_with(".tar.xz") || name.ends_with(".txz") || name.ends_with(".xz") {
        TTZipArchiveFormat::TarXz
    } else if name.ends_with(".tar.zst") || name.ends_with(".tzst") || name.ends_with(".zst") {
        TTZipArchiveFormat::TarZstd
    } else if name.ends_with(".7z") || name.ends_with(".cb7") {
        TTZipArchiveFormat::SevenZip
    } else if name.ends_with(".tar") {
        TTZipArchiveFormat::Tar
    } else if name.ends_with(".dmg") {
        TTZipArchiveFormat::Dmg
    } else if name.ends_with(".lzfse") {
        TTZipArchiveFormat::Lzfse
    } else if name.ends_with(".sz") || name.ends_with(".snappy") {
        TTZipArchiveFormat::Snappy
    } else {
        TTZipArchiveFormat::Zip
    }
}
