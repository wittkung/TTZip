// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_deflate_fast.c
 * @brief Tier 1/2 High-Throughput Greedy LZ77 Match Finder.
 * @details Implements 64KB L1-cache resident 2-Way bucket hashing, dual 64-bit SWAR + 128-bit NEON
 *          match length detection, and zero-rebasing direct pointers for >= 2.2 GB/s single-core throughput.
 */

#include "ttzip_deflate_engine.h"
#include <string.h>

#if defined(__arm64__) || defined(__aarch64__)
#include <arm_neon.h>

static inline uint32_t ttzip_fast_match_len_arm64(const uint8_t *s1, const uint8_t *s2, uint32_t max_len) {
    uint32_t len = 0;
    if (max_len >= 8) {
        uint64_t v1, v2;
        memcpy(&v1, s1, 8);
        memcpy(&v2, s2, 8);
        uint64_t diff = v1 ^ v2;
        if (diff != 0) {
            return (uint32_t)__builtin_ctzll(diff) >> 3;
        }
        len = 8;
    }
    if (max_len >= 16) {
        uint64_t v1, v2;
        memcpy(&v1, s1 + 8, 8);
        memcpy(&v2, s2 + 8, 8);
        uint64_t diff = v1 ^ v2;
        if (diff != 0) {
            return 8 + ((uint32_t)__builtin_ctzll(diff) >> 3);
        }
        len = 16;
    }
    
    while (len + 16 <= max_len) {
        uint8x16_t v1 = vld1q_u8(s1 + len);
        uint8x16_t v2 = vld1q_u8(s2 + len);
        uint8x16_t eq = vceqq_u8(v1, v2);
        uint64x2_t eq64 = vreinterpretq_u64_u8(eq);
        uint64_t low = vgetq_lane_u64(eq64, 0);
        uint64_t high = vgetq_lane_u64(eq64, 1);
        if (low != ~0ULL) {
            uint64_t diff = low ^ ~0ULL;
            return len + ((uint32_t)__builtin_ctzll(diff) >> 3);
        }
        if (high != ~0ULL) {
            uint64_t diff = high ^ ~0ULL;
            return len + 8 + ((uint32_t)__builtin_ctzll(diff) >> 3);
        }
        len += 16;
    }
    while (len + 8 <= max_len) {
        uint64_t v1, v2;
        memcpy(&v1, s1 + len, 8);
        memcpy(&v2, s2 + len, 8);
        uint64_t diff = v1 ^ v2;
        if (diff != 0) {
            return len + ((uint32_t)__builtin_ctzll(diff) >> 3);
        }
        len += 8;
    }
    while (len < max_len && s1[len] == s2[len]) {
        len++;
    }
    return len;
}
#else
static inline uint32_t ttzip_fast_match_len_arm64(const uint8_t *s1, const uint8_t *s2, uint32_t max_len) {
    uint32_t len = 0;
    while (len < max_len && s1[len] == s2[len]) len++;
    return len;
}
#endif

/* 4-byte multiplicative hash with 12-bit distribution (4096 2-way buckets = 64 KB L1 Cache Fit) */
static inline uint32_t ttzip_hash4(uint32_t seq) {
    return (seq * 0x1E35A7BDU) >> (32 - TTZIP_DEFLATE_FAST_HASH_BITS);
}

typedef struct {
    const uint8_t *table[TTZIP_DEFLATE_FAST_HASH_SIZE][2];
} ttzip_fast_ptr_table_t;

/* Fast match finder main entry point */
size_t ttzip_deflate_fast_find_matches(
    ttzip_deflate_fast_mf_t *mf,
    const uint8_t *in,
    size_t in_size,
    const uint8_t *history,
    size_t history_size,
    ttzip_deflate_token_t *tokens_out,
    size_t max_tokens,
    ttzip_symbol_freqs_t *freqs_out
) {
    ttzip_fast_ptr_table_t *ptab = (ttzip_fast_ptr_table_t *)mf;
    memset(ptab, 0, sizeof(ttzip_fast_ptr_table_t));

    size_t num_tokens = 0;
    const uint8_t *in_next = in;
    const uint8_t *in_end  = in + in_size;
    size_t unsucc_searches = 0;

    /* 1. Warm up history dictionary if contiguous in virtual memory */
    if (history && history_size > 0 && history + history_size == in) {
        size_t h_len = history_size > 32768 ? 32768 : history_size;
        const uint8_t *h_start = in - h_len;
        for (const uint8_t *p = h_start; p + 4 <= in; p++) {
            uint32_t seq;
            memcpy(&seq, p, 4);
            uint32_t h = ttzip_hash4(seq);
            ptab->table[h][1] = ptab->table[h][0];
            ptab->table[h][0] = p;
        }
    }

    if (in_size < 4) {
        while (in_next < in_end && num_tokens < max_tokens) {
            uint8_t lit = *in_next++;
            tokens_out[num_tokens].length = 0;
            tokens_out[num_tokens].offset = lit;
            freqs_out->litlen[lit]++;
            num_tokens++;
        }
        return num_tokens;
    }

    uint32_t seq;
    memcpy(&seq, in_next, 4);
    uint32_t next_hash = ttzip_hash4(seq);

    while (in_next + 4 <= in_end && num_tokens < max_tokens - 1) {
        uint32_t hash = next_hash;
        memcpy(&seq, in_next, 4);
        if (in_next + 5 <= in_end) {
            uint32_t next_seq;
            memcpy(&next_seq, in_next + 1, 4);
            next_hash = ttzip_hash4(next_seq);
#if defined(__arm64__) || defined(__aarch64__)
            __builtin_prefetch(&ptab->table[next_hash][0], 1, 1);
#endif
        }

        const uint8_t *cand0 = ptab->table[hash][0];
        const uint8_t *cand1 = ptab->table[hash][1];
        ptab->table[hash][1] = cand0;
        ptab->table[hash][0] = in_next;

        uint32_t max_len = (uint32_t)(in_end - in_next);
        if (max_len > TTZIP_DEFLATE_MAX_MATCH_LEN) max_len = TTZIP_DEFLATE_MAX_MATCH_LEN;

        uint32_t best_len = 0;
        uint32_t best_offset = 0;

        /* Probe candidate 0 */
        if (cand0 != NULL && in_next > cand0) {
            size_t dist = (size_t)(in_next - cand0);
            if (dist <= 32768) {
                uint32_t mseq;
                memcpy(&mseq, cand0, 4);
                if (mseq == seq) {
                    best_len = ttzip_fast_match_len_arm64(in_next, cand0, max_len);
                    best_offset = (uint32_t)dist;
                }
            }
        }

        /* Probe candidate 1 */
        if (best_len < 32 && cand1 != NULL && in_next > cand1) {
            size_t dist = (size_t)(in_next - cand1);
            if (dist <= 32768) {
                uint32_t mseq;
                memcpy(&mseq, cand1, 4);
                if (mseq == seq) {
                    uint32_t len1 = ttzip_fast_match_len_arm64(in_next, cand1, max_len);
                    if (len1 > best_len) {
                        best_len = len1;
                        best_offset = (uint32_t)dist;
                    }
                }
            }
        }

        if (best_len >= 3 && best_offset >= 1 && best_offset <= 32768) {
            unsucc_searches = 0;
            tokens_out[num_tokens].length = (uint16_t)best_len;
            tokens_out[num_tokens].offset = (uint16_t)best_offset;
            num_tokens++;

            uint8_t len_slot = s_length_slot[best_len];
            freqs_out->litlen[257 + len_slot]++;
            uint8_t off_slot = s_offset_slot[best_offset];
            freqs_out->offset[off_slot]++;

            /* Advance position */
            in_next += best_len;
            if (in_next + 4 <= in_end) {
                uint32_t s;
                memcpy(&s, in_next, 4);
                next_hash = ttzip_hash4(s);
            }
        } else {
            unsucc_searches++;
            if (__builtin_expect(unsucc_searches >= 256, 0)) {
                /* High-entropy incompressible stream detected: fast-forward remaining bytes directly */
                size_t rem = (size_t)(in_end - in_next);
                if (rem > max_tokens - num_tokens) rem = max_tokens - num_tokens;
                for (size_t i = 0; i < rem; i++) {
                    uint8_t lit = in_next[i];
                    tokens_out[num_tokens + i].length = 0;
                    tokens_out[num_tokens + i].offset = lit;
                    freqs_out->litlen[lit]++;
                }
                num_tokens += rem;
                in_next += rem;
                break;
            }

            uint32_t step = 1 + (uint32_t)(unsucc_searches >> 5);
            if (step > 32) step = 32;
            if (step > (uint32_t)(in_end - in_next - 4)) {
                step = (uint32_t)(in_end - in_next - 4);
                if (step == 0) step = 1;
            }

            for (uint32_t i = 0; i < step && in_next < in_end && num_tokens < max_tokens; i++) {
                uint8_t lit = *in_next++;
                tokens_out[num_tokens].length = 0;
                tokens_out[num_tokens].offset = lit;
                freqs_out->litlen[lit]++;
                num_tokens++;
            }

            if (in_next + 4 <= in_end) {
                uint32_t s;
                memcpy(&s, in_next, 4);
                next_hash = ttzip_hash4(s);
            }
        }
    }

    while (in_next < in_end && num_tokens < max_tokens) {
        uint8_t lit = *in_next++;
        tokens_out[num_tokens].length = 0;
        tokens_out[num_tokens].offset = lit;
        freqs_out->litlen[lit]++;
        num_tokens++;
    }

    return num_tokens;
}
