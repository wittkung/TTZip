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

/* ============================================================================
 * 1. Tier 3: Fast-Lazy 3-Byte Direct + 4-Byte 2-Way Match Finder
 * ============================================================================ */

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
    (void)max_chain_depth;
    memset(mf, 0, sizeof(ttzip_deflate_fast_lazy_mf_t));

    size_t num_tokens = 0;
    const uint8_t *in_next = in;
    const uint8_t *in_end  = in + in_size;

    /* Warm up history */
    if (history && history_size > 0 && history + history_size == in) {
        size_t h_len = history_size > 32768 ? 32768 : history_size;
        const uint8_t *h_start = in - h_len;
        for (const uint8_t *p = h_start; p + 4 <= in; p++) {
            uint32_t s;
            memcpy(&s, p, 4);
            uint32_t h3 = ttzip_hash3(s);
            uint32_t h4 = ttzip_hash4_lazy(s);
            mf->hash3_tab[h3] = p;
            mf->hash4_tab[h4][1] = mf->hash4_tab[h4][0];
            mf->hash4_tab[h4][0] = p;
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

        const uint8_t *cand3 = mf->hash3_tab[h3];
        const uint8_t *cand4_0 = mf->hash4_tab[h4][0];
        const uint8_t *cand4_1 = mf->hash4_tab[h4][1];

        mf->hash3_tab[h3] = in_next;
        mf->hash4_tab[h4][1] = cand4_0;
        mf->hash4_tab[h4][0] = in_next;

        uint32_t max_len = (uint32_t)(in_end - in_next);
        if (max_len > TTZIP_DEFLATE_MAX_MATCH_LEN) max_len = TTZIP_DEFLATE_MAX_MATCH_LEN;

        uint32_t new_len = 0;
        uint32_t new_offset = 0;

        /* Probe 3-byte table */
        if (cand3 != NULL && in_next > cand3) {
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

        /* Probe 4-byte candidate 0 */
        if (cand4_0 != NULL && in_next > cand4_0) {
            size_t dist = (size_t)(in_next - cand4_0);
            if (dist <= 32768) {
                uint32_t mseq;
                memcpy(&mseq, cand4_0, 4);
                if (mseq == seq) {
                    uint32_t ml = ttzip_lazy_match_len_arm64(in_next, cand4_0, max_len);
                    if (ml > new_len) {
                        new_len = ml;
                        new_offset = (uint32_t)dist;
                    }
                }
            }
        }

        /* Probe 4-byte candidate 1 */
        if (new_len < nice_match_len && cand4_1 != NULL && in_next > cand4_1) {
            size_t dist = (size_t)(in_next - cand4_1);
            if (dist <= 32768) {
                uint32_t mseq;
                memcpy(&mseq, cand4_1, 4);
                if (mseq == seq) {
                    uint32_t ml = ttzip_lazy_match_len_arm64(in_next, cand4_1, max_len);
                    if (ml > new_len) {
                        new_len = ml;
                        new_offset = (uint32_t)dist;
                    }
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
                            uint32_t _h3 = ttzip_hash3(s);
                            uint32_t _h4 = ttzip_hash4_lazy(s);
                            mf->hash3_tab[_h3] = in_next;
                            mf->hash4_tab[_h4][1] = mf->hash4_tab[_h4][0];
                            mf->hash4_tab[_h4][0] = in_next;
                        }
                    }
                } else {
                    in_next += (match_len - 1);
                    if (in_next + 4 <= in_end) {
                        uint32_t s;
                        memcpy(&s, in_next, 4);
                        uint32_t _h3 = ttzip_hash3(s);
                        uint32_t _h4 = ttzip_hash4_lazy(s);
                        mf->hash3_tab[_h3] = in_next;
                        mf->hash4_tab[_h4][1] = mf->hash4_tab[_h4][0];
                        mf->hash4_tab[_h4][0] = in_next;
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
 * 2. Tier 4: Deep-Lazy 2-Step Lookahead Match Finder (Chained Table)
 * ============================================================================ */

static inline uint32_t ttzip_deep_longest_match(
    ttzip_deflate_deep_lazy_mf_t *mf,
    const uint8_t *in_next,
    const uint8_t *in_end,
    uint32_t min_len,
    uint32_t nice_len,
    uint32_t max_depth,
    uint32_t *offset_out
) {
    uint32_t seq;
    memcpy(&seq, in_next, 4);
    uint32_t h3 = ttzip_hash3(seq);
    uint32_t h4 = ttzip_hash4_lazy(seq);

    const uint8_t *cand3 = mf->hash3_tab[h3];
    const uint8_t *cand4 = mf->hash4_tab[h4];

    mf->hash3_tab[h3] = in_next;
    mf->hash4_tab[h4] = in_next;
    mf->next_tab[((uintptr_t)in_next) & 32767] = cand4;

    uint32_t max_len = (uint32_t)(in_end - in_next);
    if (max_len > TTZIP_DEFLATE_MAX_MATCH_LEN) max_len = TTZIP_DEFLATE_MAX_MATCH_LEN;

    uint32_t best_len = min_len > 0 ? (min_len - 1) : 0;
    uint32_t best_offset = 0;

    /* Probe 3-byte direct hash */
    if (best_len < 3 && cand3 != NULL && in_next > cand3) {
        size_t dist = (size_t)(in_next - cand3);
        if (dist <= 32768) {
            uint32_t mseq;
            memcpy(&mseq, cand3, 4);
            if ((mseq & 0xFFFFFF) == (seq & 0xFFFFFF)) {
                best_len = 3;
                best_offset = (uint32_t)dist;
            }
        }
    }

    /* Traverse 4-byte hash chain */
    const uint8_t *node = cand4;
    uint32_t depth = max_depth;

    while (node != NULL && in_next > node && depth-- > 0) {
        size_t dist = (size_t)(in_next - node);
        if (dist > 32768) break;

        if (best_len >= 4 && in_next + best_len <= in_end) {
            uint32_t tail_cand, tail_target;
            memcpy(&tail_cand, node + best_len - 3, 4);
            memcpy(&tail_target, in_next + best_len - 3, 4);
            if (tail_cand != tail_target) {
                node = mf->next_tab[((uintptr_t)node) & 32767];
                continue;
            }
        }

        uint32_t mseq;
        memcpy(&mseq, node, 4);
        if (mseq == seq) {
            uint32_t ml = ttzip_lazy_match_len_arm64(in_next, node, max_len);
            if (ml > best_len) {
                best_len = ml;
                best_offset = (uint32_t)dist;
                if (ml >= nice_len) break;
            }
        }
        node = mf->next_tab[((uintptr_t)node) & 32767];
    }

    *offset_out = best_offset;
    return best_len >= min_len ? best_len : 0;
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
    memset(mf, 0, sizeof(ttzip_deflate_deep_lazy_mf_t));

    size_t num_tokens = 0;
    const uint8_t *in_next = in;
    const uint8_t *in_end  = in + in_size;

    /* Warm up history */
    if (history && history_size > 0 && history + history_size == in) {
        size_t h_len = history_size > 32768 ? 32768 : history_size;
        const uint8_t *h_start = in - h_len;
        for (const uint8_t *p = h_start; p + 4 <= in; p++) {
            uint32_t s;
            memcpy(&s, p, 4);
            uint32_t h3 = ttzip_hash3(s);
            uint32_t h4 = ttzip_hash4_lazy(s);
            mf->hash3_tab[h3] = p;
            mf->next_tab[((uintptr_t)p) & 32767] = mf->hash4_tab[h4];
            mf->hash4_tab[h4] = p;
        }
    }

    while (in_next + 4 <= in_end && num_tokens < max_tokens - 4) {
        uint32_t cur_offset = 0;
        uint32_t cur_len = ttzip_deep_longest_match(mf, in_next, in_end, 3, nice_match_len, max_chain_depth, &cur_offset);

        if (cur_len < 3 || (cur_len == 3 && cur_offset > 8192)) {
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

            uint32_t skip = cur_len - 1;
            while (--skip > 0) {
                if (in_next + 4 <= in_end) {
                    uint32_t s;
                    memcpy(&s, in_next, 4);
                    uint32_t _h3 = ttzip_hash3(s);
                    uint32_t _h4 = ttzip_hash4_lazy(s);
                    mf->hash3_tab[_h3] = in_next;
                    mf->next_tab[((uintptr_t)in_next) & 32767] = mf->hash4_tab[_h4];
                    mf->hash4_tab[_h4] = in_next;
                }
                in_next++;
            }
            continue;
        }

        if (in_next + 4 <= in_end) {
            uint32_t next_offset = 0;
            uint32_t next_len = ttzip_deep_longest_match(mf, in_next, in_end, cur_len - 1, nice_match_len, max_chain_depth >> 1, &next_offset);

            if (next_len >= cur_len) {
                int cost_delta = 4 * (int)(next_len - cur_len) + ((int)__builtin_clz(cur_offset | 1) - (int)__builtin_clz(next_offset | 1));
                if (cost_delta > 2) {
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

            if (lookahead_steps >= 2 && in_next + 5 <= in_end) {
                uint32_t next2_offset = 0;
                uint32_t next2_len = ttzip_deep_longest_match(mf, in_next + 1, in_end, cur_len - 1, nice_match_len, max_chain_depth >> 2, &next2_offset);
                if (next2_len >= cur_len) {
                    int cost_delta2 = 4 * (int)(next2_len - cur_len) + ((int)__builtin_clz(cur_offset | 1) - (int)__builtin_clz(next2_offset | 1));
                    if (cost_delta2 > 6) {
                        uint8_t lit0 = *(in_next - 1);
                        uint8_t lit1 = *in_next++;
                        tokens_out[num_tokens].length = 0;
                        tokens_out[num_tokens].offset = lit0;
                        freqs_out->litlen[lit0]++;
                        num_tokens++;

                        tokens_out[num_tokens].length = 0;
                        tokens_out[num_tokens].offset = lit1;
                        freqs_out->litlen[lit1]++;
                        num_tokens++;

                        cur_len = next2_len;
                        cur_offset = next2_offset;
                        in_next++;
                        goto have_cur_match;
                    }
                }
            }
        }

        tokens_out[num_tokens].length = (uint16_t)cur_len;
        tokens_out[num_tokens].offset = (uint16_t)cur_offset;
        num_tokens++;
        uint8_t len_slot = s_length_slot[cur_len];
        freqs_out->litlen[257 + len_slot]++;
        uint8_t off_slot = s_offset_slot[cur_offset];
        freqs_out->offset[off_slot]++;

        uint32_t skip = cur_len - 1;
        while (--skip > 0) {
            if (in_next + 4 <= in_end) {
                uint32_t s;
                memcpy(&s, in_next, 4);
                uint32_t _h3 = ttzip_hash3(s);
                uint32_t _h4 = ttzip_hash4_lazy(s);
                mf->hash3_tab[_h3] = in_next;
                mf->next_tab[((uintptr_t)in_next) & 32767] = mf->hash4_tab[_h4];
                mf->hash4_tab[_h4] = in_next;
            }
            in_next++;
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
