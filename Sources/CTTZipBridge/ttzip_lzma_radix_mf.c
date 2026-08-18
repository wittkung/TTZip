// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_lzma_radix_mf.c
 * @brief 7Z Fast LZMA2 Radix match finder and Level 1 fast skip table (ARM64 NEON).
 */

#include "include/ttzip_lzma_radix_mf.h"
#include <stdlib.h>
#include <string.h>

#if defined(__ARM_NEON) || defined(__ARM_NEON__) || defined(__aarch64__)
#include <arm_neon.h>
#endif

int ttzip_radix_mf_init(ttzip_radix_mf_t* mf, uint32_t dict_size) {
    if (!mf) return -1;
    if (dict_size == 0) dict_size = 1 << 20; // Default 1MB
    
    mf->dict_size = dict_size;
    mf->mask = dict_size - 1;
    
    mf->head = (uint32_t*)malloc(65536 * sizeof(uint32_t));
    mf->prev = (uint32_t*)malloc(dict_size * sizeof(uint32_t));
    
    if (!mf->head || !mf->prev) {
        ttzip_radix_mf_free(mf);
        return -2;
    }
    
    memset(mf->head, 0xFF, 65536 * sizeof(uint32_t));
    memset(mf->prev, 0xFF, dict_size * sizeof(uint32_t));
    return 0;
}

void ttzip_radix_mf_free(ttzip_radix_mf_t* mf) {
    if (!mf) return;
    if (mf->head) { free(mf->head); mf->head = NULL; }
    if (mf->prev) { free(mf->prev); mf->prev = NULL; }
}

ttzip_match_pair_t ttzip_radix_mf_find_fast(
    ttzip_radix_mf_t* mf,
    const uint8_t* src,
    size_t cur_pos,
    size_t max_len
) {
    ttzip_match_pair_t best = { .len = 0, .dist = 0 };
    if (!mf || !src || cur_pos + 2 > max_len) return best;
    
    uint16_t prefix = (uint16_t)src[cur_pos] | ((uint16_t)src[cur_pos + 1] << 8);
    uint32_t match_pos = mf->head[prefix];
    
    uint32_t ring_idx = (uint32_t)(cur_pos & mf->mask);
    mf->prev[ring_idx] = match_pos;
    mf->head[prefix] = (uint32_t)cur_pos;
    
    int depth = 0;
    while (match_pos != 0xFFFFFFFF && depth < 2) {
        if (cur_pos <= match_pos) break;
        uint32_t dist = (uint32_t)(cur_pos - match_pos);
        if (dist > mf->dict_size) break;
        
        const uint8_t* p1 = src + cur_pos;
        const uint8_t* p2 = src + match_pos;
        size_t len = 0;
        
        while (len + 16 <= max_len - cur_pos) {
#if defined(__ARM_NEON) || defined(__ARM_NEON__) || defined(__aarch64__)
            uint8x16_t v1 = vld1q_u8(p1 + len);
            uint8x16_t v2 = vld1q_u8(p2 + len);
            uint8x16_t diff = veorq_u8(v1, v2);
            if (vmaxvq_u8(diff) != 0) {
                while (len < max_len - cur_pos && p1[len] == p2[len]) len++;
                break;
            }
            len += 16;
#else
            while (len < max_len - cur_pos && p1[len] == p2[len]) len++;
            break;
#endif
        }
        
        if (len > best.len && len >= 3) {
            best.len = (uint32_t)len;
            best.dist = dist;
            if (len >= 32) break;
        }
        
        uint32_t prev_ring_idx = match_pos & mf->mask;
        match_pos = mf->prev[prev_ring_idx];
        depth++;
    }
    
    return best;
}
