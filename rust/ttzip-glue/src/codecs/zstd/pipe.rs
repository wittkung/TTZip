// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Zstandard 4MB In / 4MB Out bounded streaming compression and decompression pipelines.
//!
//! Enforces strict <16MB RSS memory bounds during multi-gigabyte compression/decompression,
//! eliminating high-memory consumption and Out-Of-Memory (OOM) failures.

use super::cctx::ZstdCCtx;
use super::dctx::ZstdDCtx;
use super::types::*;
use crate::types::TTZipStatus;
use std::io::{Read, Write};

/// Bounded pipe chunk buffer size: 4MB In / 4MB Out.
pub const ZSTD_PIPE_BUFFER_SIZE: usize = 4 * 1024 * 1024; // 4MB

/// Streams uncompressed data from `reader`, compresses it via Zstandard with bounded memory,
/// and writes compressed frames to `writer`.
pub fn zstd_compress_stream_pipe<R: Read, W: Write>(
    reader: &mut R,
    writer: &mut W,
    config: &ZstdConfig,
    progress_callback: Option<&dyn Fn(u64, u64) -> bool>,
) -> Result<(u64, u64), TTZipStatus> {
    let mut cctx = ZstdCCtx::new()?;
    cctx.apply_config(config)?;

    let mut in_buf = vec![0u8; ZSTD_PIPE_BUFFER_SIZE];
    let mut out_buf = vec![0u8; ZSTD_PIPE_BUFFER_SIZE];

    let mut total_read: u64 = 0;
    let mut total_written: u64 = 0;

    loop {
        let bytes_read = reader.read(&mut in_buf).map_err(|_| TTZipStatus::ErrOpenFailed)?;
        if bytes_read == 0 {
            // End of input: flush and finalize frame
            let mut in_struct = ZstdInBuffer {
                src: std::ptr::null(),
                size: 0,
                pos: 0,
            };
            loop {
                let mut out_struct = ZstdOutBuffer {
                    dst: out_buf.as_mut_ptr() as *mut libc::c_void,
                    capacity: out_buf.len(),
                    pos: 0,
                };
                let remaining = cctx.compress_stream(&mut in_struct, &mut out_struct, ZstdEndDirective::End)?;
                if out_struct.pos > 0 {
                    writer.write_all(&out_buf[..out_struct.pos]).map_err(|_| TTZipStatus::ErrCompressionFailed)?;
                    total_written += out_struct.pos as u64;
                }
                if remaining == 0 {
                    break;
                }
            }
            break;
        }

        total_read += bytes_read as u64;
        let mut in_struct = ZstdInBuffer {
            src: in_buf.as_ptr() as *const libc::c_void,
            size: bytes_read,
            pos: 0,
        };

        while in_struct.pos < in_struct.size {
            let mut out_struct = ZstdOutBuffer {
                dst: out_buf.as_mut_ptr() as *mut libc::c_void,
                capacity: out_buf.len(),
                pos: 0,
            };
            let _ = cctx.compress_stream(&mut in_struct, &mut out_struct, ZstdEndDirective::Continue)?;
            if out_struct.pos > 0 {
                writer.write_all(&out_buf[..out_struct.pos]).map_err(|_| TTZipStatus::ErrCompressionFailed)?;
                total_written += out_struct.pos as u64;
            }
        }

        if let Some(cb) = progress_callback {
            if !cb(total_read, total_written) {
                return Err(TTZipStatus::Cancelled);
            }
        }
    }

    writer.flush().map_err(|_| TTZipStatus::ErrCompressionFailed)?;
    Ok((total_read, total_written))
}

/// Streams compressed data from `reader`, decompresses via Zstandard with bounded memory,
/// and writes uncompressed frames to `writer`.
pub fn zstd_decompress_stream_pipe<R: Read, W: Write>(
    reader: &mut R,
    writer: &mut W,
    progress_callback: Option<&dyn Fn(u64, u64) -> bool>,
) -> Result<(u64, u64), TTZipStatus> {
    let mut dctx = ZstdDCtx::new()?;

    let mut in_buf = vec![0u8; ZSTD_PIPE_BUFFER_SIZE];
    let mut out_buf = vec![0u8; ZSTD_PIPE_BUFFER_SIZE];

    let mut total_read: u64 = 0;
    let mut total_written: u64 = 0;

    loop {
        let bytes_read = reader.read(&mut in_buf).map_err(|_| TTZipStatus::ErrOpenFailed)?;
        if bytes_read == 0 {
            break;
        }

        total_read += bytes_read as u64;
        let mut in_struct = ZstdInBuffer {
            src: in_buf.as_ptr() as *const libc::c_void,
            size: bytes_read,
            pos: 0,
        };

        while in_struct.pos < in_struct.size {
            let mut out_struct = ZstdOutBuffer {
                dst: out_buf.as_mut_ptr() as *mut libc::c_void,
                capacity: out_buf.len(),
                pos: 0,
            };
            let prev_in_pos = in_struct.pos;
            let _ = dctx.decompress_stream(&mut in_struct, &mut out_struct)?;
            if out_struct.pos > 0 {
                writer.write_all(&out_buf[..out_struct.pos]).map_err(|_| TTZipStatus::ErrExtractionFailed)?;
                total_written += out_struct.pos as u64;
            }
            if in_struct.pos == prev_in_pos && out_struct.pos == 0 {
                break;
            }
        }

        if let Some(cb) = progress_callback {
            if !cb(total_read, total_written) {
                return Err(TTZipStatus::Cancelled);
            }
        }
    }

    writer.flush().map_err(|_| TTZipStatus::ErrExtractionFailed)?;
    Ok((total_read, total_written))
}
