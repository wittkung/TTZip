// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Unified codec driver for multi-algorithm matrix benchmarking.
//!
//! Executes compression and decompression across Libdeflate, Zstd, LZ4, LZFSE, Snappy, Brotli, and Bzip2.

use crate::codecs::{
    brotli::{brotli_compress, brotli_compress_bound, brotli_decompress},
    deflate::{deflate_compress, deflate_compress_bound, deflate_decompress},
    fast_blocks::{
        lz4_compress_bound, lz4_compress_fast, lz4_decompress, lzfse_compress, lzfse_decompress,
        snappy_compress, snappy_decompress, snappy_max_compressed_length,
    },
    zstd::{zstd_compress, zstd_compress_bound, zstd_decompress},
};
use crate::types::TTZipStatus;
use serde::{Deserialize, Serialize};

// MARK: - Native C Bzip2 Declarations

extern "C" {
    fn BZ2_bzBuffToBuffCompress(
        dest: *mut libc::c_char,
        destLen: *mut libc::c_uint,
        source: *const libc::c_char,
        sourceLen: libc::c_uint,
        blockSize100k: libc::c_int,
        verbosity: libc::c_int,
        workFactor: libc::c_int,
    ) -> libc::c_int;

    fn BZ2_bzBuffToBuffDecompress(
        dest: *mut libc::c_char,
        destLen: *mut libc::c_uint,
        source: *const libc::c_char,
        sourceLen: libc::c_uint,
        small: libc::c_int,
        verbosity: libc::c_int,
    ) -> libc::c_int;
}

fn bzip2_compress(src: &[u8], dst: &mut [u8], level: i32) -> Result<usize, TTZipStatus> {
    if src.is_empty() {
        return Ok(0);
    }
    let mut dst_len = dst.len() as libc::c_uint;
    let ret = unsafe {
        BZ2_bzBuffToBuffCompress(
            dst.as_mut_ptr() as *mut libc::c_char,
            &mut dst_len,
            src.as_ptr() as *const libc::c_char,
            src.len() as libc::c_uint,
            level.clamp(1, 9) as libc::c_int,
            0,
            30,
        )
    };
    if ret == 0 {
        Ok(dst_len as usize)
    } else {
        Err(TTZipStatus::ErrCompressionFailed)
    }
}

fn bzip2_decompress(src: &[u8], dst: &mut [u8]) -> Result<usize, TTZipStatus> {
    if src.is_empty() {
        return Ok(0);
    }
    let mut dst_len = dst.len() as libc::c_uint;
    let ret = unsafe {
        BZ2_bzBuffToBuffDecompress(
            dst.as_mut_ptr() as *mut libc::c_char,
            &mut dst_len,
            src.as_ptr() as *const libc::c_char,
            src.len() as libc::c_uint,
            0,
            0,
        )
    };
    if ret == 0 {
        Ok(dst_len as usize)
    } else {
        Err(TTZipStatus::ErrExtractionFailed)
    }
}

/// Codec configuration descriptor.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct MatrixCodecConfig {
    pub algorithm: String,
    pub level: i32,
    pub display_name: String,
}

impl MatrixCodecConfig {
    pub fn new(algorithm: impl Into<String>, level: i32, display_name: impl Into<String>) -> Self {
        Self {
            algorithm: algorithm.into(),
            level,
            display_name: display_name.into(),
        }
    }
}

/// Unified codec driver dispatcher.
pub struct MatrixCodecDriver;

impl MatrixCodecDriver {
    /// Generates all 60 standard benchmark configurations (>= 50 point Matrix Gate).
    pub fn all_matrix_configs() -> Vec<MatrixCodecConfig> {
        let mut configs = Vec::with_capacity(60);

        // 1. Libdeflate: Levels 1..=12 (12 points)
        for lvl in 1..=12 {
            configs.push(MatrixCodecConfig::new("Libdeflate", lvl, format!("Libdeflate L{}", lvl)));
        }

        // 2. Zstd: Levels 1..=22 (22 points)
        for lvl in 1..=22 {
            configs.push(MatrixCodecConfig::new("Zstd", lvl, format!("Zstd L{}", lvl)));
        }

        // 3. LZ4: Acceleration 1 (Fast), 3 (Faster), 9 (UltraFast) (3 points)
        configs.push(MatrixCodecConfig::new("LZ4", 1, "LZ4 Fast 1"));
        configs.push(MatrixCodecConfig::new("LZ4", 3, "LZ4 Fast 3"));
        configs.push(MatrixCodecConfig::new("LZ4", 9, "LZ4 Fast 9"));

        // 4. Apple LZFSE (1 point)
        configs.push(MatrixCodecConfig::new("LZFSE", 1, "Apple LZFSE"));

        // 5. Snappy (1 point)
        configs.push(MatrixCodecConfig::new("Snappy", 1, "Snappy"));

        // 6. Brotli: Quality 0..=11 (12 points)
        for q in 0..=11 {
            configs.push(MatrixCodecConfig::new("Brotli", q, format!("Brotli Q{}", q)));
        }

        // 7. Bzip2: Levels 1..=9 (9 points)
        for lvl in 1..=9 {
            configs.push(MatrixCodecConfig::new("Bzip2", lvl, format!("Bzip2 L{}", lvl)));
        }

        configs
    }

    /// Compresses source slice using the given configuration.
    pub fn compress(cfg: &MatrixCodecConfig, src: &[u8]) -> Result<Vec<u8>, TTZipStatus> {
        match cfg.algorithm.as_str() {
            "Libdeflate" => {
                let bound = deflate_compress_bound(src.len(), cfg.level) + 1024;
                let mut dst = vec![0u8; bound];
                let written = deflate_compress(src, &mut dst, cfg.level)?;
                dst.truncate(written);
                Ok(dst)
            }
            "Zstd" => {
                let bound = zstd_compress_bound(src.len()) + 1024;
                let mut dst = vec![0u8; bound];
                let written = zstd_compress(src, &mut dst, cfg.level)?;
                dst.truncate(written);
                Ok(dst)
            }
            "LZ4" => {
                let bound = lz4_compress_bound(src.len()) + 1024;
                let mut dst = vec![0u8; bound];
                let written = lz4_compress_fast(src, &mut dst, cfg.level)?;
                dst.truncate(written);
                Ok(dst)
            }
            "LZFSE" => {
                let bound = src.len() + 4096;
                let mut dst = vec![0u8; bound];
                let written = lzfse_compress(src, &mut dst)?;
                dst.truncate(written);
                Ok(dst)
            }
            "Snappy" => {
                let bound = snappy_max_compressed_length(src.len()) + 1024;
                let mut dst = vec![0u8; bound];
                let written = snappy_compress(src, &mut dst)?;
                dst.truncate(written);
                Ok(dst)
            }
            "Brotli" => {
                let bound = brotli_compress_bound(src.len()) + 1024;
                let mut dst = vec![0u8; bound];
                let written = brotli_compress(src, &mut dst, cfg.level as u32, 22)?;
                dst.truncate(written);
                Ok(dst)
            }
            "Bzip2" => {
                let bound = src.len() + (src.len() / 100) + 1024;
                let mut dst = vec![0u8; bound];
                let written = bzip2_compress(src, &mut dst, cfg.level)?;
                dst.truncate(written);
                Ok(dst)
            }
            _ => Err(TTZipStatus::ErrInvalidParam),
        }
    }

    /// Decompresses compressed slice using the given configuration.
    pub fn decompress(
        cfg: &MatrixCodecConfig,
        compressed: &[u8],
        orig_len: usize,
    ) -> Result<Vec<u8>, TTZipStatus> {
        let mut dst = vec![0u8; orig_len];
        match cfg.algorithm.as_str() {
            "Libdeflate" => {
                let written = deflate_decompress(compressed, &mut dst)?;
                if written != orig_len {
                    return Err(TTZipStatus::ErrExtractionFailed);
                }
                Ok(dst)
            }
            "Zstd" => {
                let written = zstd_decompress(compressed, &mut dst)?;
                if written != orig_len {
                    return Err(TTZipStatus::ErrExtractionFailed);
                }
                Ok(dst)
            }
            "LZ4" => {
                let written = lz4_decompress(compressed, &mut dst)?;
                if written != orig_len {
                    return Err(TTZipStatus::ErrExtractionFailed);
                }
                Ok(dst)
            }
            "LZFSE" => {
                let written = lzfse_decompress(compressed, &mut dst)?;
                if written != orig_len {
                    return Err(TTZipStatus::ErrExtractionFailed);
                }
                Ok(dst)
            }
            "Snappy" => {
                let written = snappy_decompress(compressed, &mut dst)?;
                if written != orig_len {
                    return Err(TTZipStatus::ErrExtractionFailed);
                }
                Ok(dst)
            }
            "Brotli" => {
                let written = brotli_decompress(compressed, &mut dst)?;
                if written != orig_len {
                    return Err(TTZipStatus::ErrExtractionFailed);
                }
                Ok(dst)
            }
            "Bzip2" => {
                let written = bzip2_decompress(compressed, &mut dst)?;
                if written != orig_len {
                    return Err(TTZipStatus::ErrExtractionFailed);
                }
                Ok(dst)
            }
            _ => Err(TTZipStatus::ErrInvalidParam),
        }
    }
}
