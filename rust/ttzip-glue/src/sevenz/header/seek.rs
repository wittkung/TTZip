// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! 7-Zip Seek Table and Entry Location indexing for O(1) random-access queries.

use super::models::SevenZHeaderInfo;

/// Spatial location and byte offset mapping for an individual entry in a 7z archive.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SevenZEntryLocation {
    pub file_index: usize,
    pub rel_path: String,
    pub is_directory: bool,
    pub is_empty_stream: bool,
    pub folder_index: Option<usize>,
    pub stream_index: Option<usize>,
    pub offset_in_folder: u64,
    pub uncompressed_size: u64,
    pub crc: Option<u32>,
}

/// Seek table index providing O(1) entry location lookups across solid 7z streams.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct SevenZSeekIndex {
    pub entries: Vec<SevenZEntryLocation>,
}

impl SevenZSeekIndex {
    /// Builds a random-access seek table index from parsed 7z metadata header.
    pub fn build(info: &SevenZHeaderInfo) -> Self {
        let mut entries = Vec::with_capacity(info.files.len());
        let mut stream_idx = 0usize;
        let mut current_folder_offset = 0u64;
        let folder_idx = if !info.folders.is_empty() { Some(0) } else { None };

        for (file_idx, f) in info.files.iter().enumerate() {
            if f.is_directory || f.is_empty_stream {
                entries.push(SevenZEntryLocation {
                    file_index: file_idx,
                    rel_path: f.rel_path.clone(),
                    is_directory: f.is_directory,
                    is_empty_stream: f.is_empty_stream,
                    folder_index: None,
                    stream_index: None,
                    offset_in_folder: 0,
                    uncompressed_size: 0,
                    crc: None,
                });
            } else {
                let sz = if stream_idx < info.stream_sizes.len() {
                    info.stream_sizes[stream_idx]
                } else if !info.folders.is_empty() && !info.folders[0].unpack_sizes.is_empty() {
                    info.folders[0].unpack_sizes[0].saturating_sub(current_folder_offset)
                } else {
                    0
                };
                let crc = info.stream_crcs.get(stream_idx).copied();
                entries.push(SevenZEntryLocation {
                    file_index: file_idx,
                    rel_path: f.rel_path.clone(),
                    is_directory: false,
                    is_empty_stream: false,
                    folder_index: folder_idx,
                    stream_index: Some(stream_idx),
                    offset_in_folder: current_folder_offset,
                    uncompressed_size: sz,
                    crc,
                });
                current_folder_offset += sz;
                stream_idx += 1;
            }
        }

        Self { entries }
    }

    /// Finds entry location by file index.
    #[inline]
    pub fn get_by_index(&self, index: usize) -> Option<&SevenZEntryLocation> {
        self.entries.get(index)
    }

    /// Finds entry location by relative path.
    #[inline]
    pub fn get_by_path(&self, path: &str) -> Option<&SevenZEntryLocation> {
        let normalized = path.replace('\\', "/");
        let normalized_trimmed = normalized.trim_start_matches('/');
        self.entries.iter().find(|e| {
            let e_norm = e.rel_path.replace('\\', "/");
            let e_norm_trimmed = e_norm.trim_start_matches('/');
            e_norm_trimmed == normalized_trimmed || e.rel_path == path
        })
    }
}
