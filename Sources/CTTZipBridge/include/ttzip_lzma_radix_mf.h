// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_lzma_radix_mf.h
 * @brief Radix-based fast match finder for LZMA/LZMA2 Level 1 compression.
 */

#ifndef TTZIP_LZMA_RADIX_MF_H
#define TTZIP_LZMA_RADIX_MF_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    uint32_t len;
    uint32_t dist;
} ttzip_match_pair_t;

typedef struct {
    uint32_t* head;         // Radix 16-bit prefix table (65536 entries)
    uint32_t* prev;         // Circular offset chain
    uint32_t dict_size;
    uint32_t mask;
    const uint8_t* buffer;
    size_t buf_size;
} ttzip_radix_mf_t;

int ttzip_radix_mf_init(ttzip_radix_mf_t* mf, uint32_t dict_size);

void ttzip_radix_mf_free(ttzip_radix_mf_t* mf);

ttzip_match_pair_t ttzip_radix_mf_find_fast(
    ttzip_radix_mf_t* mf,
    const uint8_t* src,
    size_t cur_pos,
    size_t max_len
);

#ifdef __cplusplus
}
#endif

#endif // TTZIP_LZMA_RADIX_MF_H
