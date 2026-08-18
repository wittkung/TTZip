// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file CTTZipNEONMatchFinder.h
 * @brief High-speed NEON vector match length finder and 16-bit saturated rebase.
 */

#ifndef CTTZipNEONMatchFinder_h
#define CTTZipNEONMatchFinder_h

#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include "CTTZipPlatformTimer.h"

typedef int16_t ttzip_mf_pos_t;
#define TTZIP_MF_WINDOW_SIZE 32768
#define TTZIP_MF_INITVAL     ((ttzip_mf_pos_t)-TTZIP_MF_WINDOW_SIZE)

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

static inline __attribute__((always_inline)) void ttzip_matchfinder_init_neon(ttzip_mf_pos_t *data, size_t size_bytes) {
    int16x8_t *p = (int16x8_t *)data;
    int16x8_t v = vdupq_n_s16(TTZIP_MF_INITVAL);
    while (size_bytes >= 8 * sizeof(*p)) {
        p[0] = v; p[1] = v; p[2] = v; p[3] = v;
        p[4] = v; p[5] = v; p[6] = v; p[7] = v;
        p += 8;
        size_bytes -= 8 * sizeof(*p);
    }
    while (size_bytes >= sizeof(*p)) {
        *p++ = v;
        size_bytes -= sizeof(*p);
    }
    if (size_bytes > 0) {
        memset(p, 0x80, size_bytes);
    }
}

static inline __attribute__((always_inline)) void ttzip_matchfinder_rebase_neon(ttzip_mf_pos_t *data, size_t size_bytes) {
    int16x8_t *p = (int16x8_t *)data;
    int16x8_t v = vdupq_n_s16(TTZIP_MF_INITVAL);
    while (size_bytes >= 8 * sizeof(*p)) {
        p[0] = vqaddq_s16(p[0], v);
        p[1] = vqaddq_s16(p[1], v);
        p[2] = vqaddq_s16(p[2], v);
        p[3] = vqaddq_s16(p[3], v);
        p[4] = vqaddq_s16(p[4], v);
        p[5] = vqaddq_s16(p[5], v);
        p[6] = vqaddq_s16(p[6], v);
        p[7] = vqaddq_s16(p[7], v);
        p += 8;
        size_bytes -= 8 * sizeof(*p);
    }
    while (size_bytes >= sizeof(*p)) {
        *p = vqaddq_s16(*p, v);
        p++;
        size_bytes -= sizeof(*p);
    }
    if (size_bytes > 0) {
        ttzip_mf_pos_t *tail = (ttzip_mf_pos_t *)p;
        size_t count = size_bytes / sizeof(ttzip_mf_pos_t);
        for (size_t i = 0; i < count; i++) {
            tail[i] = (ttzip_mf_pos_t)(0x8000 | (tail[i] & ~(tail[i] >> 15)));
        }
    }
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

static inline void ttzip_matchfinder_init_neon(ttzip_mf_pos_t *data, size_t size_bytes) {
    size_t count = size_bytes / sizeof(ttzip_mf_pos_t);
    for (size_t i = 0; i < count; i++) {
        data[i] = TTZIP_MF_INITVAL;
    }
}

static inline void ttzip_matchfinder_rebase_neon(ttzip_mf_pos_t *data, size_t size_bytes) {
    size_t count = size_bytes / sizeof(ttzip_mf_pos_t);
    for (size_t i = 0; i < count; i++) {
        data[i] = (ttzip_mf_pos_t)(0x8000 | (data[i] & ~(data[i] >> 15)));
    }
}

#endif // __ARM_NEON

/* ============================================================================
 * Microbenchmark Timing & 24-bit Fast Hashing
 * ============================================================================ */
static inline double ttzip_matchfinder_benchmark_rebase(ttzip_mf_pos_t *data, size_t size_bytes, int passes) {
    if (passes <= 0) return 0.0;
    uint64_t start = ttzip_platform_monotonic_nanos();
    for (int i = 0; i < passes; i++) {
        ttzip_matchfinder_rebase_neon(data, size_bytes);
    }
    uint64_t elapsed = ttzip_platform_monotonic_nanos() - start;
    return (double)elapsed / (double)passes / 1000.0; // returns microseconds
}

static inline uint32_t ttzip_load_u24_unaligned(const uint8_t *p) {
    uint32_t v;
    memcpy(&v, p, sizeof(uint32_t));
#if defined(WORDS_BIGENDIAN)
    return v >> 8;
#else
    return v & 0xFFFFFFU;
#endif
}

static inline uint32_t ttzip_lz_hash24(uint32_t seq24, unsigned num_bits) {
    return (uint32_t)(seq24 * 0x1E35A7BDU) >> (32 - num_bits);
}

#endif // CTTZipNEONMatchFinder_h
