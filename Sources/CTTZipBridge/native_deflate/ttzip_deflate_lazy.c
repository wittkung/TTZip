// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_deflate_lazy.c
 * @brief Tier 3/4 Lazy Evaluation LZ77 Match Finder.
 * @details Combines a 3-byte direct hash table for short runs with a 4-byte chained hash
 *          table for deep match detection, incorporating 1-step lookahead lazy evaluation.
 */

#include "ttzip_deflate_engine.h"
#include <string.h>

#if defined(__arm64__) || defined(__aarch64__)
#include <arm_neon.h>

static inline uint32_t ttzip_lazy_match_len_arm64(const uint8_t *s1, const uint8_t *s2, uint32_t max_len) {
    uint32_t len = 0;
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
static inline uint32_t ttzip_lazy_match_len_arm64(const uint8_t *s1, const uint8_t *s2, uint32_t max_len) {
    uint32_t len = 0;
    while (len < max_len && s1[len] == s2[len]) len++;
    return len;
}
#endif

static inline uint32_t ttzip_hash3(uint32_t seq) {
    return ((seq & 0xFFFFFFU) * 0x1E35A7BDU) >> (32 - 15);
}

static inline uint32_t ttzip_hash4_lazy(uint32_t seq) {
    return (seq * 0x1E35A7BDU) >> (32 - 15);
}

typedef struct {
    const uint8_t *hash3_tab[32768];
    const uint8_t *hash4_tab[32768];
    const uint8_t *next_tab[32768];
} ttzip_lazy_ptr_table_t;

/* Lazy match finder main entry point */
size_t ttzip_deflate_lazy_find_matches(
    ttzip_deflate_lazy_mf_t *mf,
    const uint8_t *in,
    size_t in_size,
    const uint8_t *history,
    size_t history_size,
    uint32_t max_chain_depth,
    uint32_t nice_match_len,
    ttzip_deflate_token_t *tokens_out,
    size_t max_tokens,
    ttzip_symbol_freqs_t *freqs_out
) {
    ttzip_lazy_ptr_table_t *ptab = (ttzip_lazy_ptr_table_t *)mf;
    memset(ptab, 0, sizeof(ttzip_lazy_ptr_table_t));

    size_t num_tokens = 0;
    const uint8_t *in_next = in;
    const uint8_t *in_end  = in + in_size;

    /* 1. Warm up history dictionary if contiguous in memory */
    if (history && history_size > 0 && history + history_size == in) {
        size_t h_len = history_size > 32768 ? 32768 : history_size;
        const uint8_t *h_start = in - h_len;
        for (const uint8_t *p = h_start; p + 4 <= in; p++) {
            uint32_t s;
            memcpy(&s, p, 4);
            uint32_t h3 = ttzip_hash3(s);
            uint32_t h4 = ttzip_hash4_lazy(s);
            ptab->hash3_tab[h3] = p;
            ptab->next_tab[((uintptr_t)p) & 32767] = ptab->hash4_tab[h4];
            ptab->hash4_tab[h4] = p;
        }
    }

    struct {
        uint32_t length;
        uint32_t offset;
    } cur_match = {0, 0};

    while (in_next + 4 <= in_end && num_tokens < max_tokens - 2) {
        uint32_t seq;
        memcpy(&seq, in_next, 4);
        uint32_t h3 = ttzip_hash3(seq);
        uint32_t h4 = ttzip_hash4_lazy(seq);

        const uint8_t *cand3 = ptab->hash3_tab[h3];
        const uint8_t *cand4 = ptab->hash4_tab[h4];

        ptab->hash3_tab[h3] = in_next;
        ptab->hash4_tab[h4] = in_next;
        ptab->next_tab[((uintptr_t)in_next) & 32767] = cand4;

        uint32_t max_len = (uint32_t)(in_end - in_next);
        if (max_len > TTZIP_DEFLATE_MAX_MATCH_LEN) max_len = TTZIP_DEFLATE_MAX_MATCH_LEN;

        uint32_t new_len = 0;
        uint32_t new_offset = 0;

        /* 1. Probe 3-byte direct hash table */
        if (cur_match.length < 3 && cand3 != NULL && in_next > cand3) {
            size_t dist = (size_t)(in_next - cand3);
            if (dist <= 32768) {
                uint32_t mseq;
                memcpy(&mseq, cand3, 4);
                if ((mseq & 0xFFFFFF) == (seq & 0xFFFFFF)) {
                    new_len = 3;
                    new_offset = (uint32_t)dist;
                }
            }
        }

        /* 2. Traverse 4-byte hash chain */
        const uint8_t *node = cand4;
        uint32_t depth = max_chain_depth;

        while (node != NULL && in_next > node && depth-- > 0) {
            size_t dist = (size_t)(in_next - node);
            if (dist > 32768) break;

            uint32_t mseq;
            memcpy(&mseq, node, 4);
            if (mseq == seq) {
                uint32_t ml = ttzip_lazy_match_len_arm64(in_next, node, max_len);
                if (ml > new_len) {
                    new_len = ml;
                    new_offset = (uint32_t)dist;
                    if (ml >= nice_match_len) break;
                }
            }
            node = ptab->next_tab[((uintptr_t)node) & 32767];
        }

        /* 3. 1-Step Lookahead Lazy Evaluation Decision */
        if (cur_match.length >= 3) {
            bool take_next = false;
            if (new_len > cur_match.length) {
                take_next = true;
            } else if (new_len == cur_match.length && new_offset < (cur_match.offset >> 2)) {
                take_next = true;
            }

            if (take_next) {
                uint8_t lit = *(in_next - 1);
                tokens_out[num_tokens].length = 0;
                tokens_out[num_tokens].offset = lit;
                freqs_out->litlen[lit]++;
                num_tokens++;

                cur_match.length = new_len;
                cur_match.offset = new_offset;
                in_next++;
            } else {
                tokens_out[num_tokens].length = (uint16_t)cur_match.length;
                tokens_out[num_tokens].offset = (uint16_t)cur_match.offset;
                num_tokens++;

                uint8_t len_slot = s_length_slot[cur_match.length];
                freqs_out->litlen[257 + len_slot]++;
                uint8_t off_slot = s_offset_slot[cur_match.offset];
                freqs_out->offset[off_slot]++;

                uint32_t skip = cur_match.length - 1;
                while (--skip > 0) {
                    in_next++;
                    if (in_next + 4 <= in_end) {
                        uint32_t s;
                        memcpy(&s, in_next, 4);
                        uint32_t _h3 = ttzip_hash3(s);
                        uint32_t _h4 = ttzip_hash4_lazy(s);
                        ptab->hash3_tab[_h3] = in_next;
                        ptab->next_tab[((uintptr_t)in_next) & 32767] = ptab->hash4_tab[_h4];
                        ptab->hash4_tab[_h4] = in_next;
                    }
                }
                cur_match.length = 0;
                in_next++;
            }
        } else {
            if (new_len >= 3) {
                cur_match.length = new_len;
                cur_match.offset = new_offset;
                in_next++;
            } else {
                uint8_t lit = *in_next++;
                tokens_out[num_tokens].length = 0;
                tokens_out[num_tokens].offset = lit;
                freqs_out->litlen[lit]++;
                num_tokens++;
            }
        }
    }

    if (cur_match.length >= 3 && num_tokens < max_tokens) {
        tokens_out[num_tokens].length = (uint16_t)cur_match.length;
        tokens_out[num_tokens].offset = (uint16_t)cur_match.offset;
        num_tokens++;

        uint8_t len_slot = s_length_slot[cur_match.length];
        freqs_out->litlen[257 + len_slot]++;
        uint8_t off_slot = s_offset_slot[cur_match.offset];
        freqs_out->offset[off_slot]++;
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
