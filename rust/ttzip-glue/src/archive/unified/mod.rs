// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Unified Archive Lifecycle Orchestrator Engine.
//!
//! Supports:
//! 1. Zero-copy / stream auto-detection across 17 archive/compression formats.
//! 2. Single-entry and multi-file recursive archive creation with optional encryption and split volumes.
//! 3. Two-stage secure extraction with ZipSlip defense, APFS extent preallocation, and bottom-up metadata.
//! 4. Non-destructive archive inspection with optional automatic charset detection.
//! 5. Self-healing archive repair integrating RS-FEC streaming and damaged header recovery.

pub mod create;
pub mod detect;
pub mod extract;
pub mod inspect;
pub mod repair;
#[cfg(test)]
pub mod tests_detection;
#[cfg(test)]
pub mod tests_lifecycle;

use std::path::{Path, PathBuf};

use crate::standards::signatures::{CompoundFormat, DetectedFormat};
use crate::types::{
    TTZipArchiveFormat, TTZipCreateOptions, TTZipExtractOptions, TTZipInspectCallback, TTZipStatus,
};
use libc::c_void;

/// Unified Archive Orchestrator Engine.
pub struct UnifiedArchiveOrchestrator;

impl UnifiedArchiveOrchestrator {
    /// Detects format of an archive from file headers with extension fallback.
    #[inline]
    pub fn detect_format(path: &Path) -> Result<(DetectedFormat, Option<CompoundFormat>), TTZipStatus> {
        detect::detect_format(path)
    }

    /// Resolves target archive creation format from explicit format and destination path.
    #[inline]
    pub fn resolve_create_format(format: TTZipArchiveFormat, dest_path: &Path) -> TTZipArchiveFormat {
        detect::resolve_create_format(format, dest_path)
    }

    /// Recursively compresses source paths into the destination archive path.
    #[inline]
    pub fn create_archive(
        source_paths: &[PathBuf],
        destination_path: &Path,
        options: &TTZipCreateOptions,
        split_volume_size_bytes: u64,
    ) -> Result<(), TTZipStatus> {
        create::create_archive(source_paths, destination_path, options, split_volume_size_bytes)
    }

    /// Extracts an archive to destination directory with security verification and APFS preallocation.
    #[inline]
    pub fn extract_archive(
        archive_path: &Path,
        destination_path: &Path,
        options: &TTZipExtractOptions,
    ) -> Result<(), TTZipStatus> {
        extract::extract_archive(archive_path, destination_path, options)
    }

    /// Inspects an archive and invokes the callback for every discovered entry metadata item.
    #[inline]
    pub fn inspect_archive(
        archive_path: &Path,
        password: Option<&str>,
        detect_encoding: bool,
        callback: TTZipInspectCallback,
        user_data: *mut c_void,
    ) -> Result<usize, TTZipStatus> {
        inspect::inspect_archive(archive_path, password, detect_encoding, callback, user_data)
    }

    /// Auto-detects format and repairs damaged archive.
    #[inline]
    pub fn repair_archive(
        damaged_path: &Path,
        repaired_path: &Path,
    ) -> Result<usize, TTZipStatus> {
        repair::repair_archive(damaged_path, repaired_path)
    }
}
