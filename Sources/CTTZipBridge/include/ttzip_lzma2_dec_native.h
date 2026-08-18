// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_lzma2_dec_native.h
 * @brief Native ARM64 vectorized LZMA1 and LZMA2 block decompression engines.
 */

#ifndef TTZIP_LZMA2_DEC_NATIVE_H
#define TTZIP_LZMA2_DEC_NATIVE_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

#define TTZIP_LZMA2_PROBS_COUNT 16384

typedef struct {
    uint16_t probs[TTZIP_LZMA2_PROBS_COUNT];
    uint32_t range;
    uint32_t code;
    uint32_t state;
    uint32_t rep[4];
} ttzip_lzma2_dec_state_t;

int ttzip_lzma2_decode_block_native(
    const uint8_t* src,
    size_t src_len,
    uint8_t* dst,
    size_t dst_capacity,
    size_t* out_decompressed_len
);

int ttzip_lzma1_decode_block_native(
    const uint8_t* src,
    size_t src_len,
    const uint8_t* props,
    size_t props_len,
    uint8_t* dst,
    size_t dst_capacity,
    size_t* out_decompressed_len
);

#ifdef __cplusplus
}
#endif

#endif // TTZIP_LZMA2_DEC_NATIVE_H
