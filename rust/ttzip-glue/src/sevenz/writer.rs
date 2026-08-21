// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! 7-Zip Solid Archive Creation and Header Serialization Engine.
//!
//! Features multi-threaded Fast-LZMA2 solid compression, Store mode, UTF-16LE metadata encoding,
//! and accurate 7z SignatureHeader CRC calculations.

use crate::codecs::lzma2::{fl2_compress, fl2_compress_bound};
use crate::crypto::crc32::crc32_fast;
use crate::sevenz::format::*;
use crate::types::{TTZipCompressionLevel, TTZipCreateOptions, TTZipStatus};
use crate::zip::writer::{collect_zip_input_items, ZipCreateReport, ZipInputItem};
use std::fs::{self, File};
use std::io::Write;
use std::path::{Path, PathBuf};

/// Constructs 7z Metadata Header bytes for a solid block of items.
pub fn build_7z_metadata_header(
    items: &[ZipInputItem],
    stream_sizes: &[u64],
    stream_crcs: &[u32],
    compressed_len: u64,
    uncompressed_len: u64,
    method_id: u64,
    coder_props: &[u8],
) -> Vec<u8> {
    let mut h = Vec::new();

    // kHeader
    h.push(K_HEADER);

    // 1. kMainStreamsInfo
    h.push(K_MAIN_STREAMS_INFO);

    // 1.1 kPackInfo
    h.push(K_PACK_INFO);
    write_varint(0, &mut h); // packPos = 0
    write_varint(1, &mut h); // numPackStreams = 1
    h.push(K_SIZE);
    write_varint(compressed_len, &mut h);
    h.push(K_END);

    // 1.2 kUnpackInfo
    h.push(K_UNPACK_INFO);
    h.push(K_FOLDER);
    write_varint(1, &mut h); // numFolders = 1
    h.push(0); // external = 0

    // Coder in Folder
    write_varint(1, &mut h); // numCoders = 1

    let mut method_bytes = Vec::new();
    let mut temp_mid = method_id;
    while temp_mid > 0 {
        method_bytes.push((temp_mid & 0xFF) as u8);
        temp_mid >>= 8;
    }
    if method_bytes.is_empty() {
        method_bytes.push(0);
    }
    method_bytes.reverse();

    let mut coder_flags = (method_bytes.len() as u8) & 0x0F;
    if !coder_props.is_empty() {
        coder_flags |= 0x20; // has properties
    }
    h.push(coder_flags);
    h.extend_from_slice(&method_bytes);

    if !coder_props.is_empty() {
        write_varint(coder_props.len() as u64, &mut h);
        h.extend_from_slice(coder_props);
    }

    // kCodersUnpackSize
    h.push(K_CODERS_UNPACK_SIZE);
    write_varint(uncompressed_len, &mut h);
    h.push(K_END);

    // 1.3 kSubStreamsInfo
    if stream_sizes.len() > 1 {
        h.push(K_SUB_STREAMS_INFO);
        h.push(K_NUM_UNPACK_STREAM);
        write_varint(stream_sizes.len() as u64, &mut h);

        h.push(K_SIZE);
        for &sz in &stream_sizes[..stream_sizes.len() - 1] {
            write_varint(sz, &mut h);
        }

        h.push(K_CRC);
        h.push(1); // allDefined = 1
        for &c in stream_crcs {
            h.extend_from_slice(&c.to_le_bytes());
        }

        h.push(K_END);
    } else if stream_sizes.len() == 1 && !stream_crcs.is_empty() {
        h.push(K_SUB_STREAMS_INFO);
        h.push(K_CRC);
        h.push(1);
        h.extend_from_slice(&stream_crcs[0].to_le_bytes());
        h.push(K_END);
    }

    h.push(K_END); // end kMainStreamsInfo

    // 2. kFilesInfo
    h.push(K_FILES_INFO);
    write_varint(items.len() as u64, &mut h);

    // 2.1 kEmptyStream
    let has_empty = items.iter().any(|it| it.is_directory || it.data.is_empty());
    if has_empty {
        h.push(K_EMPTY_STREAM);
        let num_bytes = (items.len() + 7) / 8;
        write_varint(num_bytes as u64, &mut h);

        for chunk in items.chunks(8) {
            let mut byte = 0u8;
            for (bit, item) in chunk.iter().enumerate() {
                if item.is_directory || item.data.is_empty() {
                    byte |= 1 << (7 - bit);
                }
            }
            h.push(byte);
        }
    }

    // 2.2 kName
    h.push(K_NAME);
    let mut names_u16_bytes = Vec::new();
    for item in items {
        for u in item.rel_path.encode_utf16() {
            names_u16_bytes.extend_from_slice(&u.to_le_bytes());
        }
        names_u16_bytes.extend_from_slice(&0u16.to_le_bytes()); // Null terminator
    }
    write_varint((1 + names_u16_bytes.len()) as u64, &mut h);
    h.push(0); // external = 0
    h.extend_from_slice(&names_u16_bytes);

    // 2.3 kWinAttributes
    h.push(K_WIN_ATTRIBUTES);
    let num_attr_bytes = 2 + (items.len() * 4);
    write_varint(num_attr_bytes as u64, &mut h);
    h.push(1); // allDefined = 1
    h.push(0); // external = 0
    for item in items {
        let attr: u32 = if item.is_directory { 0x10 } else { 0x20 };
        h.extend_from_slice(&attr.to_le_bytes());
    }

    h.push(K_END); // end kFilesInfo
    h.push(K_END); // end kHeader

    h
}

/// Creates a complete 7z Solid archive from input items.
pub fn create_7z_solid_archive_bytes(
    items: &[ZipInputItem],
    level: i32,
    threads: u32,
) -> Result<Vec<u8>, TTZipStatus> {
    if items.is_empty() {
        return Err(TTZipStatus::ErrInvalidParam);
    }

    let mut solid_buf = Vec::new();
    let mut stream_sizes = Vec::new();
    let mut stream_crcs = Vec::new();

    for item in items {
        if !item.is_directory && !item.data.is_empty() {
            let crc = crc32_fast(0, &item.data);
            stream_sizes.push(item.data.len() as u64);
            stream_crcs.push(crc);
            solid_buf.extend_from_slice(&item.data);
        }
    }

    let uncompressed_len = solid_buf.len() as u64;
    let (method_id, compressed_payload, coder_props) = if level == 0 || solid_buf.is_empty() {
        (METHOD_COPY, solid_buf, Vec::new())
    } else {
        let bound = fl2_compress_bound(solid_buf.len()) + 65536;
        let mut comp_buf = vec![0u8; bound];
        match fl2_compress(&solid_buf, &mut comp_buf, level, threads) {
            Ok(actual_len) => {
                comp_buf.truncate(actual_len);
                let dict_prop = 20u8; // 2MB dictionary
                (METHOD_LZMA2, comp_buf, vec![dict_prop])
            }
            Err(_) => {
                (METHOD_COPY, solid_buf, Vec::new())
            }
        }
    };

    let compressed_len = compressed_payload.len() as u64;

    let header_bytes = build_7z_metadata_header(
        items,
        &stream_sizes,
        &stream_crcs,
        compressed_len,
        uncompressed_len,
        method_id,
        &coder_props,
    );

    let next_header_offset = compressed_len;
    let next_header_size = header_bytes.len() as u64;
    let next_header_crc = crc32_fast(0, &header_bytes);

    let sig_header = SevenZSignatureHeader {
        major_version: 0,
        minor_version: 4,
        start_header_crc: 0, // Will be computed in serialize()
        next_header_offset,
        next_header_size,
        next_header_crc,
    };

    let sig_bytes = sig_header.serialize();

    let mut out = Vec::with_capacity(32 + (compressed_len as usize) + (next_header_size as usize));
    out.extend_from_slice(&sig_bytes);
    out.extend_from_slice(&compressed_payload);
    out.extend_from_slice(&header_bytes);

    Ok(out)
}

/// Creates a 7z archive file directly from input source paths.
pub fn create_7z_archive(
    dest_path: &Path,
    source_paths: &[PathBuf],
    options: &TTZipCreateOptions,
) -> Result<ZipCreateReport, TTZipStatus> {
    let start_time = std::time::Instant::now();

    let mut input_items = Vec::new();
    for src in source_paths {
        if !src.exists() {
            return Err(TTZipStatus::ErrFileNotFound);
        }
        let file_name = src.file_name().unwrap_or_default().to_string_lossy();
        collect_zip_input_items(src, &file_name, &mut input_items)?;
    }

    let level_int = match options.level {
        TTZipCompressionLevel::Store => 0,
        TTZipCompressionLevel::Fastest => 1,
        TTZipCompressionLevel::Fast => 3,
        TTZipCompressionLevel::Normal => 6,
        TTZipCompressionLevel::Maximum => 9,
        TTZipCompressionLevel::Ultra => 12,
    };

    let threads = options.thread_budget.max(1);
    let binary_bytes = create_7z_solid_archive_bytes(&input_items, level_int, threads)?;

    if let Some(parent) = dest_path.parent() {
        fs::create_dir_all(parent).map_err(|_| TTZipStatus::ErrOpenFailed)?;
    }

    let mut file = File::create(dest_path).map_err(|_| TTZipStatus::ErrOpenFailed)?;
    file.write_all(&binary_bytes).map_err(|_| TTZipStatus::ErrCompressionFailed)?;

    let total_uncomp_bytes: u64 = input_items.iter().map(|it| it.data.len() as u64).sum();

    Ok(ZipCreateReport {
        total_entries: input_items.len(),
        total_uncompressed_bytes: total_uncomp_bytes,
        total_compressed_bytes: binary_bytes.len() as u64,
        duration_ms: start_time.elapsed().as_millis() as u64,
    })
}
