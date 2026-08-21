// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Safe, RAII-governed single-format compression and character encoding codecs.

pub mod brotli;
pub mod chardet;
pub mod deflate;
pub mod fast_blocks;
pub mod lzma2;
pub mod snappy;
pub mod zstd;

pub use brotli::{
    brotli_compress, brotli_compress_bound, brotli_compress_file, brotli_compress_stream_pipe,
    brotli_compress_to_vec, brotli_decompress, brotli_decompress_file,
    brotli_decompress_stream_pipe, brotli_decompress_to_vec, BrotliCompressorWriter, BrotliConfig,
    BrotliDecompressorReader, BROTLI_PIPE_BUFFER_SIZE,
};
pub use chardet::*;
pub use deflate::*;
pub use fast_blocks::*;
pub use lzma2::*;
pub use snappy::{
    is_framed_snappy, mask_crc32c, snappy_compress, snappy_compress_bound, snappy_compress_file,
    snappy_compress_stream_pipe, snappy_compress_to_vec, snappy_decompress, snappy_decompress_file,
    snappy_decompress_stream_pipe, snappy_decompress_to_vec, snappy_frame_decode,
    snappy_frame_decode_to_vec, snappy_frame_encode, snappy_frame_encode_to_vec,
    snappy_frame_max_encoded_length, snappy_uncompressed_length, snappy_validate, unmask_crc32c,
    SNAPPY_MAX_CHUNK_SIZE, SNAPPY_PIPE_BUFFER_SIZE, SNAPPY_STREAM_IDENTIFIER,
};
pub use zstd::*;
