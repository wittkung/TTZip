// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_lzma_hc4_neon.h
 * @brief HC4 and Double-Fast match finder with ARM NEON acceleration for LZMA/LZMA2.
 */

#ifndef TTZIP_LZMA_HC4_NEON_H
#define TTZIP_LZMA_HC4_NEON_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    uint32_t len;
    uint32_t dist;
} ttzip_match_t;

typedef struct {
    uint32_t* hash2;
    uint32_t* hash3;
    uint32_t* hash4;
    uint32_t* chain;
    const uint8_t* buffer;
    uint32_t  buffer_size;
    uint32_t  pos;
    uint32_t  dict_size;
    uint32_t  hash_mask;
    uint32_t  cut_value;
    uint32_t  nice_len;
    uint32_t  len_limit;
} ttzip_hc4_t;

int ttzip_hc4_init(ttzip_hc4_t* mf, const uint8_t* data, uint32_t data_size,
                   uint32_t dict_size, uint32_t nice_len, uint32_t cut_value);

void ttzip_hc4_free(ttzip_hc4_t* mf);

uint32_t ttzip_hc4_get_matches(ttzip_hc4_t* mf, ttzip_match_t* matches, uint32_t max_matches);

void ttzip_hc4_skip(ttzip_hc4_t* mf, uint32_t count);

typedef struct {
    uint32_t* table_small;
    uint32_t* table_long;
    const uint8_t* buffer;
    uint32_t buffer_size;
    uint32_t pos;
    uint32_t dict_size;
    uint32_t mask_small;
    uint32_t mask_long;
    uint32_t nice_len;
    uint32_t len_limit;
    void* workspace;
    bool owns_workspace;
} ttzip_double_fast_t;

int ttzip_double_fast_init_workspace(ttzip_double_fast_t* df, const uint8_t* data, uint32_t data_size,
                                     uint32_t dict_size, uint32_t nice_len, void* workspace, size_t workspace_size);

int ttzip_double_fast_init(ttzip_double_fast_t* df, const uint8_t* data, uint32_t data_size,
                           uint32_t dict_size, uint32_t nice_len);

void ttzip_double_fast_free(ttzip_double_fast_t* df);

uint32_t ttzip_double_fast_get_matches(ttzip_double_fast_t* df, ttzip_match_t* matches, uint32_t max_matches);

void ttzip_double_fast_skip(ttzip_double_fast_t* df, uint32_t count);

uint32_t ttzip_hybrid_match_len_neon(const uint8_t* p1, const uint8_t* p2, uint32_t max_len);

uint32_t ttzip_match_len_neon(const uint8_t* p1, const uint8_t* p2, uint32_t max_len);

#if defined(__ARM_NEON) || defined(__ARM_NEON__)
#include <arm_neon.h>
#endif

static inline bool ttzip_is_block_repetitive_neon(const uint8_t* data, size_t size, uint8_t* out_byte) {
    if (!data || size == 0) return false;
    uint8_t first_byte = data[0];
    if (out_byte) *out_byte = first_byte;
    size_t i = 0;
#if defined(__ARM_NEON) || defined(__ARM_NEON__)
    uint8x16_t vtarget = vdupq_n_u8(first_byte);
    while (i + 64 <= size) {
        uint8x16_t v1 = veorq_u8(vld1q_u8(data + i), vtarget);
        uint8x16_t v2 = veorq_u8(vld1q_u8(data + i + 16), vtarget);
        uint8x16_t v3 = veorq_u8(vld1q_u8(data + i + 32), vtarget);
        uint8x16_t v4 = veorq_u8(vld1q_u8(data + i + 48), vtarget);
        uint8x16_t final_or = vorrq_u8(vorrq_u8(v1, v2), vorrq_u8(v3, v4));
        uint64_t low = vgetq_lane_u64(vreinterpretq_u64_u8(final_or), 0);
        uint64_t high = vgetq_lane_u64(vreinterpretq_u64_u8(final_or), 1);
        if (low | high) return false;
        i += 64;
    }
#endif
    while (i < size) {
        if (data[i] != first_byte) return false;
        i++;
    }
    return true;
}

static inline bool ttzip_is_block_all_zero_neon(const uint8_t* data, size_t size) {
    uint8_t b = 0;
    return ttzip_is_block_repetitive_neon(data, size, &b) && b == 0;
}

#ifdef __cplusplus
}
#endif

#endif // TTZIP_LZMA_HC4_NEON_H
