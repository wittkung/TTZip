// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Safe RAII wrapper and streaming context for Facebook `Zstandard` (zstd).
//!
//! Supports multi-threaded parallel compression (`nb_workers`), Long Distance Matching (LDM),
//! custom window/overlap logs, zero-copy in-memory buffer operations, and 4MB In / 4MB Out bounded pipes.

pub mod cctx;
pub mod dctx;
pub mod pipe;
pub mod types;

pub use cctx::{
    with_thread_local_zstd_cctx, zstd_compress, zstd_compress_advanced, zstd_compress_bound,
    ZstdCCtx,
};
pub use dctx::{
    with_thread_local_zstd_dctx, zstd_decompress, zstd_get_decompressed_size, ZstdDCtx,
};
pub use pipe::{zstd_compress_stream_pipe, zstd_decompress_stream_pipe, ZSTD_PIPE_BUFFER_SIZE};
pub use types::{ZstdCParameter, ZstdConfig, ZstdEndDirective, ZstdInBuffer, ZstdOutBuffer};

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Cursor;

    #[test]
    fn test_zstd_basic_roundtrip() {
        let input = b"TTZip High-performance ZSTD compression engine test string in Safe Rust.";
        let mut compressed = vec![0u8; zstd_compress_bound(input.len())];
        let comp_len = zstd_compress(input, &mut compressed, 3).expect("zstd compression failed");
        assert!(comp_len > 0);

        let detected_size = zstd_get_decompressed_size(&compressed[..comp_len]);
        assert_eq!(detected_size, Some(input.len() as u64));

        let mut decompressed = vec![0u8; input.len()];
        let decomp_len = zstd_decompress(&compressed[..comp_len], &mut decompressed)
            .expect("zstd decompression failed");
        assert_eq!(decomp_len, input.len());
        assert_eq!(&decompressed[..decomp_len], input);
    }

    #[test]
    fn test_zstd_advanced_multithread_ldm() {
        let pattern = b"Long repetitive block data designed for Zstandard Long Distance Matching (LDM) verification. ";
        let mut input = Vec::new();
        for _ in 0..1000 {
            input.extend_from_slice(pattern);
        }

        let config = ZstdConfig {
            level: 6,
            nb_workers: 2,
            job_size_mb: 1,
            overlap_log: 2,
            window_log: 20,
            enable_ldm: true,
            enable_checksum: true,
        };

        let mut compressed = vec![0u8; zstd_compress_bound(input.len())];
        let comp_len = zstd_compress_advanced(&input, &mut compressed, &config)
            .expect("zstd advanced compression failed");
        assert!(comp_len > 0);
        assert!(comp_len < input.len() / 5);

        let mut decompressed = vec![0u8; input.len()];
        let decomp_len = zstd_decompress(&compressed[..comp_len], &mut decompressed)
            .expect("zstd decompression failed");
        assert_eq!(decomp_len, input.len());
        assert_eq!(&decompressed, &input);
    }

    #[test]
    fn test_zstd_corrupt_data() {
        let corrupt = [0x28, 0xb5, 0x2f, 0xfd, 0x00, 0x00, 0xff, 0xff];
        let mut out = [0u8; 128];
        let res = zstd_decompress(&corrupt, &mut out);
        assert!(res.is_err());
    }

    #[test]
    fn test_zstd_stream_pipe_roundtrip() {
        let payload = vec![0xABu8; 1024 * 1024 * 5]; // 5MB payload (spans across 4MB pipe boundary)
        let mut reader = Cursor::new(&payload);
        let mut compressed_out = Vec::new();

        let config = ZstdConfig {
            level: 3,
            ..Default::default()
        };

        let (read_bytes, written_bytes) = zstd_compress_stream_pipe(&mut reader, &mut compressed_out, &config, None)
            .expect("compress pipe failed");
        assert_eq!(read_bytes, payload.len() as u64);
        assert!(written_bytes > 0);
        assert_eq!(written_bytes, compressed_out.len() as u64);

        let mut comp_reader = Cursor::new(&compressed_out);
        let mut decompressed_out = Vec::new();

        let (comp_read, decomp_written) = zstd_decompress_stream_pipe(&mut comp_reader, &mut decompressed_out, None)
            .expect("decompress pipe failed");
        assert_eq!(comp_read, compressed_out.len() as u64);
        assert_eq!(decomp_written, payload.len() as u64);
        assert_eq!(decompressed_out, payload);
    }
}
