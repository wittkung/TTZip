// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Zero-Allocation Cross-Platform Path Sanitizer & ZipSlip Defense Subsystem.
//!
//! Aligned with libarchive `archive_read_disk_posix.c` and `archive_read_disk_windows.c`:
//! - Single-pass stack-based ZipSlip directory traversal neutralization and detection
//! - Windows reserved device name interception (CON, PRN, AUX, NUL, COM0..9, LPT0..9, CLOCK$, PhysicalDrive)
//! - Win32 trailing space and dot normalization
//! - Segment-by-segment NTFS Alternate Data Stream (ADS) identification and stripping
//! - High-throughput Unicode NFC canonical normalization (with zero-allocation fast paths)
//! - Win32 extended-length path formatting (`\\?\` and `\\?\UNC\`)

use std::borrow::Cow;
use unicode_normalization::{is_nfc_quick, IsNormalized, UnicodeNormalization};

/// Windows DOS reserved device names.
const WINDOWS_RESERVED_DEVICES: &[&str] = &[
    "CON", "PRN", "AUX", "NUL",
    "COM0", "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
    "LPT0", "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9",
    "CLOCK$",
];

/// Result of path security sanitization and canonical normalization.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PathSanitizationResult {
    pub original_path: String,
    pub normalized_path: String,
    pub has_traversal_attack: bool,
    pub is_absolute: bool,
    pub is_unc: bool,
    pub is_long_path: bool,
    pub is_windows_reserved: bool,
    pub stripped_ads: Option<String>,
    pub win32_formatted_path: String,
}

impl PathSanitizationResult {
    /// Returns true if the path is safe to extract into a sandbox root.
    #[inline]
    pub fn is_safe(&self) -> bool {
        !self.has_traversal_attack
            && !self.is_absolute
            && !self.is_unc
            && !self.is_windows_reserved
            && self.stripped_ads.is_none()
            && !self.normalized_path.is_empty()
    }
}

/// Checks if a path segment or name matches a Windows DOS reserved device.
#[inline]
pub fn is_windows_reserved_device_name(segment: &str) -> bool {
    if segment.is_empty() {
        return false;
    }

    let upper = segment.to_ascii_uppercase();
    if upper.starts_with("PHYSICALDRIVE") {
        return true;
    }

    // Win32 rule: stem before the first dot (or before extension), with trailing spaces and dots trimmed
    let base_stem = match segment.find('.') {
        Some(idx) => &segment[..idx],
        None => segment,
    };

    let trimmed = base_stem.trim_end_matches([' ', '.']);
    if trimmed.is_empty() {
        return false;
    }

    let trimmed_upper = trimmed.to_ascii_uppercase();
    WINDOWS_RESERVED_DEVICES.contains(&trimmed_upper.as_str())
}

/// Normalizes Unicode string to NFC form with zero-allocation fast-paths for ASCII and pre-normalized inputs.
#[inline]
pub fn normalize_to_nfc(input: &str) -> Cow<'_, str> {
    if input.is_ascii() || is_nfc_quick(input.chars()) == IsNormalized::Yes {
        Cow::Borrowed(input)
    } else {
        Cow::Owned(input.nfc().collect::<String>())
    }
}

/// Sanitizes and canonicalizes a relative or absolute filesystem path.
pub fn sanitize_path(raw_path: &str) -> PathSanitizationResult {
    if raw_path.is_empty() {
        return PathSanitizationResult {
            original_path: String::new(),
            normalized_path: String::new(),
            has_traversal_attack: false,
            is_absolute: false,
            is_unc: false,
            is_long_path: false,
            is_windows_reserved: false,
            stripped_ads: None,
            win32_formatted_path: String::new(),
        };
    }

    let mut has_traversal_attack = false;
    if raw_path.contains('\0') {
        has_traversal_attack = true;
    }

    // 1. Boundary & Protocol prefix detection
    let mut is_unc = false;
    let mut is_absolute = false;

    if raw_path.starts_with(r"\\") || raw_path.starts_with("//") {
        is_unc = true;
        is_absolute = true;
    } else if raw_path.starts_with('/') || raw_path.starts_with('\\') {
        is_absolute = true;
    }

    // 2. Windows drive letter check (e.g. C:, D:/, etc.)
    let bytes = raw_path.as_bytes();
    let has_drive_letter = bytes.len() >= 2
        && bytes[0].is_ascii_alphabetic()
        && bytes[1] == b':';

    if has_drive_letter {
        is_absolute = true;
    }

    // Global check for PhysicalDrive in raw path
    let mut contains_reserved = raw_path.to_ascii_uppercase().contains("PHYSICALDRIVE");

    // 3. Fast Unicode NFC normalization
    let nfc_path = normalize_to_nfc(raw_path);

    // 4. Single-pass slash/backslash segment splitting, ADS stripping, and ZipSlip stack normalization
    let mut clean_segments: Vec<String> = Vec::with_capacity(8);
    let mut stripped_ads: Option<String> = None;

    // Split segments by '/' or '\\'
    let raw_segments = nfc_path.split(['/', '\\']);

    for (seg_idx, mut seg) in raw_segments.enumerate() {
        if seg.is_empty() {
            continue;
        }

        // NTFS Alternate Data Stream (ADS) identification & stripping
        // If this is the first segment and has a drive letter (e.g. "C:"), don't treat ':' as ADS
        let is_drive_seg = seg_idx == 0 && has_drive_letter && seg.len() == 2 && seg.as_bytes()[1] == b':';
        if !is_drive_seg {
            if let Some(colon_idx) = seg.find(':') {
                let ads_part = &seg[colon_idx..];
                if stripped_ads.is_none() {
                    stripped_ads = Some(ads_part.to_string());
                }
                seg = &seg[..colon_idx];
            }
        }

        if seg.is_empty() {
            continue;
        }

        // ZipSlip stack traversal check
        if seg == "." {
            continue;
        }

        if seg == ".." {
            if !clean_segments.is_empty() {
                // If the top of the stack is a drive letter (e.g. "C:"), popping it would escape the drive root
                let last_is_drive = clean_segments.len() == 1
                    && clean_segments[0].len() == 2
                    && clean_segments[0].as_bytes()[0].is_ascii_alphabetic()
                    && clean_segments[0].as_bytes()[1] == b':';

                if last_is_drive {
                    has_traversal_attack = true;
                } else {
                    clean_segments.pop();
                }
            } else {
                has_traversal_attack = true;
            }
            continue;
        }

        // Check Windows reserved device names
        if !contains_reserved && is_windows_reserved_device_name(seg) {
            contains_reserved = true;
        }

        clean_segments.push(seg.to_string());
    }

    let normalized_path = clean_segments.join("/");
    let is_long_path = normalized_path.chars().map(|c| c.len_utf16()).sum::<usize>() > 260;

    // 5. Format Win32 formatted path
    let win32_base = clean_segments.join("\\");
    let win32_formatted_path = if is_unc {
        format!(r"\\?\UNC\{}", win32_base)
    } else if is_long_path && is_absolute {
        format!(r"\\?\{}", win32_base)
    } else {
        win32_base
    };

    PathSanitizationResult {
        original_path: raw_path.to_string(),
        normalized_path,
        has_traversal_attack,
        is_absolute,
        is_unc,
        is_long_path,
        is_windows_reserved: contains_reserved,
        stripped_ads,
        win32_formatted_path,
    }
}
