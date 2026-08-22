// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Safe Pure-Rust Google Brotli block and streaming compression codecs.

pub mod block;
pub mod pipe;
pub mod stream;

pub use block::*;
pub use pipe::*;
pub use stream::*;

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Cursor;

    #[test]
    fn test_brotli_block_roundtrip() {
        let input = b"Pure Rust Brotli block compression test in TTZip native glue layer 2026.";
        let mut compressed = vec![0u8; brotli_compress_bound(input.len())];
        let comp_len = brotli_compress(input, &mut compressed, 6, 22).expect("brotli compress");
        assert!(comp_len > 0);

        let mut decompressed = vec![0u8; input.len()];
        let decomp_len = brotli_decompress(&compressed[..comp_len], &mut decompressed).expect("brotli decompress");
        assert_eq!(decomp_len, input.len());
        assert_eq!(&decompressed[..decomp_len], input);
    }

    #[test]
    fn test_brotli_to_vec_roundtrip() {
        let input = b"Repetitive string test for Brotli to vector compression: ABCABCABCABCABCABCABCABCABCABCABCABCABCABCABCABCABCABC";
        let comp = brotli_compress_to_vec(input, 9, 22).expect("brotli to vec compress");
        assert!(comp.len() < input.len());

        let decomp = brotli_decompress_to_vec(&comp, 1024 * 1024).expect("brotli to vec decompress");
        assert_eq!(decomp, input);
    }

    #[test]
    fn test_brotli_pipe_large_payload() {
        let payload = vec![0xFEu8; 5 * 1024 * 1024]; // 5MB payload (spans across 4MB pipe boundary)
        let mut reader = Cursor::new(&payload);
        let mut compressed = Vec::new();

        let (read_bytes, _) = brotli_compress_stream_pipe(&mut reader, &mut compressed, 4, 20, None)
            .expect("brotli compress pipe failed");
        assert_eq!(read_bytes, payload.len() as u64);
        assert!(!compressed.is_empty());

        let mut comp_reader = Cursor::new(&compressed);
        let mut decompressed = Vec::new();
        let (_, dec_written) = brotli_decompress_stream_pipe(&mut comp_reader, &mut decompressed, None)
            .expect("brotli decompress pipe failed");
        assert_eq!(dec_written, payload.len() as u64);
        assert_eq!(decompressed, payload);
    }

    #[test]
    fn test_brotli_corrupt_data() {
        let corrupt = [0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x01];
        let mut out = [0u8; 128];
        let res = brotli_decompress(&corrupt, &mut out);
        assert!(res.is_err());
    }
}
