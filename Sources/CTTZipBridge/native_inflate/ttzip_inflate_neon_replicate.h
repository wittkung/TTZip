// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_inflate_neon_replicate.h
 * @brief ARM NEON in-register small-distance (D < 16) match replication engine.
 * @details Completely eliminates Store-to-Load Forwarding (STLF) stalls and scalar byte loops.
 */

#ifndef TTZIP_INFLATE_NEON_REPLICATE_H
#define TTZIP_INFLATE_NEON_REPLICATE_H

#include <stdint.h>
#include <stddef.h>
#include <string.h>

#if defined(__ARM_NEON) || defined(__ARM_NEON__)
#include <arm_neon.h>

/* Pre-computed static permutation indices for D in [3, 15] (aligned to 16 bytes) */
static const uint8_t s_permute_table[13][16] __attribute__((aligned(16))) = {
    /* D = 3 */  {0,1,2,0,1,2,0,1,2,0,1,2,0,1,2,0},
    /* D = 4 */  {0,1,2,3,0,1,2,3,0,1,2,3,0,1,2,3},
    /* D = 5 */  {0,1,2,3,4,0,1,2,3,4,0,1,2,3,4,0},
    /* D = 6 */  {0,1,2,3,4,5,0,1,2,3,4,5,0,1,2,3},
    /* D = 7 */  {0,1,2,3,4,5,6,0,1,2,3,4,5,6,0,1},
    /* D = 8 */  {0,1,2,3,4,5,6,7,0,1,2,3,4,5,6,7},
    /* D = 9 */  {0,1,2,3,4,5,6,7,8,0,1,2,3,4,5,6},
    /* D = 10 */ {0,1,2,3,4,5,6,7,8,9,0,1,2,3,4,5},
    /* D = 11 */ {0,1,2,3,4,5,6,7,8,9,10,0,1,2,3,4},
    /* D = 12 */ {0,1,2,3,4,5,6,7,8,9,10,11,0,1,2,3},
    /* D = 13 */ {0,1,2,3,4,5,6,7,8,9,10,11,12,0,1,2},
    /* D = 14 */ {0,1,2,3,4,5,6,7,8,9,10,11,12,13,0,1},
    /* D = 15 */ {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,0}
};

static inline __attribute__((always_inline)) void ttzip_replicate_small_dist_neon(
    uint8_t *dst,
    const uint8_t *src,
    uint32_t dist,
    uint32_t len
) {
    if (dist == 1) {
        uint8x16_t v = vdupq_n_u8(*src);
        while (len >= 16) {
            vst1q_u8(dst, v);
            dst += 16;
            len -= 16;
        }
        if (len > 0) {
            vst1q_u8(dst, v);
        }
        return;
    }

    if (dist == 2) {
        uint16_t val;
        memcpy(&val, src, 2);
        uint8x16_t v = vreinterpretq_u8_u16(vdupq_n_u16(val));
        while (len >= 16) {
            vst1q_u8(dst, v);
            dst += 16;
            len -= 16;
        }
        if (len > 0) {
            vst1q_u8(dst, v);
        }
        return;
    }

    if (dist == 4) {
        uint32_t val;
        memcpy(&val, src, 4);
        uint8x16_t v = vreinterpretq_u8_u32(vdupq_n_u32(val));
        while (len >= 16) {
            vst1q_u8(dst, v);
            dst += 16;
            len -= 16;
        }
        if (len > 0) {
            vst1q_u8(dst, v);
        }
        return;
    }

    if (dist == 8) {
        uint64_t val;
        memcpy(&val, src, 8);
        uint8x16_t v = vreinterpretq_u8_u64(vdupq_n_u64(val));
        while (len >= 16) {
            vst1q_u8(dst, v);
            dst += 16;
            len -= 16;
        }
        if (len > 0) {
            vst1q_u8(dst, v);
        }
        return;
    }

    if (dist >= 3 && dist <= 15) {
        uint8x16_t raw = vld1q_u8(src);
        uint8x16_t mask = vld1q_u8(s_permute_table[dist - 3]);
        uint8x16_t periodic = vqtbl1q_u8(raw, mask);
        vst1q_u8(dst, periodic);

        if (len <= 16) return;

        /* Advance 16 bytes. All future bytes are now committed in dst memory! */
        const uint8_t *cur_src = dst;
        dst += 16;
        len -= 16;

        /* Unconditional 16-byte non-overlapping vector copy */
        while (len >= 16) {
            vst1q_u8(dst, vld1q_u8(cur_src));
            dst += 16;
            cur_src += 16;
            len -= 16;
        }
        if (len > 0) {
            vst1q_u8(dst, vld1q_u8(cur_src));
        }
        return;
    }

    /* Fallback for D >= 16 */
    while (len >= 16) {
        vst1q_u8(dst, vld1q_u8(src));
        dst += 16;
        src += 16;
        len -= 16;
    }
    if (len > 0) {
        vst1q_u8(dst, vld1q_u8(src));
    }
}

#else

static inline void ttzip_replicate_small_dist_neon(
    uint8_t *dst,
    const uint8_t *src,
    uint32_t dist,
    uint32_t len
) {
    for (uint32_t i = 0; i < len; i++) {
        dst[i] = src[i % dist];
    }
}

#endif /* __ARM_NEON */

#endif /* TTZIP_INFLATE_NEON_REPLICATE_H */
