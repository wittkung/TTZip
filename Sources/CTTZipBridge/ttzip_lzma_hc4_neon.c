#include "include/ttzip_lzma_hc4_neon.h"
#include <stdlib.h>
#include <string.h>
#include <arm_neon.h>

#if defined(__ARM_FEATURE_CRC32)
#include <arm_acle.h>
#define TTZIP_HAS_ARM_CRC32 1
#endif

// Hybrid SWAR (Tier 0: 64-bit GPR) + NEON (Tier 1: 128-bit vector) match length computation
// Tier 0: 64-bit GPR check eliminates vector-to-GPR cross-domain latency (10-12 cycles on Apple Silicon)
// Tier 1: 128-bit NEON unrolling provides high throughput for extended matches (up to max_len, e.g. 258 or 273)
uint32_t ttzip_hybrid_match_len_neon(const uint8_t* p1, const uint8_t* p2, uint32_t max_len) {
    if (!p1 || !p2 || max_len == 0) {
        return 0;
    }
    
    // Tier 0: For short limits (< 8 bytes), use scalar loop to avoid reading past valid bounds
    if (max_len < 8) {
        uint32_t len = 0;
        while (len < max_len && p1[len] == p2[len]) {
            len++;
        }
        return len;
    }
    
    // Tier 0 Fast-Check: Compare first 8 bytes via 64-bit SWAR GPR
    uint64_t v1, v2;
    memcpy(&v1, p1, 8);
    memcpy(&v2, p2, 8);
    uint64_t diff = v1 ^ v2;
    if (diff != 0) {
#if defined(WORDS_BIGENDIAN)
        uint32_t match = (uint32_t)__builtin_clzll(diff) >> 3;
#else
        uint32_t match = (uint32_t)__builtin_ctzll(diff) >> 3;
#endif
        return match < max_len ? match : max_len;
    }
    
    // First 8 bytes matched completely
    uint32_t len = 8;
    
#if defined(__ARM_NEON) || defined(__ARM_NEON__)
    // Tier 1: 128-bit NEON vector unrolling (16 bytes per iteration)
    while (len + 16 <= max_len) {
        uint8x16_t q1 = vld1q_u8(p1 + len);
        uint8x16_t q2 = vld1q_u8(p2 + len);
        uint8x16_t qdiff = veorq_u8(q1, q2);
        
        uint64_t d0 = vgetq_lane_u64(vreinterpretq_u64_u8(qdiff), 0);
        if (d0 != 0) {
#if defined(WORDS_BIGENDIAN)
            uint32_t sub_len = (uint32_t)__builtin_clzll(d0) >> 3;
#else
            uint32_t sub_len = (uint32_t)__builtin_ctzll(d0) >> 3;
#endif
            return len + sub_len;
        }
        
        uint64_t d1 = vgetq_lane_u64(vreinterpretq_u64_u8(qdiff), 1);
        if (d1 != 0) {
#if defined(WORDS_BIGENDIAN)
            uint32_t sub_len = (uint32_t)__builtin_clzll(d1) >> 3;
#else
            uint32_t sub_len = (uint32_t)__builtin_ctzll(d1) >> 3;
#endif
            return len + 8 + sub_len;
        }
        
        len += 16;
    }
#else
    // Fallback 16-byte unrolling using 64-bit SWAR
    while (len + 16 <= max_len) {
        uint64_t v1_a, v2_a;
        memcpy(&v1_a, p1 + len, 8);
        memcpy(&v2_a, p2 + len, 8);
        uint64_t diff_a = v1_a ^ v2_a;
        if (diff_a != 0) {
#if defined(WORDS_BIGENDIAN)
            return len + ((uint32_t)__builtin_clzll(diff_a) >> 3);
#else
            return len + ((uint32_t)__builtin_ctzll(diff_a) >> 3);
#endif
        }
        
        uint64_t v1_b, v2_b;
        memcpy(&v1_b, p1 + len + 8, 8);
        memcpy(&v2_b, p2 + len + 8, 8);
        uint64_t diff_b = v1_b ^ v2_b;
        if (diff_b != 0) {
#if defined(WORDS_BIGENDIAN)
            return len + 8 + ((uint32_t)__builtin_clzll(diff_b) >> 3);
#else
            return len + 8 + ((uint32_t)__builtin_ctzll(diff_b) >> 3);
#endif
        }
        
        len += 16;
    }
#endif

    // Check remaining 8-byte block if available
    if (len + 8 <= max_len) {
        uint64_t v1_tail, v2_tail;
        memcpy(&v1_tail, p1 + len, 8);
        memcpy(&v2_tail, p2 + len, 8);
        uint64_t diff_tail = v1_tail ^ v2_tail;
        if (diff_tail != 0) {
#if defined(WORDS_BIGENDIAN)
            return len + ((uint32_t)__builtin_clzll(diff_tail) >> 3);
#else
            return len + ((uint32_t)__builtin_ctzll(diff_tail) >> 3);
#endif
        }
        len += 8;
    }

    // Scalar convergence for remaining < 8 bytes
    while (len < max_len && p1[len] == p2[len]) {
        len++;
    }
    
    return len;
}

// Fast 64-bit SWAR & NEON match length computation (delegates to ttzip_hybrid_match_len_neon)
uint32_t ttzip_match_len_neon(const uint8_t* p1, const uint8_t* p2, uint32_t max_len) {
    return ttzip_hybrid_match_len_neon(p1, p2, max_len);
}

// 4-byte hash calculation using ARM CRC32 hardware instruction or fallback
static inline uint32_t ttzip_hc4_hash_calc(const uint8_t* p, uint32_t mask) {
    uint32_t v;
    memcpy(&v, p, 4);
#if TTZIP_HAS_ARM_CRC32
    return __crc32w(0, v) & mask;
#else
    // Fallback multiplicative hash
    return ((v * 0x9E3779B9U) >> 12) & mask;
#endif
}

int ttzip_hc4_init(ttzip_hc4_t* mf, const uint8_t* data, uint32_t data_size,
                   uint32_t dict_size, uint32_t nice_len, uint32_t cut_value) {
    if (!mf || !data) return -1;
    
    memset(mf, 0, sizeof(*mf));
    mf->buffer = data;
    mf->buffer_size = data_size;
    mf->dict_size = dict_size > 0 ? dict_size : (256 * 1024);
    mf->nice_len = nice_len > 0 ? nice_len : 32;
    mf->cut_value = cut_value > 0 ? cut_value : 16;
    mf->len_limit = 273;
    mf->pos = 0;
    
    // Scale hash mask for cache locality (64K entries for Level 1 fits 100% in L1/L2 CPU cache)
    if (cut_value <= 4 || data_size <= 1024 * 1024) {
        mf->hash_mask = (1U << 16) - 1; // 64K entries = 256KB
    } else {
        mf->hash_mask = (1U << 18) - 1; // 256K entries = 1MB
    }
    
    mf->hash2 = (uint32_t*)calloc(65536, sizeof(uint32_t));
    mf->hash3 = (uint32_t*)calloc(65536, sizeof(uint32_t));
    mf->hash4 = (uint32_t*)calloc(mf->hash_mask + 1, sizeof(uint32_t));
    mf->chain = (uint32_t*)malloc(mf->dict_size * sizeof(uint32_t));
    
    if (!mf->hash2 || !mf->hash3 || !mf->hash4 || !mf->chain) {
        ttzip_hc4_free(mf);
        return -2;
    }
    
    return 0;
}

void ttzip_hc4_free(ttzip_hc4_t* mf) {
    if (!mf) return;
    if (mf->hash2) free(mf->hash2);
    if (mf->hash3) free(mf->hash3);
    if (mf->hash4) free(mf->hash4);
    if (mf->chain) free(mf->chain);
    memset(mf, 0, sizeof(*mf));
}

uint32_t ttzip_hc4_get_matches(ttzip_hc4_t* mf, ttzip_match_t* matches, uint32_t max_matches) {
    if (!mf || mf->pos + 4 > mf->buffer_size) {
        mf->pos++;
        return 0;
    }
    
    const uint8_t* cur = mf->buffer + mf->pos;
    uint32_t avail = mf->buffer_size - mf->pos;
    uint32_t match_limit = avail < mf->len_limit ? avail : mf->len_limit;
    
    if (match_limit < 4) {
        mf->pos++;
        return 0;
    }
    
    // 1. 2-Byte O(1) Direct Table Check
    uint32_t num_matches = 0;
    uint32_t max_len = 1; // Min match length for LZMA is 2
    
    uint32_t h2_val = cur[0] | ((uint32_t)cur[1] << 8);
    uint32_t match2 = mf->hash2[h2_val];
    mf->hash2[h2_val] = mf->pos + 1; // 1-based pos
    
    if (match2 != 0) {
        uint32_t match_pos2 = match2 - 1;
        uint32_t delta2 = mf->pos - match_pos2;
        if (delta2 <= mf->dict_size) {
            const uint8_t* candidate2 = mf->buffer + match_pos2;
            uint32_t len2 = ttzip_hybrid_match_len_neon(cur, candidate2, match_limit);
            if (len2 >= 2) {
                max_len = len2;
                if (matches && num_matches < max_matches) {
                    matches[num_matches].len = len2;
                    matches[num_matches].dist = delta2 - 1;
                    num_matches++;
                }
            }
        }
    }

    // 2. 3-Byte O(1) Direct Table Check
    uint32_t h3_val = (cur[0] | ((uint32_t)cur[1] << 8) | ((uint32_t)cur[2] << 16)) & 0xFFFF;
    uint32_t match3 = mf->hash3[h3_val];
    mf->hash3[h3_val] = mf->pos + 1;
    
    if (match3 != 0) {
        uint32_t match_pos3 = match3 - 1;
        uint32_t delta3 = mf->pos - match_pos3;
        if (delta3 <= mf->dict_size) {
            const uint8_t* candidate3 = mf->buffer + match_pos3;
            uint32_t len3 = ttzip_hybrid_match_len_neon(cur, candidate3, match_limit);
            if (len3 > max_len && len3 >= 3) {
                max_len = len3;
                if (matches && num_matches < max_matches) {
                    matches[num_matches].len = len3;
                    matches[num_matches].dist = delta3 - 1;
                    num_matches++;
                }
            }
        }
    }

    // 3. 4-Byte Hash Chain Check for longer matches
    uint32_t hash_val = ttzip_hc4_hash_calc(cur, mf->hash_mask);
    uint32_t cur_match = mf->hash4[hash_val];
    
    // Update hash and chain
    mf->hash4[hash_val] = mf->pos + 1; // 1-based index to treat 0 as empty
    uint32_t chain_idx = (mf->pos + 1) & (mf->dict_size - 1);
    mf->chain[chain_idx] = cur_match;
    
    uint32_t depth = mf->cut_value;
    
    while (cur_match != 0 && depth-- > 0) {
        uint32_t match_pos = cur_match - 1;
        uint32_t delta = mf->pos - match_pos;
        if (delta > mf->dict_size || delta == 0) break;
        
        uint32_t next_match = mf->chain[cur_match & (mf->dict_size - 1)];
        if (next_match != 0 && next_match <= mf->buffer_size) {
            __builtin_prefetch(mf->buffer + (next_match - 1), 0, 1);
            __builtin_prefetch(&mf->chain[next_match & (mf->dict_size - 1)], 0, 1);
        }
        
        const uint8_t* candidate = mf->buffer + match_pos;
        
        uint16_t c16, m16;
        memcpy(&c16, cur, 2);
        memcpy(&m16, candidate, 2);
        if (c16 != m16 || candidate[max_len] != cur[max_len]) {
            cur_match = next_match;
            continue;
        }
        
        // Compute match length with Hybrid SWAR/NEON
        uint32_t len = ttzip_hybrid_match_len_neon(cur, candidate, match_limit);
        
        if (len > max_len) {
            max_len = len;
            if (matches && num_matches < max_matches) {
                matches[num_matches].len = len;
                matches[num_matches].dist = delta - 1; // 0-based distance
                num_matches++;
            }
            if (len >= mf->nice_len) break;
        }
        
        cur_match = next_match;
    }
    
    mf->pos++;
    return num_matches;
}

void ttzip_hc4_skip(ttzip_hc4_t* mf, uint32_t count) {
    if (!mf || count == 0) return;
    
    if (mf->cut_value <= 4) {
        mf->pos += count;
        return;
    }
    
    uint32_t updates = count > 16 ? 4 : count;
    while (updates > 0 && mf->pos + 4 <= mf->buffer_size) {
        const uint8_t* cur = mf->buffer + mf->pos;
        if (mf->hash2) {
            uint32_t h2_val = cur[0] | ((uint32_t)cur[1] << 8);
            mf->hash2[h2_val] = mf->pos + 1;
        }
        if (mf->hash3) {
            uint32_t h3_val = (cur[0] | ((uint32_t)cur[1] << 8) | ((uint32_t)cur[2] << 16)) & 0xFFFF;
            mf->hash3[h3_val] = mf->pos + 1;
        }
        uint32_t hash_val = ttzip_hc4_hash_calc(cur, mf->hash_mask);
        uint32_t cur_match = mf->hash4[hash_val];
        
        mf->hash4[hash_val] = mf->pos + 1;
        uint32_t chain_idx = (mf->pos + 1) & (mf->dict_size - 1);
        mf->chain[chain_idx] = cur_match;
        
        mf->pos++;
        updates--;
        count--;
    }
    
    mf->pos += count;
}

// 8-byte hash calculation using ARM CRC32 hardware instruction or 64-bit prime multiplier
static inline uint32_t ttzip_hash8_calc(const uint8_t* p, uint32_t mask) {
    uint64_t v;
    memcpy(&v, p, 8);
#if TTZIP_HAS_ARM_CRC32
    return __crc32d(0, v) & mask;
#else
    return (uint32_t)(((v * 0xCF1BBCDCB7A56463ULL) >> 32) & mask);
#endif
}

int ttzip_double_fast_init_workspace(ttzip_double_fast_t* df, const uint8_t* data, uint32_t data_size,
                                     uint32_t dict_size, uint32_t nice_len, void* workspace, size_t workspace_size) {
    if (!df || !data) return -1;
    
    memset(df, 0, sizeof(*df));
    df->buffer = data;
    df->buffer_size = data_size;
    df->dict_size = dict_size > 0 ? dict_size : (256 * 1024);
    df->nice_len = nice_len > 0 ? nice_len : 32;
    df->len_limit = 273;
    df->pos = 0;
    df->mask_small = 65535;
    df->mask_long = 65535;
    
    size_t required_bytes = 2 * 65536 * sizeof(uint32_t); // 512KB
    if (workspace && workspace_size >= required_bytes) {
        df->workspace = workspace;
        df->owns_workspace = false;
        memset(workspace, 0, required_bytes);
    } else {
        df->workspace = calloc(2 * 65536, sizeof(uint32_t));
        if (!df->workspace) return -2;
        df->owns_workspace = true;
    }
    
    df->table_small = (uint32_t*)df->workspace;
    df->table_long = df->table_small + 65536;
    return 0;
}

int ttzip_double_fast_init(ttzip_double_fast_t* df, const uint8_t* data, uint32_t data_size,
                           uint32_t dict_size, uint32_t nice_len) {
    return ttzip_double_fast_init_workspace(df, data, data_size, dict_size, nice_len, NULL, 0);
}

void ttzip_double_fast_free(ttzip_double_fast_t* df) {
    if (!df) return;
    if (df->owns_workspace && df->workspace) {
        free(df->workspace);
    }
    memset(df, 0, sizeof(*df));
}

uint32_t ttzip_double_fast_get_matches(ttzip_double_fast_t* df, ttzip_match_t* matches, uint32_t max_matches) {
    if (!df || df->pos + 8 > df->buffer_size) {
        if (df) df->pos++;
        return 0;
    }
    
    const uint8_t* cur = df->buffer + df->pos;
    uint32_t avail = df->buffer_size - df->pos;
    uint32_t match_limit = avail < df->len_limit ? avail : df->len_limit;
    if (match_limit < 4) {
        df->pos++;
        return 0;
    }
    
    uint32_t num_matches = 0;
    uint32_t best_len = 1;
    
    uint32_t h4 = ttzip_hc4_hash_calc(cur, df->mask_small);
    uint32_t h8 = ttzip_hash8_calc(cur, df->mask_long);
    
    uint32_t match_long = df->table_long[h8];
    uint32_t match_small = df->table_small[h4];
    
    df->table_long[h8] = df->pos + 1;
    df->table_small[h4] = df->pos + 1;
    
    // 1. Check long match (8-byte hash)
    if (match_long != 0) {
        uint32_t match_pos_long = match_long - 1;
        uint32_t delta_long = df->pos - match_pos_long;
        if (delta_long <= df->dict_size && delta_long > 0) {
            const uint8_t* candidate_long = df->buffer + match_pos_long;
            uint32_t len_long = ttzip_hybrid_match_len_neon(cur, candidate_long, match_limit);
            if (len_long >= 8) {
                best_len = len_long;
                if (matches && num_matches < max_matches) {
                    matches[num_matches].len = len_long;
                    matches[num_matches].dist = delta_long - 1;
                    num_matches++;
                }
            }
        }
    }
    
    // 2. Check small match (4-byte hash)
    if (match_small != 0) {
        uint32_t match_pos_small = match_small - 1;
        uint32_t delta_small = df->pos - match_pos_small;
        if (delta_small <= df->dict_size && delta_small > 0) {
            const uint8_t* candidate_small = df->buffer + match_pos_small;
            uint32_t len_small = ttzip_hybrid_match_len_neon(cur, candidate_small, match_limit);
            if (len_small > best_len && len_small >= 4) {
                best_len = len_small;
                if (matches && num_matches < max_matches) {
                    matches[num_matches].len = len_small;
                    matches[num_matches].dist = delta_small - 1;
                    num_matches++;
                }
            }
        }
    }
    
    // 3. Double-Fast 1-Step Lookahead (if short match found, check ip + 1 in long table)
    if (best_len >= 4 && best_len < df->nice_len && df->pos + 9 <= df->buffer_size) {
        const uint8_t* next_cur = cur + 1;
        uint32_t h8_next = ttzip_hash8_calc(next_cur, df->mask_long);
        uint32_t match_long_next = df->table_long[h8_next];
        if (match_long_next != 0) {
            uint32_t match_pos_next = match_long_next - 1;
            uint32_t delta_next = (df->pos + 1) - match_pos_next;
            if (delta_next <= df->dict_size && delta_next > 0) {
                const uint8_t* candidate_next = df->buffer + match_pos_next;
                uint32_t avail_next = df->buffer_size - (df->pos + 1);
                uint32_t match_limit_next = avail_next < df->len_limit ? avail_next : df->len_limit;
                uint32_t len_next = ttzip_hybrid_match_len_neon(next_cur, candidate_next, match_limit_next);
                if (len_next > best_len + 1 && len_next >= 8) {
                    df->pos++;
                    df->table_long[h8_next] = df->pos + 1;
                    if (matches && num_matches < max_matches) {
                        matches[num_matches].len = len_next;
                        matches[num_matches].dist = delta_next - 1;
                        num_matches++;
                    }
                    df->pos++;
                    return num_matches;
                }
            }
        }
    }
    
    df->pos++;
    return num_matches;
}

void ttzip_double_fast_skip(ttzip_double_fast_t* df, uint32_t count) {
    if (!df || count == 0) return;
    uint32_t updates = count > 16 ? 4 : count;
    while (updates > 0 && df->pos + 8 <= df->buffer_size) {
        const uint8_t* cur = df->buffer + df->pos;
        uint32_t h4 = ttzip_hc4_hash_calc(cur, df->mask_small);
        uint32_t h8 = ttzip_hash8_calc(cur, df->mask_long);
        df->table_small[h4] = df->pos + 1;
        df->table_long[h8] = df->pos + 1;
        df->pos++;
        updates--;
        count--;
    }
    df->pos += count;
}
