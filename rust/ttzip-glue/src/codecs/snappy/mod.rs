// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Safe Pure-Rust Google Snappy block & streaming framing codecs.

pub mod block;
pub mod frame;
pub mod pipe;

pub use block::*;
pub use frame::*;
pub use pipe::*;

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Cursor;

    #[test]
    fn test_snappy_raw_block_roundtrip() {
        let data = b"Pure Rust Snappy zero-copy block compression in TTZip glue layer 2026.";
        let bound = snappy_compress_bound(data.len());
        let mut comp = vec![0u8; bound];
        let c_len = snappy_compress(data, &mut comp).expect("snappy compress");
        assert!(c_len > 0);

        assert!(snappy_validate(&comp[..c_len]));
        let d_len_expected = snappy_uncompressed_length(&comp[..c_len]).expect("uncompressed len");
        assert_eq!(d_len_expected, data.len());

        let mut decomp = vec![0u8; data.len()];
        let d_len = snappy_decompress(&comp[..c_len], &mut decomp).expect("snappy decompress");
        assert_eq!(d_len, data.len());
        assert_eq!(&decomp[..d_len], data);
    }

    #[test]
    fn test_snappy_framing_roundtrip() {
        let data = b"Framing format test payload with standard Castagnoli CRC32-C checksum validation.";
        let encoded = snappy_frame_encode_to_vec(data).expect("frame encode");
        assert!(is_framed_snappy(&encoded));

        let decoded = snappy_frame_decode_to_vec(&encoded, 1024 * 1024).expect("frame decode");
        assert_eq!(decoded, data);
    }

    #[test]
    fn test_snappy_crc32c_mask_unmask() {
        let original_crc: u32 = 0x12345678;
        let masked = mask_crc32c(original_crc);
        let unmasked = unmask_crc32c(masked);
        assert_eq!(unmasked, original_crc);
    }

    #[test]
    fn test_snappy_pipe_large_payload() {
        let payload = vec![0x3Cu8; 5 * 1024 * 1024]; // 5MB (exceeds 4MB pipe chunk)
        let mut reader = Cursor::new(&payload);
        let mut compressed = Vec::new();

        let (read_bytes, _) = snappy_compress_stream_pipe(&mut reader, &mut compressed, None)
            .expect("compress pipe failed");
        assert_eq!(read_bytes, payload.len() as u64);
        assert!(is_framed_snappy(&compressed));

        let mut comp_reader = Cursor::new(&compressed);
        let mut decompressed = Vec::new();
        let (_, dec_written) = snappy_decompress_stream_pipe(&mut comp_reader, &mut decompressed, None)
            .expect("decompress pipe failed");
        assert_eq!(dec_written, payload.len() as u64);
        assert_eq!(decompressed, payload);
    }
}
