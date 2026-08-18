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
#include <stdio.h>


#if defined(__arm64__) || defined(__aarch64__)
#include <arm_neon.h>
#endif

/* 15-bit direct 3-byte multiplicative hash (32,768 singleton entries = 64 KB) */
static inline uint32_t ttzip_fast_hash3(uint32_t seq) {
    return (uint32_t)(((seq & 0x00FFFFFFU) * 0x1E35A7BDU) >> 17);
}

/* 14-bit multiplicative hash (16,384 2-way buckets = 64 KB) */
static inline uint32_t ttzip_fast_hash(uint32_t seq) {
    return (uint32_t)(seq * 0x1E35A7BDU) >> (32 - 14);
}



#if defined(__arm64__) || defined(__aarch64__)
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
static inline void ttzip_matchfinder_init_neon(int16_t *data, size_t num_entries) {
    for (size_t i = 0; i < num_entries; i++) data[i] = -32768;
}
static inline void ttzip_matchfinder_rebase_neon(int16_t *data, size_t num_entries) {
    for (size_t i = 0; i < num_entries; i++) {
        data[i] = (int16_t)(0x8000 | (data[i] & ~(data[i] >> 15)));
    }
}
#endif

static inline uint32_t ttzip_lz_extend_fast_arm64(const uint8_t *s1, const uint8_t *s2, uint32_t start_len, uint32_t max_len) {
    uint32_t len = start_len;
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
    while (len < max_len && s1[len] == s2[len]) len++;
    return len;
}

/* Tier 1: 64KB Direct 3-Byte Match Finder with 64-Bit SWAR Verification for Structured JSON & High-Speed Streams */
size_t ttzip_deflate_hybrid_fast_find_matches(
    ttzip_deflate_hybrid_fast_mf_t *mf,
    const uint8_t *in,
    size_t in_size,
    const uint8_t *history,
    size_t history_size,
    ttzip_deflate_token_t *tokens_out,
    size_t max_tokens,
    ttzip_symbol_freqs_t *freqs_out
) {
    /* Initialize 64KB direct 3-byte table with -32768 */
    ttzip_matchfinder_init_neon((int16_t *)mf->hash3_tab, 32768);

    size_t num_tokens = 0;
    uint32_t consecutive_no_match = 0;
    const uint8_t *in_next = in;
    const uint8_t *in_end  = in + in_size;
    const uint8_t *in_cur_base = in;

    /* Warm up history dictionary if contiguous */
    if (history && history_size > 0 && history + history_size == in) {
        size_t h_len = history_size > 32768 ? 32768 : history_size;
        const uint8_t *h_start = in - h_len;
        in_cur_base = in - h_len;
        for (const uint8_t *p = h_start; p + 3 <= in; p++) {
            uint32_t s;
            memcpy(&s, p, 4);
            uint32_t h = ttzip_fast_hash3(s);
            mf->hash3_tab[h] = (uint16_t)(int16_t)(p - in_cur_base);
        }
    }

    const uint8_t *in_min_ptr = history ? (history_size > 32768 ? history + history_size - 32768 : history) : in;

    if (in_size < 8) {
        while (in_next < in_end && num_tokens < max_tokens) {
            uint8_t lit = *in_next++;
            tokens_out[num_tokens].length = 0;
            tokens_out[num_tokens].offset = lit;
            freqs_out->litlen[lit]++;
            num_tokens++;
        }
        return num_tokens;
    }

    while (in_next + 8 <= in_end && num_tokens < max_tokens - 8) {
        uint32_t cur_pos = (uint32_t)(in_next - in_cur_base);
        while (cur_pos >= 32768) {
            ttzip_matchfinder_rebase_neon((int16_t *)mf->hash3_tab, 32768);
            in_cur_base += 32768;
            cur_pos -= 32768;
        }

        const uint8_t *in_base = in_cur_base;
        int16_t cutoff = (int16_t)(cur_pos - 32768);

        uint32_t seq;
        memcpy(&seq, in_next, 4);
        uint32_t h = ttzip_fast_hash3(seq);

        int16_t cand_pos = (int16_t)mf->hash3_tab[h];
        mf->hash3_tab[h] = (uint16_t)cur_pos;

#if defined(__arm64__) || defined(__aarch64__)
        if (in_next + 12 <= in_end) {
            uint32_t next_seq;
            memcpy(&next_seq, in_next + 1, 4);
            uint32_t next_h = ttzip_fast_hash3(next_seq);
            __builtin_prefetch(&mf->hash3_tab[next_h], 1, 1);
        }
#endif

        if (cand_pos > cutoff && cand_pos < (int16_t)cur_pos) {
            const uint8_t *matchptr = &in_base[cand_pos];
            if (matchptr >= in_min_ptr && matchptr < in_next) {
                uint32_t best_offset = (uint32_t)(in_next - matchptr);
                if (best_offset >= 1 && best_offset <= 32768) {
                    uint64_t w_cur, w_cand;
                    memcpy(&w_cur, in_next, 8);
                    memcpy(&w_cand, matchptr, 8);
                    uint64_t diff = w_cur ^ w_cand;

                    /* Check for 3-byte prefix match */
                    if ((diff & 0x0000000000FFFFFFULL) == 0) {
                        uint32_t max_len = (uint32_t)(in_end - in_next);
                        if (max_len > TTZIP_DEFLATE_MAX_MATCH_LEN) max_len = TTZIP_DEFLATE_MAX_MATCH_LEN;

                        uint32_t best_len;
                        if (diff == 0) {
                            best_len = ttzip_lz_extend_fast_arm64(in_next, matchptr, 8, max_len);
                        } else {
                            best_len = (uint32_t)__builtin_ctzll(diff) >> 3;
                            if (best_len > max_len) best_len = max_len;
                        }

                        consecutive_no_match = 0;
                        tokens_out[num_tokens].length = (uint16_t)best_len;
                        tokens_out[num_tokens].offset = (uint16_t)best_offset;
                        num_tokens++;

                        uint8_t len_slot = s_length_slot[best_len];
                        freqs_out->litlen[257 + len_slot]++;
                        uint8_t off_slot = s_offset_slot[best_offset];
                        freqs_out->offset[off_slot]++;

                        in_next += best_len;
                        continue;
                    }
                }
            }
        }

        consecutive_no_match++;
        if (consecutive_no_match > 1) {
            uint32_t step = (consecutive_no_match > 16) ? 32 : ((consecutive_no_match > 4) ? 16 : 4);
            if (in_next + step + 8 <= in_end && num_tokens + step <= max_tokens) {
                for (uint32_t k = 0; k < step; k++) {
                    uint8_t lit = in_next[k];
                    tokens_out[num_tokens + k].length = 0;
                    tokens_out[num_tokens + k].offset = lit;
                    freqs_out->litlen[lit]++;
                }
                num_tokens += step;
                in_next += step;
                continue;
            }
        }


        if (in_next + 2 + 8 <= in_end && num_tokens + 2 <= max_tokens) {
            uint8_t lit0 = in_next[0];
            uint8_t lit1 = in_next[1];
            tokens_out[num_tokens].length = 0;
            tokens_out[num_tokens].offset = lit0;
            tokens_out[num_tokens + 1].length = 0;
            tokens_out[num_tokens + 1].offset = lit1;
            freqs_out->litlen[lit0]++;
            freqs_out->litlen[lit1]++;
            num_tokens += 2;
            in_next += 2;
        } else {
            uint8_t lit = *in_next++;
            tokens_out[num_tokens].length = 0;
            tokens_out[num_tokens].offset = lit;
            freqs_out->litlen[lit]++;
            num_tokens++;
        }

    }




    /* Process trailing bytes */
    while (in_next < in_end && num_tokens < max_tokens) {
        uint8_t lit = *in_next++;
        tokens_out[num_tokens].length = 0;
        tokens_out[num_tokens].offset = lit;
        freqs_out->litlen[lit]++;
        num_tokens++;
    }

    return num_tokens;
}

/* Tier 2: Fast 2-Way Greedy Match Finder with Full Chain Updates */

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

    ttzip_matchfinder_init_neon((int16_t *)mf->hash_tab, 32768);

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
            uint32_t h = ttzip_fast_hash(s) & 16383;
            int16_t pos = (int16_t)(p - in_cur_base);
            mf->hash_tab[h][1] = mf->hash_tab[h][0];
            mf->hash_tab[h][0] = pos;
        }
    }

    const uint8_t *in_min_ptr = history ? (history_size > 32768 ? history + history_size - 32768 : history) : in;

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

    uint32_t seq;
    memcpy(&seq, in_next, 4);
    uint32_t next_h = ttzip_fast_hash(seq) & 16383;

    while (in_next + 4 <= in_end && num_tokens < max_tokens - 2) {
        uint32_t cur_pos = (uint32_t)(in_next - in_cur_base);
        while (cur_pos >= 32768) {
            ttzip_matchfinder_rebase_neon((int16_t *)mf->hash_tab, 32768);
            in_cur_base += 32768;
            cur_pos -= 32768;
        }

        const uint8_t *in_base = in_cur_base;
        int16_t cutoff = (int16_t)(cur_pos - 32768);


        uint32_t h = next_h;
        memcpy(&seq, in_next, 4);

        if (in_next + 5 <= in_end) {
            uint32_t next_seq;
            memcpy(&next_seq, in_next + 1, 4);
            next_h = ttzip_fast_hash(next_seq) & 16383;
#if defined(__arm64__) || defined(__aarch64__)
            __builtin_prefetch(&mf->hash_tab[next_h][0], 1, 1);
#endif
        }

        uint32_t bucket = *(uint32_t *)&mf->hash_tab[h][0];
        int16_t cand0_pos = (int16_t)(bucket & 0xFFFF);
        int16_t cand1_pos = (int16_t)(bucket >> 16);
        *(uint32_t *)&mf->hash_tab[h][0] = (uint32_t)(uint16_t)cur_pos | ((uint32_t)(uint16_t)cand0_pos << 16);

        uint32_t max_len = (uint32_t)(in_end - in_next);
        if (max_len > TTZIP_DEFLATE_MAX_MATCH_LEN) max_len = TTZIP_DEFLATE_MAX_MATCH_LEN;

        uint32_t best_len = 0;
        const uint8_t *best_matchptr = in_next;

        if (cand0_pos <= cutoff) {
            goto fast_no_match;
        }

        const uint8_t *matchptr = &in_base[cand0_pos];
        if (matchptr < in_min_ptr) {
            goto fast_no_match;
        }

        uint32_t mseq;
        memcpy(&mseq, matchptr, 4);

        if (mseq == seq) {
            best_len = ttzip_lz_extend_fast_arm64(in_next, matchptr, 4, max_len);
            best_matchptr = matchptr;

            if (cand1_pos > cutoff && best_len < 64) {
                const uint8_t *matchptr1 = &in_base[cand1_pos];
                if (matchptr1 >= in_min_ptr) {
                    uint32_t mseq1;
                    memcpy(&mseq1, matchptr1, 4);
                    if (mseq1 == seq &&
                        in_next + best_len <= in_end &&
                        matchptr1 + best_len <= in_end) {
                        uint32_t tail1, tail_target;
                        memcpy(&tail1, matchptr1 + best_len - 3, 4);
                        memcpy(&tail_target, in_next + best_len - 3, 4);
                        if (tail1 == tail_target) {
                            uint32_t len1 = ttzip_lz_extend_fast_arm64(in_next, matchptr1, 4, max_len);
                            if (len1 > best_len) {
                                best_len = len1;
                                best_matchptr = matchptr1;
                            }
                        }
                    }
                }
            }
        } else if (cand1_pos > cutoff) {
            const uint8_t *matchptr1 = &in_base[cand1_pos];
            if (matchptr1 >= in_min_ptr) {
                uint32_t mseq1;
                memcpy(&mseq1, matchptr1, 4);
                if (mseq1 == seq) {
                    best_len = ttzip_lz_extend_fast_arm64(in_next, matchptr1, 4, max_len);
                    best_matchptr = matchptr1;
                }
            }
        }


        if (best_len >= 4) {
            uint32_t best_offset = (uint32_t)(in_next - best_matchptr);
            tokens_out[num_tokens].length = (uint16_t)best_len;
            tokens_out[num_tokens].offset = (uint16_t)best_offset;
            num_tokens++;

            uint8_t len_slot = s_length_slot[best_len];
            freqs_out->litlen[257 + len_slot]++;
            uint8_t off_slot = s_offset_slot[best_offset];
            freqs_out->offset[off_slot]++;

            /* Sample intermediate pos to maintain dictionary continuity */
            if (in_next + 1 + 4 <= in_end) {
                uint32_t s1;
                memcpy(&s1, in_next + 1, 4);
                uint32_t _h = ttzip_fast_hash(s1) & 16383;
                uint16_t _pos = (uint16_t)((uintptr_t)(in_next + 1 - in_cur_base) & 0xFFFF);
                uint32_t _b = *(uint32_t *)&mf->hash_tab[_h][0];
                *(uint32_t *)&mf->hash_tab[_h][0] = (uint32_t)_pos | ((uint32_t)(uint16_t)(_b & 0xFFFF) << 16);
            }

            in_next += best_len;
            if (in_next + 4 <= in_end) {
                uint32_t s;
                memcpy(&s, in_next, 4);
                next_h = ttzip_fast_hash(s) & 16383;
            }
            continue;
        }

    fast_no_match:
        {
            uint8_t lit = *in_next++;
            tokens_out[num_tokens].length = 0;
            tokens_out[num_tokens].offset = lit;
            freqs_out->litlen[lit]++;
            num_tokens++;

            if (in_next + 4 <= in_end) {
                uint32_t s;
                memcpy(&s, in_next, 4);
                next_h = ttzip_fast_hash(s) & 16383;
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



