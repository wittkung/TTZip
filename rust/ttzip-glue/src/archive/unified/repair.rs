// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Archive repair and RS-FEC self-healing submodule for Unified Orchestrator.

use std::fs;
use std::path::Path;

use crate::archive::repair::{repair_damaged_tar, repair_damaged_zip};
use crate::archive::unified::detect::detect_format;
use crate::standards::signatures::DetectedFormat;
use crate::types::TTZipStatus;

/// Auto-detects format and repairs damaged archive.
pub fn repair_archive(
    damaged_path: &Path,
    repaired_path: &Path,
) -> Result<usize, TTZipStatus> {
    if !damaged_path.exists() {
        return Err(TTZipStatus::ErrFileNotFound);
    }

    // 1. Try Reed-Solomon Recovery Streaming Repair if record exists
    if let Ok(true) = crate::crypto::rs_fec::repair::repair_archive_file_streaming(damaged_path) {
        let _ = fs::copy(damaged_path, repaired_path);
        return Ok(1);
    }

    // 2. Format based repair (Zip vs Tar)
    let (fmt, _) = detect_format(damaged_path).unwrap_or((DetectedFormat::Unknown, None));
    match fmt {
        DetectedFormat::Tar => repair_damaged_tar(damaged_path, repaired_path),
        DetectedFormat::Zip => repair_damaged_zip(damaged_path, repaired_path),
        _ => {
            let name = damaged_path
                .file_name()
                .and_then(|n| n.to_str())
                .unwrap_or("")
                .to_lowercase();
            if name.ends_with(".tar") || name.ends_with(".tar.gz") || name.ends_with(".tgz") {
                repair_damaged_tar(damaged_path, repaired_path)
            } else {
                repair_damaged_zip(damaged_path, repaired_path)
                    .or_else(|_| repair_damaged_tar(damaged_path, repaired_path))
            }
        }
    }
}
