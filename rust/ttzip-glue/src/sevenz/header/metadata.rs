// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! 7-Zip Archive Metadata Parser from mapped memory.

use super::models::SevenZHeaderInfo;
use super::stream::parse_7z_header_stream;
use crate::crypto::crc32::crc32_fast;
use crate::sevenz::format::*;
use crate::types::TTZipStatus;

/// Parses 7z Header metadata from memory mapped archive.
pub fn parse_7z_metadata(mapped: &[u8]) -> Result<SevenZHeaderInfo, TTZipStatus> {
    let sig = SevenZSignatureHeader::parse(mapped)?;
    let header_start = 32 + (sig.next_header_offset as usize);
    let header_size = sig.next_header_size as usize;

    if header_start + header_size > mapped.len() {
        return Err(TTZipStatus::ErrCorruptHeader);
    }

    let header_bytes = &mapped[header_start..header_start + header_size];

    if sig.next_header_crc != 0 && header_size > 0 {
        let computed_crc = crc32_fast(0, header_bytes);
        if computed_crc != sig.next_header_crc {
            return Err(TTZipStatus::ErrCorruptHeader);
        }
    }

    let mut info = SevenZHeaderInfo {
        payload_offset: 32,
        payload_len: sig.next_header_offset as usize,
        folders: Vec::new(),
        stream_sizes: Vec::new(),
        stream_crcs: Vec::new(),
        files: Vec::new(),
        primary_method_id: METHOD_LZMA2,
        coder_props: Vec::new(),
        is_encrypted: false,
        aes_salt: [0u8; 16],
        aes_salt_len: 0,
        aes_iv: [0u8; 16],
        aes_iv_len: 0,
        aes_num_cycles_power: 19,
    };

    if !header_bytes.is_empty() {
        if header_bytes[0] == K_ENCODED_HEADER {
            let mut sub_info = SevenZHeaderInfo::default();
            let _ = parse_7z_header_stream(&header_bytes[1..], &mut sub_info);
            info.primary_method_id = sub_info.primary_method_id;
            info.coder_props = sub_info.coder_props;
            info.folders = sub_info.folders;
            info.files = sub_info.files;
            info.stream_sizes = sub_info.stream_sizes;
            info.stream_crcs = sub_info.stream_crcs;
        } else {
            let _ = parse_7z_header_stream(header_bytes, &mut info);
        }
    }

    Ok(info)
}
