// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_lzma2_branchless_rc.h
 * @brief High-speed branchless LZMA2 range coder decoding primitives.
 */

#ifndef TTZIP_LZMA2_BRANCHLESS_RC_H
#define TTZIP_LZMA2_BRANCHLESS_RC_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    uint32_t range;
    uint32_t code;
    const uint8_t* in_ptr;
    const uint8_t* in_limit;
    uint32_t corrupt;
} ttzip_lzma_rc_state_t;

void ttzip_lzma_rc_init(ttzip_lzma_rc_state_t* rc, const uint8_t* in_buf, size_t in_size);

static inline uint32_t ttzip_lzma_rc_decode_bit_branchless(ttzip_lzma_rc_state_t* rc, uint16_t* prob) {
    uint32_t r = rc->range;
    uint32_t c = rc->code;
    uint32_t p = *prob;
    uint32_t bound = (r >> 11) * p;

    uint32_t is_bit_1 = (c >= bound);

    *prob = (uint16_t)(p + (is_bit_1 ? -(int32_t)(p >> 5) : (int32_t)((2048 - p) >> 5)));
    c -= is_bit_1 ? bound : 0;
    r = is_bit_1 ? (r - bound) : bound;

    if (r < 0x01000000) {
        r <<= 8;
        if (rc->in_ptr < rc->in_limit) {
            c = (c << 8) | (*rc->in_ptr++);
        } else {
            rc->corrupt = 1;
        }
    }

    rc->range = r;
    rc->code = c;
    return is_bit_1;
}

uint32_t ttzip_lzma_rc_decode_direct_bits(ttzip_lzma_rc_state_t* rc, unsigned num_bits);

#ifdef __cplusplus
}
#endif

#endif // TTZIP_LZMA2_BRANCHLESS_RC_H
