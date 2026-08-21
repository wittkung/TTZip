// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! VFS Entry Metadata representation.

use serde::{Deserialize, Serialize};

/// Clean, safe representation of an archive entry's metadata.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct VfsEntryMeta {
    pub path: String,
    pub uncompressed_size: u64,
    pub compressed_size: u64,
    pub crc32: u32,
    pub mtime_epoch_secs: i64,
    pub mode: u32,
    pub is_directory: bool,
    pub is_encrypted: bool,
    #[serde(default)]
    pub entry_idx: Option<usize>,
}

impl From<&ttzip_glue::TTZipEntryMetadata> for VfsEntryMeta {
    fn from(m: &ttzip_glue::TTZipEntryMetadata) -> Self {
        let path = if !m.path.is_null() {
            unsafe { std::ffi::CStr::from_ptr(m.path) }
                .to_str()
                .unwrap_or("")
                .to_string()
        } else {
            String::new()
        };
        Self {
            path,
            uncompressed_size: m.uncompressed_size,
            compressed_size: m.compressed_size,
            crc32: m.crc32,
            mtime_epoch_secs: m.mtime_epoch_secs,
            mode: m.mode,
            is_directory: m.is_directory,
            is_encrypted: m.is_encrypted,
            entry_idx: None,
        }
    }
}
