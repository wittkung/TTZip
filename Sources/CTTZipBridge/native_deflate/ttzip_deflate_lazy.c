// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_deflate_lazy.c
 * @brief Tier 3 Fast-Lazy & Tier 4 Deep-Lazy 2-Step Match Finding Engine.
 * @details Implements 3-byte + 4-byte 2-way fast lazy evaluation (Tier 3)
 *          and 4-way unrolled hash-chained deep lazy evaluation with 2-step lookahead (Tier 4).
 */

#include "ttzip_deflate_engine.h"
#include <string.h>
#include <stdio.h>


#if defined(__arm64__) || defined(__aarch64__)
#include <arm_neon.h>

static inline uint32_t ttzip_lazy_match_len_arm64(const uint8_t *s1, const uint8_t *s2, uint32_t max_len) {
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

static inline void ttzip_matchfinder_init_neon(int16_t *data, size_t num_entries) {
    int16x8_t *p = (int16x8_t *)data;
    int16x8_t v = vdupq_n_s16(-32768);
    size_t count = num_entries / 32;
    do {
        p[0] = v;
        p[1] = v;
        p[2] = v;
        p[3] = v;
        p += 4;
    } while (--count);
}

static inline void ttzip_matchfinder_rebase_neon(int16_t *data, size_t num_entries) {
    int16x8_t *p = (int16x8_t *)data;
    int16x8_t v = vdupq_n_s16((int16_t)-32768);
    size_t count = num_entries / 32;
    do {
        p[0] = vqaddq_s16(p[0], v);
        p[1] = vqaddq_s16(p[1], v);
        p[2] = vqaddq_s16(p[2], v);
        p[3] = vqaddq_s16(p[3], v);
        p += 4;
    } while (--count);
}
#else
static inline uint32_t ttzip_lazy_match_len_arm64(const uint8_t *s1, const uint8_t *s2, uint32_t max_len) {
    uint32_t len = 0;
    while (len < max_len && s1[len] == s2[len]) len++;
    return len;
}

static inline void ttzip_matchfinder_init_neon(int16_t *data, size_t num_entries) {
    for (size_t i = 0; i < num_entries; i++) data[i] = -32768;
}

static inline void ttzip_matchfinder_rebase_neon(int16_t *data, size_t num_entries) {
    for (size_t i = 0; i < num_entries; i++) {
        data[i] = (int16_t)(0x8000 | (data[i] & ~(data[i] >> 15)));
    }
}
#endif



/* ============================================================================
 * 1. Tier 3 & 4: Fast-Lazy 4-Way Compact Bucket Table (HT-4, 64 KB L1 Cache Fit)
 * ============================================================================ */

/* 13-bit hash over 32-bit sequence (8192 4-way buckets = 64 KB) */
static inline uint32_t ttzip_hash4_bucket(uint32_t seq) {
    return (seq * 0x1E35A7BDU) >> (32 - 13);
}

size_t ttzip_deflate_fast_lazy_find_matches(
    ttzip_deflate_fast_lazy_mf_t *mf,
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
    ttzip_matchfinder_init_neon((int16_t *)mf->hash_tab, 32768);

    size_t num_tokens = 0;
    const uint8_t *in_next = in;
    const uint8_t *in_end  = in + in_size;
    const uint8_t *in_cur_base = in;

    /* Max candidate probes per bucket: 2 probes for L3, 4 probes for L4/L5 */
    uint32_t max_probes = (max_chain_depth <= 1) ? 1 : ((max_chain_depth <= 2) ? 2 : 4);

    /* Warm up history */
    if (history && history_size > 0 && history + history_size == in) {
        size_t h_len = history_size > 32768 ? 32768 : history_size;
        const uint8_t *h_start = in - h_len;
        in_cur_base = in - h_len;
        for (const uint8_t *p = h_start; p + 4 <= in; p++) {
            uint32_t s;
            memcpy(&s, p, 4);
            uint32_t h = ttzip_hash4_bucket(s);
            uint16_t pos = (uint16_t)((uintptr_t)(p - in_cur_base) & 0xFFFF);
            mf->hash_tab[h][3] = mf->hash_tab[h][2];
            mf->hash_tab[h][2] = mf->hash_tab[h][1];
            mf->hash_tab[h][1] = mf->hash_tab[h][0];
            mf->hash_tab[h][0] = pos;
        }
    }

    struct {
        uint32_t length;
        uint32_t offset;
    } cur_match = {0, 0};

    while (in_next + 4 <= in_end && num_tokens < max_tokens - 2) {
        /* Early Lazy Short-Circuit if match is sufficiently long (>= 16 bytes) */
        if (cur_match.length >= 16) {
            tokens_out[num_tokens].length = (uint16_t)cur_match.length;
            tokens_out[num_tokens].offset = (uint16_t)cur_match.offset;
            num_tokens++;

            uint8_t len_slot = s_length_slot[cur_match.length];
            freqs_out->litlen[257 + len_slot]++;
            uint8_t off_slot = s_offset_slot[cur_match.offset];
            freqs_out->offset[off_slot]++;

            uint32_t match_len = cur_match.length;
            in_next += (match_len - 1);
            cur_match.length = 0;
            cur_match.offset = 0;
            continue;
        }

        uint32_t cur_pos = (uint32_t)(in_next - in_cur_base);
        while (cur_pos >= 32768) {
            ttzip_matchfinder_rebase_neon((int16_t *)mf->hash_tab, 32768);
            in_cur_base += 32768;
            cur_pos -= 32768;
        }

        int16_t cutoff = (int16_t)(cur_pos - 32768);

        uint32_t seq;
        memcpy(&seq, in_next, 4);
        uint32_t h = ttzip_hash4_bucket(seq);

        uint64_t old_entries;
        memcpy(&old_entries, &mf->hash_tab[h][0], sizeof(uint64_t));
        uint64_t new_entries = (old_entries << 16) | (uint16_t)cur_pos;
        memcpy(&mf->hash_tab[h][0], &new_entries, sizeof(uint64_t));

        uint16_t cand_pos[4];
        cand_pos[0] = (uint16_t)old_entries;
        cand_pos[1] = (uint16_t)(old_entries >> 16);
        cand_pos[2] = (uint16_t)(old_entries >> 32);
        cand_pos[3] = (uint16_t)(old_entries >> 48);


        uint32_t max_len = (uint32_t)(in_end - in_next);
        if (max_len > TTZIP_DEFLATE_MAX_MATCH_LEN) max_len = TTZIP_DEFLATE_MAX_MATCH_LEN;

        uint32_t new_len = 0;
        uint32_t new_offset = 0;

        for (uint32_t p = 0; p < max_probes; p++) {
            int16_t cpos = (int16_t)cand_pos[p];
            if (cpos <= cutoff) break;

            uint32_t dist = (uint32_t)(uint16_t)(cur_pos - (uint16_t)cpos);
            if (dist == 0 || dist > 32768) continue;
            const uint8_t *cand_ptr = in_next - dist;
            const uint8_t *min_valid_ptr = history ? (history_size > 32768 ? history + history_size - 32768 : history) : in;
            if (cand_ptr < min_valid_ptr) continue;

            /* Prefix + Tail Dual-Word Filter (3 CPU cycles) */
            if (new_len >= 4 && in_next + new_len <= in_end) {
                uint32_t tail_cand, tail_target;
                memcpy(&tail_cand, cand_ptr + new_len - 3, 4);
                memcpy(&tail_target, in_next + new_len - 3, 4);
                if (tail_cand != tail_target) continue;
            }

            uint32_t mseq;
            memcpy(&mseq, cand_ptr, 4);
            if (mseq == seq) {
                uint32_t ml = ttzip_lazy_match_len_arm64(in_next, cand_ptr, max_len);
                if (ml > new_len) {
                    new_len = ml;
                    new_offset = dist;
                    if (ml >= nice_match_len || ml >= 16) break;
                }
            }
        }



        /* 1-Step Lazy Evaluation */
        if (cur_match.length >= 3) {
            bool take_next = (new_len > cur_match.length);
            if (new_len == cur_match.length && new_offset < (cur_match.offset >> 2)) {
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

                uint32_t match_len = cur_match.length;
                if (match_len <= 8) {
                    for (uint32_t k = 1; k < match_len - 1; k++) {
                        in_next++;
                        if (in_next + 4 <= in_end) {
                            uint32_t s;
                            memcpy(&s, in_next, 4);
                            uint32_t _h = ttzip_hash4_bucket(s);
                            uint16_t _pos = (uint16_t)((uintptr_t)(in_next - in_cur_base) & 0xFFFF);
                            mf->hash_tab[_h][3] = mf->hash_tab[_h][2];
                            mf->hash_tab[_h][2] = mf->hash_tab[_h][1];
                            mf->hash_tab[_h][1] = mf->hash_tab[_h][0];
                            mf->hash_tab[_h][0] = _pos;
                        }
                    }
                } else {
                    in_next += (match_len - 1);
                    if (in_next + 4 <= in_end) {
                        uint32_t s;
                        memcpy(&s, in_next, 4);
                        uint32_t _h = ttzip_hash4_bucket(s);
                        uint16_t _pos = (uint16_t)((uintptr_t)(in_next - in_cur_base) & 0xFFFF);
                        mf->hash_tab[_h][3] = mf->hash_tab[_h][2];
                        mf->hash_tab[_h][2] = mf->hash_tab[_h][1];
                        mf->hash_tab[_h][1] = mf->hash_tab[_h][0];
                        mf->hash_tab[_h][0] = _pos;
                    }
                }
                cur_match.length = 0;

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
        in_next += (cur_match.length - 1);
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

/* ============================================================================
 * 2. Tier 5 ~ 9: Deep-Lazy 2-Step Lookahead Match Finder (256 KB Chained Table)
 * ============================================================================ */

static inline uint32_t ttzip_lz_hash(uint32_t seq, unsigned num_bits) {
    return (uint32_t)(seq * 0x1E35A7BDU) >> (32 - num_bits);
}

#if defined(__arm64__) || defined(__aarch64__)
static inline void ttzip_hc_matchfinder_init(ttzip_deflate_deep_lazy_mf_t *mf) {
    int16x8_t *p3 = (int16x8_t *)mf->hash3_tab;
    int16x8_t *p4 = (int16x8_t *)mf->hash4_tab;
    int16x8_t *pn = (int16x8_t *)mf->next_tab;
    int16x8_t v = vdupq_n_s16(-32768);

    for (size_t i = 0; i < 32768 / 32; i++) {
        p3[0] = v; p3[1] = v; p3[2] = v; p3[3] = v; p3 += 4;
        pn[0] = v; pn[1] = v; pn[2] = v; pn[3] = v; pn += 4;
    }
    for (size_t i = 0; i < 65536 / 32; i++) {
        p4[0] = v; p4[1] = v; p4[2] = v; p4[3] = v; p4 += 4;
    }
}

static inline void ttzip_hc_matchfinder_slide_window(ttzip_deflate_deep_lazy_mf_t *mf) {
    int16x8_t *p3 = (int16x8_t *)mf->hash3_tab;
    int16x8_t *p4 = (int16x8_t *)mf->hash4_tab;
    int16x8_t *pn = (int16x8_t *)mf->next_tab;
    int16x8_t v = vdupq_n_s16((int16_t)-32768);

    for (size_t i = 0; i < 32768 / 32; i++) {
        p3[0] = vqaddq_s16(p3[0], v); p3[1] = vqaddq_s16(p3[1], v);
        p3[2] = vqaddq_s16(p3[2], v); p3[3] = vqaddq_s16(p3[3], v);
        p3 += 4;
        pn[0] = vqaddq_s16(pn[0], v); pn[1] = vqaddq_s16(pn[1], v);
        pn[2] = vqaddq_s16(pn[2], v); pn[3] = vqaddq_s16(pn[3], v);
        pn += 4;
    }
    for (size_t i = 0; i < 65536 / 32; i++) {
        p4[0] = vqaddq_s16(p4[0], v); p4[1] = vqaddq_s16(p4[1], v);
        p4[2] = vqaddq_s16(p4[2], v); p4[3] = vqaddq_s16(p4[3], v);
        p4 += 4;
    }
}
#else
static inline void ttzip_hc_matchfinder_init(ttzip_deflate_deep_lazy_mf_t *mf) {
    for (size_t i = 0; i < 32768; i++) mf->hash3_tab[i] = -32768;
    for (size_t i = 0; i < 65536; i++) mf->hash4_tab[i] = -32768;
    for (size_t i = 0; i < 32768; i++) mf->next_tab[i] = -32768;
}

static inline void ttzip_hc_matchfinder_slide_window(ttzip_deflate_deep_lazy_mf_t *mf) {
    for (size_t i = 0; i < 32768; i++) {
        mf->hash3_tab[i] = (int16_t)(0x8000 | (mf->hash3_tab[i] & ~(mf->hash3_tab[i] >> 15)));
        mf->next_tab[i] = (int16_t)(0x8000 | (mf->next_tab[i] & ~(mf->next_tab[i] >> 15)));
    }
    for (size_t i = 0; i < 65536; i++) {
        mf->hash4_tab[i] = (int16_t)(0x8000 | (mf->hash4_tab[i] & ~(mf->hash4_tab[i] >> 15)));
    }
}
#endif

static inline uint32_t ttzip_hc_longest_match(
    ttzip_deflate_deep_lazy_mf_t *mf,
    const uint8_t **in_cur_base,
    const uint8_t *in_next,
    uint32_t best_len,
    uint32_t max_len,
    uint32_t nice_len,
    uint32_t max_search_depth,
    uint32_t *next_hashes,
    uint32_t *offset_ret
) {
    uint32_t depth_remaining = max_search_depth;
    const uint8_t *best_matchptr = in_next;
    int16_t cur_node3, cur_node4;
    uint32_t hash3, hash4;
    uint32_t next_hashseq;
    uint32_t seq4;
    const uint8_t *matchptr;
    uint32_t len;
    uint32_t cur_pos = (uint32_t)(in_next - *in_cur_base);
    const uint8_t *in_base;
    int16_t cutoff;

    while (cur_pos >= 32768) {
        ttzip_hc_matchfinder_slide_window(mf);
        *in_cur_base += 32768;
        cur_pos -= 32768;
    }



    in_base = *in_cur_base;
    cutoff = (int16_t)(cur_pos - 32768);

    if (max_len < 5) goto out;

    hash3 = next_hashes[0];
    hash4 = next_hashes[1];

    cur_node3 = mf->hash3_tab[hash3];
    cur_node4 = mf->hash4_tab[hash4];

    mf->hash3_tab[hash3] = (int16_t)cur_pos;
    mf->hash4_tab[hash4] = (int16_t)cur_pos;
    mf->next_tab[cur_pos & 32767] = cur_node4;

    if (max_len >= 5) {
        memcpy(&next_hashseq, in_next + 1, 4);
        next_hashes[0] = ttzip_lz_hash(next_hashseq & 0xFFFFFFU, 15);
        next_hashes[1] = ttzip_lz_hash(next_hashseq, 16);
#if defined(__arm64__) || defined(__aarch64__)
        __builtin_prefetch(&mf->hash3_tab[next_hashes[0]], 1, 1);
        __builtin_prefetch(&mf->hash4_tab[next_hashes[1]], 1, 1);
#endif
    }

    memcpy(&seq4, in_next, 4);

    if (best_len < 4) {
        if (cur_node3 > cutoff && cur_node3 < (int16_t)cur_pos && best_len < 3) {
            matchptr = &in_base[cur_node3];
            if (matchptr < in_next) {
                uint32_t mseq;
                memcpy(&mseq, matchptr, 4);
                if (((mseq ^ seq4) & 0xFFFFFFU) == 0) {
                    best_len = 3;
                    best_matchptr = matchptr;
                }
            }
        }

        if (cur_node4 <= cutoff || cur_node4 >= (int16_t)cur_pos) goto out;

        for (;;) {
            matchptr = &in_base[cur_node4];
            if (matchptr < in_next) {
                uint32_t mseq;
                memcpy(&mseq, matchptr, 4);
                if (mseq == seq4) break;
            }

            cur_node4 = mf->next_tab[cur_node4 & 32767];
            if (cur_node4 <= cutoff || cur_node4 >= (int16_t)cur_pos || !--depth_remaining) goto out;
        }

        best_matchptr = matchptr;
        best_len = ttzip_lazy_match_len_arm64(in_next, best_matchptr, max_len);
        if (best_len >= nice_len) goto out;
        cur_node4 = mf->next_tab[cur_node4 & 32767];
        if (cur_node4 <= cutoff || cur_node4 >= (int16_t)cur_pos || !--depth_remaining) goto out;
    } else {
        if (cur_node4 <= cutoff || cur_node4 >= (int16_t)cur_pos || best_len >= nice_len) goto out;
    }

    for (;;) {
        matchptr = &in_base[cur_node4];
        int16_t next_node = mf->next_tab[cur_node4 & 32767];
#if defined(__arm64__) || defined(__aarch64__)
        __builtin_prefetch(&in_base[next_node & 32767], 0, 0);
#endif

        if (matchptr < in_next && best_len + 1 <= max_len) {
            uint32_t tail_cand, tail_target;
            memcpy(&tail_cand, matchptr + best_len - 3, 4);
            memcpy(&tail_target, in_next + best_len - 3, 4);
            if (tail_cand == tail_target) {
                uint32_t mseq;
                memcpy(&mseq, matchptr, 4);
                if (mseq == seq4) {
                    len = ttzip_lazy_match_len_arm64(in_next, matchptr, max_len);
                    if (len > best_len) {
                        best_len = len;
                        best_matchptr = matchptr;
                        if (best_len >= nice_len) goto out;
                    }
                }
            }
        }

        cur_node4 = next_node;
        if (cur_node4 <= cutoff || cur_node4 >= (int16_t)cur_pos || !--depth_remaining) goto out;
    }

out:
    if (best_matchptr < in_next && best_len >= 3) {
        uint32_t off = (uint32_t)(in_next - best_matchptr);
        if (off >= 1 && off <= 32768) {
            *offset_ret = off;
            return best_len;
        }
    }
    *offset_ret = 0;
    return 0;
}


static inline void ttzip_hc_skip_bytes(
    ttzip_deflate_deep_lazy_mf_t *mf,
    const uint8_t **in_cur_base,
    const uint8_t *in_next,
    const uint8_t *in_end,
    uint32_t count,
    uint32_t *next_hashes
) {
    if (count + 5 > (uint32_t)(in_end - in_next)) return;

    uint32_t remaining = count;
    uint32_t hash3 = next_hashes[0];
    uint32_t hash4 = next_hashes[1];

    while (remaining > 0) {
        uint32_t cur_pos = (uint32_t)(in_next - *in_cur_base);
        while (cur_pos >= 32768) {
            ttzip_hc_matchfinder_slide_window(mf);
            *in_cur_base += 32768;
            cur_pos -= 32768;
        }

        mf->hash3_tab[hash3] = (int16_t)cur_pos;
        mf->next_tab[cur_pos & 32767] = mf->hash4_tab[hash4];
        mf->hash4_tab[hash4] = (int16_t)cur_pos;

        in_next++;
        remaining--;

        uint32_t next_seq;
        memcpy(&next_seq, in_next, 4);
        hash3 = ttzip_lz_hash(next_seq & 0xFFFFFFU, 15);
        hash4 = ttzip_lz_hash(next_seq, 16);
    }

    next_hashes[0] = hash3;
    next_hashes[1] = hash4;
}


size_t ttzip_deflate_deep_lazy_find_matches(
    ttzip_deflate_deep_lazy_mf_t *mf,
    const uint8_t *in,
    size_t in_size,
    const uint8_t *history,
    size_t history_size,
    uint32_t max_chain_depth,
    uint32_t nice_match_len,
    uint32_t lookahead_steps,
    ttzip_deflate_token_t *tokens_out,
    size_t max_tokens,
    ttzip_symbol_freqs_t *freqs_out
) {
    ttzip_hc_matchfinder_init(mf);
    (void)lookahead_steps;


    size_t num_tokens = 0;
    const uint8_t *in_next = in;
    const uint8_t *in_end  = in + in_size;
    const uint8_t *in_cur_base = in;

    /* Warm up history */
    if (history && history_size > 0 && history + history_size == in) {
        size_t h_len = history_size > 32768 ? 32768 : history_size;
        const uint8_t *h_start = in - h_len;
        in_cur_base = in - h_len;
        for (const uint8_t *p = h_start; p + 4 <= in; p++) {
            uint32_t s;
            memcpy(&s, p, 4);
            uint32_t h3 = ttzip_lz_hash(s & 0xFFFFFFU, 15);
            uint32_t h4 = ttzip_lz_hash(s, 16);
            int16_t pos = (int16_t)(p - in_cur_base);
            mf->hash3_tab[h3] = pos;
            mf->next_tab[pos & 32767] = mf->hash4_tab[h4];
            mf->hash4_tab[h4] = pos;
        }
    }



    if (in_size < 5) {
        while (in_next < in_end && num_tokens < max_tokens) {
            uint8_t lit = *in_next++;
            tokens_out[num_tokens].length = 0;
            tokens_out[num_tokens].offset = lit;
            freqs_out->litlen[lit]++;
            num_tokens++;
        }
        return num_tokens;
    }

    uint32_t next_hashes[2];
    uint32_t initial_seq;
    memcpy(&initial_seq, in_next, 4);
    next_hashes[0] = ttzip_lz_hash(initial_seq & 0xFFFFFFU, 15);
    next_hashes[1] = ttzip_lz_hash(initial_seq, 16);

    while (in_next + 4 <= in_end && num_tokens < max_tokens - 4) {
        uint32_t cur_offset = 0;
        uint32_t max_len = (uint32_t)(in_end - in_next);
        if (max_len > TTZIP_DEFLATE_MAX_MATCH_LEN) max_len = TTZIP_DEFLATE_MAX_MATCH_LEN;

        uint32_t cur_len = ttzip_hc_longest_match(
            mf, &in_cur_base, in_next, 2, max_len, nice_match_len, max_chain_depth, next_hashes, &cur_offset
        );

        if (cur_len < 3 || (cur_len == 3 && cur_offset > 4096)) {
            uint8_t lit = *in_next++;
            tokens_out[num_tokens].length = 0;
            tokens_out[num_tokens].offset = lit;
            freqs_out->litlen[lit]++;
            num_tokens++;
            continue;
        }


        in_next++;

    have_cur_match:
        if (cur_len >= nice_match_len) {
            tokens_out[num_tokens].length = (uint16_t)cur_len;
            tokens_out[num_tokens].offset = (uint16_t)cur_offset;
            num_tokens++;
            uint8_t len_slot = s_length_slot[cur_len];
            freqs_out->litlen[257 + len_slot]++;
            uint8_t off_slot = s_offset_slot[cur_offset];
            freqs_out->offset[off_slot]++;

            ttzip_hc_skip_bytes(mf, &in_cur_base, in_next, in_end, cur_len - 1, next_hashes);
            in_next += cur_len - 1;
            continue;
        }

        if (in_next + 4 <= in_end) {
            uint32_t next_offset = 0;
            uint32_t next_max_len = (uint32_t)(in_end - in_next);
            if (next_max_len > TTZIP_DEFLATE_MAX_MATCH_LEN) next_max_len = TTZIP_DEFLATE_MAX_MATCH_LEN;

            uint32_t next_len = ttzip_hc_longest_match(
                mf, &in_cur_base, in_next, cur_len - 1, next_max_len, nice_match_len, max_chain_depth >> 1, next_hashes, &next_offset
            );

            if (next_len > cur_len || (next_len == cur_len && next_offset < (cur_offset >> 2))) {
                uint8_t lit = *(in_next - 1);
                tokens_out[num_tokens].length = 0;
                tokens_out[num_tokens].offset = lit;
                freqs_out->litlen[lit]++;
                num_tokens++;

                cur_len = next_len;
                cur_offset = next_offset;
                in_next++;
                goto have_cur_match;
            }
        }


        tokens_out[num_tokens].length = (uint16_t)cur_len;
        tokens_out[num_tokens].offset = (uint16_t)cur_offset;
        num_tokens++;
        uint8_t len_slot = s_length_slot[cur_len];
        freqs_out->litlen[257 + len_slot]++;
        uint8_t off_slot = s_offset_slot[cur_offset];
        freqs_out->offset[off_slot]++;

        ttzip_hc_skip_bytes(mf, &in_cur_base, in_next, in_end, cur_len - 1, next_hashes);
        in_next += cur_len - 1;
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

/* Backward compatibility wrapper */
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
    return ttzip_deflate_deep_lazy_find_matches(
        mf, in, in_size, history, history_size, max_chain_depth, nice_match_len, 1, tokens_out, max_tokens, freqs_out
    );
}


