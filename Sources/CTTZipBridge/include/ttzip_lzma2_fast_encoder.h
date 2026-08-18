// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_lzma2_fast_encoder.h
 * @brief Fast NEON-accelerated LZMA2 Level 1 and tuned multi-level block compressor.
 */

#ifndef TTZIP_LZMA2_FAST_ENCODER_H
#define TTZIP_LZMA2_FAST_ENCODER_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

int ttzip_lzma2_fast_encode(
    const uint8_t* src,
    size_t src_len,
    uint8_t* dst,
    size_t dst_capacity,
    size_t* out_compressed_len,
    uint32_t* out_dict_size
);

int ttzip_lzma2_compress_block_tuned(
    const uint8_t* src,
    size_t src_len,
    uint8_t* dst,
    size_t dst_capacity,
    size_t* out_compressed_len,
    int level,
    bool is_zero_block,
    uint32_t* out_dict_size
);

#ifdef __cplusplus
}
#endif

#endif // TTZIP_LZMA2_FAST_ENCODER_H
