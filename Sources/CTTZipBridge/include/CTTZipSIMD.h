// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file CTTZipSIMD.h
 * @brief SIMD hardware acceleration, varint serialization, and unaligned byte order readers.
 */

#ifndef CTTZIP_SIMD_H
#define CTTZIP_SIMD_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

uint32_t ttzip_simd_crc32(uint32_t crc, const void* buf, size_t len);

size_t ttzip_varint_write_u64(uint8_t* dst, uint64_t value);

static inline uint16_t ttzip_read_u16_le(const uint8_t* p) {
    return (uint16_t)p[0] | ((uint16_t)p[1] << 8);
}

static inline uint32_t ttzip_read_u32_le(const uint8_t* p) {
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

#include <stdbool.h>

#if defined(__ARM_NEON) || defined(__ARM_NEON__) || defined(__aarch64__)
#include <arm_neon.h>

static inline uint64x2_t ttzip_neon_transpose_8x8_2x(
    uint64x2_t v,
    uint64x2_t mask1, // 0x00AA00AA00AA00AAULL
    uint64x2_t mask2, // 0x0000CCCC0000CCCCULL
    uint64x2_t mask3  // 0x00000000F0F0F0F0ULL
) {
    uint64x2_t t1 = vandq_u64(veorq_u64(v, vshrq_n_u64(v, 7)), mask1);
    v = veorq_u64(veorq_u64(v, t1), vshlq_n_u64(t1, 7));

    uint64x2_t t2 = vandq_u64(veorq_u64(v, vshrq_n_u64(v, 14)), mask2);
    v = veorq_u64(veorq_u64(v, t2), vshlq_n_u64(t2, 14));

    uint64x2_t t3 = vandq_u64(veorq_u64(v, vshrq_n_u64(v, 28)), mask3);
    v = veorq_u64(veorq_u64(v, t3), vshlq_n_u64(t3, 28));

    return v;
}
#endif

static inline uint64_t ttzip_scalar_transpose_8x8(uint64_t x) {
    uint64_t t;
    t = (x ^ (x >> 7)) & 0x00AA00AA00AA00AAULL;
    x = x ^ t ^ (t << 7);
    t = (x ^ (x >> 14)) & 0x0000CCCC0000CCCCULL;
    x = x ^ t ^ (t << 14);
    t = (x ^ (x >> 28)) & 0x00000000F0F0F0F0ULL;
    x = x ^ t ^ (t << 28);
    return x;
}

bool ttzip_simd_is_all_zero_64b(const void* buf, size_t len);
bool ttzip_simd_is_uniform_64b(const void* buf, size_t len, uint64_t* out_pattern);
size_t ttzip_cache_get_optimal_block_size(void);

#ifdef __cplusplus
}
#endif

#endif // CTTZIP_SIMD_H
