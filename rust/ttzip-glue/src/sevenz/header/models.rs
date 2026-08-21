// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Data models for 7z Header metadata.

/// Metadata for an individual file inside a 7z archive.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct SevenZFileMeta {
    pub rel_path: String,
    pub is_directory: bool,
    pub is_empty_stream: bool,
    pub mtime_epoch_secs: Option<i64>,
    pub mode: u32,
}

/// Coder description within a 7z Folder block.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct SevenZCoder {
    pub method_id: u64,
    pub num_in_streams: u64,
    pub num_out_streams: u64,
    pub properties: Vec<u8>,
}

/// Folder block defining compression and filter chain for a solid stream.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct SevenZFolder {
    pub coders: Vec<SevenZCoder>,
    pub unpack_sizes: Vec<u64>,
    pub crc: Option<u32>,
}

/// Complete parsed 7z Header information.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct SevenZHeaderInfo {
    pub payload_offset: usize,
    pub payload_len: usize,
    pub folders: Vec<SevenZFolder>,
    pub stream_sizes: Vec<u64>,
    pub stream_crcs: Vec<u32>,
    pub files: Vec<SevenZFileMeta>,
    pub primary_method_id: u64,
    pub coder_props: Vec<u8>,
    pub is_encrypted: bool,
    pub aes_salt: [u8; 16],
    pub aes_salt_len: usize,
    pub aes_iv: [u8; 16],
    pub aes_iv_len: usize,
    pub aes_num_cycles_power: u32,
}
