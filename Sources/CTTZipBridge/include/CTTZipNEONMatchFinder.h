// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file CTTZipNEONMatchFinder.h
 * @brief High-speed NEON vector match length finder.
 */

#ifndef CTTZipNEONMatchFinder_h
#define CTTZipNEONMatchFinder_h

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <string.h>

#if defined(__ARM_NEON) || defined(__ARM_NEON__)
#include <arm_neon.h>

static inline size_t ttzip_neon_match_len(const uint8_t* p1, const uint8_t* p2, size_t limit) {
    size_t len = 0;
    // Tier 0: Fast 64-bit GPR check for initial 8-byte prefix
    if (len + 8 <= limit) {
        uint64_t v1, v2;
        memcpy(&v1, p1 + len, 8);
        memcpy(&v2, p2 + len, 8);
        uint64_t diff = v1 ^ v2;
        if (diff != 0) {
#if defined(WORDS_BIGENDIAN)
            return ((size_t)__builtin_clzll(diff) >> 3);
#else
            return ((size_t)__builtin_ctzll(diff) >> 3);
#endif
        }
        len += 8;
    }
    // Tier 1: 128-bit NEON vector unrolling for 16-byte chunks
    while (len + 16 <= limit) {
        uint8x16_t q1 = vld1q_u8(p1 + len);
        uint8x16_t q2 = vld1q_u8(p2 + len);
        uint8x16_t qdiff = veorq_u8(q1, q2);
        uint64_t d0 = vgetq_lane_u64(vreinterpretq_u64_u8(qdiff), 0);
        uint64_t d1 = vgetq_lane_u64(vreinterpretq_u64_u8(qdiff), 1);
        if (d0 != 0) {
#if defined(WORDS_BIGENDIAN)
            return len + ((size_t)__builtin_clzll(d0) >> 3);
#else
            return len + ((size_t)__builtin_ctzll(d0) >> 3);
#endif
        }
        if (d1 != 0) {
#if defined(WORDS_BIGENDIAN)
            return len + 8 + ((size_t)__builtin_clzll(d1) >> 3);
#else
            return len + 8 + ((size_t)__builtin_ctzll(d1) >> 3);
#endif
        }
        len += 16;
    }
    // Check remaining 8-byte chunk
    if (len + 8 <= limit) {
        uint64_t v1, v2;
        memcpy(&v1, p1 + len, 8);
        memcpy(&v2, p2 + len, 8);
        uint64_t diff = v1 ^ v2;
        if (diff != 0) {
#if defined(WORDS_BIGENDIAN)
            return len + ((size_t)__builtin_clzll(diff) >> 3);
#else
            return len + ((size_t)__builtin_ctzll(diff) >> 3);
#endif
        }
        len += 8;
    }
    while (len < limit && p1[len] == p2[len]) {
        len++;
    }
    return len;
}

static inline size_t ttzip_neon_match_len_prefetch(const uint8_t* p1, const uint8_t* p2, size_t limit) {
    __builtin_prefetch(p1 + 64, 0, 1);
    __builtin_prefetch(p2 + 64, 0, 1);
    return ttzip_neon_match_len(p1, p2, limit);
}

#else

static inline size_t ttzip_neon_match_len(const uint8_t* p1, const uint8_t* p2, size_t limit) {
    size_t len = 0;
    while (len < limit && p1[len] == p2[len]) {
        len++;
    }
    return len;
}

static inline size_t ttzip_neon_match_len_prefetch(const uint8_t* p1, const uint8_t* p2, size_t limit) {
    return ttzip_neon_match_len(p1, p2, limit);
}

#endif

#endif // CTTZipNEONMatchFinder_h
