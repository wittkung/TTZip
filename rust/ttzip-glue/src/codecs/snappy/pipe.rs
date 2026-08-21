// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Snappy 4MB In / 4MB Out bounded streaming compression and decompression pipelines.
//!
//! Strictly enforces memory bounds for file-to-file and stream-to-stream processing.

use crate::types::TTZipStatus;
use snap::read::FrameDecoder;
use snap::write::FrameEncoder;
use std::fs::File;
use std::io::{Read, Write};
use std::path::Path;

/// Bounded pipe chunk buffer size: 4MB In / 4MB Out.
pub const SNAPPY_PIPE_BUFFER_SIZE: usize = 4 * 1024 * 1024; // 4MB

/// Streams uncompressed data from `reader`, compresses into Snappy framing stream, and writes to `writer`.
pub fn snappy_compress_stream_pipe<R: Read, W: Write>(
    reader: &mut R,
    writer: &mut W,
    progress_callback: Option<&dyn Fn(u64, u64) -> bool>,
) -> Result<(u64, u64), TTZipStatus> {
    let mut in_buf = vec![0u8; SNAPPY_PIPE_BUFFER_SIZE];
    let mut total_read: u64 = 0;
    let mut total_written: u64 = 0;

    let mut encoder = FrameEncoder::new(writer);

    loop {
        let bytes_read = reader.read(&mut in_buf).map_err(|_| TTZipStatus::ErrOpenFailed)?;
        if bytes_read == 0 {
            break;
        }

        total_read += bytes_read as u64;
        encoder
            .write_all(&in_buf[..bytes_read])
            .map_err(|_| TTZipStatus::ErrCompressionFailed)?;

        if let Some(cb) = progress_callback {
            if !cb(total_read, total_written) {
                return Err(TTZipStatus::Cancelled);
            }
        }
    }

    let inner_writer = encoder.into_inner().map_err(|_| TTZipStatus::ErrCompressionFailed)?;
    inner_writer.flush().map_err(|_| TTZipStatus::ErrCompressionFailed)?;

    total_written = total_read;
    Ok((total_read, total_written))
}

/// Streams Snappy framed data from `reader`, decompresses, and writes uncompressed bytes to `writer`.
pub fn snappy_decompress_stream_pipe<R: Read, W: Write>(
    reader: &mut R,
    writer: &mut W,
    progress_callback: Option<&dyn Fn(u64, u64) -> bool>,
) -> Result<(u64, u64), TTZipStatus> {
    let mut decoder = FrameDecoder::new(reader);
    let mut out_buf = vec![0u8; SNAPPY_PIPE_BUFFER_SIZE];

    let mut total_read: u64 = 0;
    let mut total_written: u64 = 0;

    loop {
        let bytes_decompressed = match decoder.read(&mut out_buf) {
            Ok(0) => break,
            Ok(n) => n,
            Err(_) => return Err(TTZipStatus::ErrCorruptHeader),
        };

        writer
            .write_all(&out_buf[..bytes_decompressed])
            .map_err(|_| TTZipStatus::ErrExtractionFailed)?;
        total_written += bytes_decompressed as u64;

        if let Some(cb) = progress_callback {
            if !cb(total_read, total_written) {
                return Err(TTZipStatus::Cancelled);
            }
        }
    }

    writer.flush().map_err(|_| TTZipStatus::ErrExtractionFailed)?;
    total_read = total_written;
    Ok((total_read, total_written))
}

/// Compresses a file on disk to Snappy framing format with progress callback.
pub fn snappy_compress_file(
    src_path: &Path,
    dst_path: &Path,
    progress_callback: Option<&dyn Fn(u64, u64) -> bool>,
) -> Result<(u64, u64), TTZipStatus> {
    if !src_path.exists() {
        return Err(TTZipStatus::ErrFileNotFound);
    }
    if let Some(parent) = dst_path.parent() {
        let _ = std::fs::create_dir_all(parent);
    }
    let mut src_file = File::open(src_path).map_err(|_| TTZipStatus::ErrOpenFailed)?;
    let mut dst_file = File::create(dst_path).map_err(|_| TTZipStatus::ErrOpenFailed)?;
    snappy_compress_stream_pipe(&mut src_file, &mut dst_file, progress_callback)
}

/// Decompresses a Snappy framed file on disk with progress callback.
pub fn snappy_decompress_file(
    src_path: &Path,
    dst_path: &Path,
    progress_callback: Option<&dyn Fn(u64, u64) -> bool>,
) -> Result<(u64, u64), TTZipStatus> {
    if !src_path.exists() {
        return Err(TTZipStatus::ErrFileNotFound);
    }
    if let Some(parent) = dst_path.parent() {
        let _ = std::fs::create_dir_all(parent);
    }
    let mut src_file = File::open(src_path).map_err(|_| TTZipStatus::ErrOpenFailed)?;
    let mut dst_file = File::create(dst_path).map_err(|_| TTZipStatus::ErrOpenFailed)?;
    snappy_decompress_stream_pipe(&mut src_file, &mut dst_file, progress_callback)
}
