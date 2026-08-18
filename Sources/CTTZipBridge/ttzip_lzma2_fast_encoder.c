// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_lzma2_fast_encoder.c
 * @brief Ultra-fast LZMA2 encoder implementation for Level 1 compression.
 */

#include "include/ttzip_lzma2_fast_encoder.h"
#include "include/ttzip_lzma_hc4_neon.h"
#include "include/ttzip_lzma_range_coder.h"
#include "include/CTTZipSliceProfiler.h"
#include <stdlib.h>
#include <string.h>

#define LZMA_NUM_STATIONARY_STATES 4
#define LZMA_NUM_STATES 12

// Distance slot table
static const uint8_t kDistSlotTable[256] = {
    0, 1, 2, 3, 4, 4, 5, 5, 6, 6, 6, 6, 7, 7, 7, 7,
    8, 8, 8, 8, 8, 8, 8, 8, 9, 9, 9, 9, 9, 9, 9, 9,
    10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10,
    11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11,
    12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12,
    12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12,
    13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13,
    13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13,
    14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14,
    14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14,
    14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14,
    14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14,
    15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15,
    15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15,
    15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15,
    15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15
};

static inline uint32_t get_dist_slot(uint32_t dist) {
    if (dist < 256) return kDistSlotTable[dist];
    if (dist < (1 << 14)) return kDistSlotTable[dist >> 6] + 12;
    return kDistSlotTable[dist >> 14] + 28;
}

typedef struct {
    uint16_t is_match[LZMA_NUM_STATES][16];
    uint16_t is_rep[LZMA_NUM_STATES];
    uint16_t is_rep0[LZMA_NUM_STATES];
    uint16_t is_rep0_long[LZMA_NUM_STATES][16];
    uint16_t is_rep1[LZMA_NUM_STATES];
    uint16_t is_rep2[LZMA_NUM_STATES];
    
    uint16_t match_len_choice[2];
    uint16_t match_len_low[16][8];
    uint16_t match_len_mid[16][8];
    uint16_t match_len_high[256];
    
    uint16_t rep_len_choice[2];
    uint16_t rep_len_low[16][8];
    uint16_t rep_len_mid[16][8];
    uint16_t rep_len_high[256];
    
    uint16_t dist_slot[4][64];
    uint16_t dist_special[128 - 4];
    uint16_t dist_align[16];
    
    uint16_t literal[1 << (3 + 0 + 8)]; // lc=3, lp=0 -> 1<<11 = 2048 probs
} ttzip_lzma_probs_t;

static void init_probs(ttzip_lzma_probs_t* p) {
    uint16_t* ptr = (uint16_t*)p;
    size_t num = sizeof(ttzip_lzma_probs_t) / sizeof(uint16_t);
    for (size_t i = 0; i < num; i++) {
        ptr[i] = TTZIP_RC_PROB_INIT;
    }
}

static inline void encode_len(ttzip_range_enc_t* rc, uint32_t len,
                              uint16_t* choice, uint16_t low[16][8], uint16_t mid[16][8], uint16_t high[256],
                              uint32_t pos_state) {
    len -= 2; // LZMA min match len is 2
    if (len < 8) {
        ttzip_rc_encode_bit(rc, &choice[0], 0);
        ttzip_rc_encode_bit_tree(rc, low[pos_state], 3, len);
    } else {
        ttzip_rc_encode_bit(rc, &choice[0], 1);
        if (len < 16) {
            ttzip_rc_encode_bit(rc, &choice[1], 0);
            ttzip_rc_encode_bit_tree(rc, mid[pos_state], 3, len - 8);
        } else {
            ttzip_rc_encode_bit(rc, &choice[1], 1);
            ttzip_rc_encode_bit_tree(rc, high, 8, len - 16);
        }
    }
}

// Ultra-fast 2MB Zero Chunk LZMA2 Encoder (Spec-compliant 2MB max chunk size)
static size_t encode_zero_chunk_2mb(
    uint8_t* dst,
    size_t chunk_len,
    bool is_first_chunk,
    ttzip_lzma_probs_t* probs
) {
    uint8_t rc_tmp[1024];
    ttzip_range_enc_t rc;
    ttzip_rc_init(&rc, rc_tmp, sizeof(rc_tmp));
    
    init_probs(probs);
    
    uint32_t state = 0;
    uint32_t cur_pos = 0;
    
    while (cur_pos < chunk_len) {
        uint32_t pos_state = cur_pos & 3;
        uint32_t best_len = 0;
        
        if (cur_pos == 0) {
            best_len = 0; // Literal byte 0x00 for pos 0 of chunk
        } else {
            uint32_t rem = (uint32_t)(chunk_len - cur_pos);
            best_len = rem < 273 ? rem : 273;
            if (best_len < 2) best_len = 0;
        }
        cur_pos++;
        
        if (best_len < 2) {
            ttzip_rc_encode_bit(&rc, &probs->is_match[state][pos_state], 0);
            uint16_t* lit_probs = probs->literal;
            ttzip_rc_encode_bit_tree(&rc, lit_probs, 8, 0);
            state = state < 4 ? 0 : (state < 10 ? state - 3 : state - 6);
        } else {
            // LZMA REP0 match (repeat distance 1 offset for zero RLE)
            ttzip_rc_encode_bit(&rc, &probs->is_match[state][pos_state], 1);
            ttzip_rc_encode_bit(&rc, &probs->is_rep[state], 1);
            ttzip_rc_encode_bit(&rc, &probs->is_rep0[state], 0);
            state = state < 7 ? 8 : 11;
            
            encode_len(&rc, best_len, probs->rep_len_choice, probs->rep_len_low,
                       probs->rep_len_mid, probs->rep_len_high, pos_state);
            cur_pos += (best_len - 1);
        }
    }
    
    ttzip_rc_flush(&rc);
    size_t packed_size = ttzip_rc_get_processed_size(&rc);
    
    uint8_t control = is_first_chunk ? (0xE0 | (uint8_t)((chunk_len - 1) >> 16))
                                     : (0x80 | (uint8_t)((chunk_len - 1) >> 16));
    uint16_t unp_low = (uint16_t)((chunk_len - 1) & 0xFFFF);
    uint16_t pack_low = (uint16_t)((packed_size - 1) & 0xFFFF);
    uint8_t pack_hi = (uint8_t)((packed_size - 1) >> 16);
    
    size_t out = 0;
    dst[out++] = control;
    dst[out++] = (uint8_t)(unp_low >> 8);
    dst[out++] = (uint8_t)(unp_low & 0xFF);
    dst[out++] = pack_hi;
    dst[out++] = (uint8_t)(pack_low >> 8);
    dst[out++] = (uint8_t)(pack_low & 0xFF);
    if (is_first_chunk) dst[out++] = 0x5D; // props
    
    memcpy(dst + out, rc_tmp, packed_size);
    out += packed_size;
    
    return out;
}

int ttzip_lzma2_fast_encode(
    const uint8_t* src,
    size_t src_len,
    uint8_t* dst,
    size_t dst_capacity,
    size_t* out_compressed_len,
    uint32_t* out_dict_size
) {
    if (!src || !dst || !out_compressed_len) return -1;
    if (src_len == 0) {
        *out_compressed_len = 0;
        if (out_dict_size) *out_dict_size = 4096;
        return 0;
    }

    uint32_t dict_size = 64 * 1024; // 64KB dict for Level 1 (matching 7-Zip L1)
    if (out_dict_size) *out_dict_size = dict_size;
    
    bool is_zero = ttzip_is_block_all_zero_neon(src, src_len);
    
    ttzip_lzma_probs_t* probs = (ttzip_lzma_probs_t*)malloc(sizeof(ttzip_lzma_probs_t));
    if (!probs) return -3;
    
    if (is_zero) {
        // Fast path for zero blocks: Encode in spec-compliant 2MB LZMA2 chunks
        const size_t kChunkSize = 2 * 1024 * 1024; // 2MB
        size_t unp_rem = src_len;
        size_t out_idx = 0;
        bool first_chunk = true;
        
        while (unp_rem > 0) {
            size_t chunk_len = unp_rem < kChunkSize ? unp_rem : kChunkSize;
            out_idx += encode_zero_chunk_2mb(dst + out_idx, chunk_len, first_chunk, probs);
            first_chunk = false;
            unp_rem -= chunk_len;
        }
        
        dst[out_idx++] = 0x00; // LZMA2 End Marker
        *out_compressed_len = out_idx;
        free(probs);
        return 0;
    }
    
    // Normal non-zero fast path (nice_len=8, cut_value=1 for 7zz L1 equivalence)
    ttzip_hc4_t mf;
    if (ttzip_hc4_init(&mf, src, (uint32_t)src_len, dict_size, 8, 1) != 0) {
        free(probs);
        return -2;
    }
    init_probs(probs);
    
    size_t rc_buf_capacity = dst_capacity > (src_len + 1024) ? dst_capacity : (src_len + 1024);
    uint8_t* rc_buf = (uint8_t*)malloc(rc_buf_capacity);
    if (!rc_buf) {
        free(probs);
        ttzip_hc4_free(&mf);
        return -4;
    }
    
    ttzip_range_enc_t rc;
    ttzip_rc_init(&rc, rc_buf, rc_buf_capacity);
    
    uint32_t state = 0;
    uint32_t rep[4] = {0, 0, 0, 0};
    ttzip_match_t matches[16];
    uint32_t cur_pos = 0;
    
    while (cur_pos < src_len) {
        uint32_t pos_state = cur_pos & 3;
        uint32_t best_len = 0;
        uint32_t best_dist = 0;
        
        uint32_t num_matches = ttzip_hc4_get_matches(&mf, matches, 16);
        if (num_matches > 0) {
            best_len = matches[num_matches - 1].len;
            best_dist = matches[num_matches - 1].dist;
        }
        cur_pos = mf.pos;
        
        if (best_len < 2) {
            ttzip_rc_encode_bit(&rc, &probs->is_match[state][pos_state], 0);
            uint8_t cur_byte = src[cur_pos - 1];
            uint32_t lit_state = 0;
            if (cur_pos > 1) {
                lit_state = (src[cur_pos - 2] >> 5);
            }
            uint16_t* lit_probs = probs->literal + (lit_state * 256);
            
            if (state < 7) {
                ttzip_rc_encode_bit_tree_8(&rc, lit_probs, cur_byte);
            } else {
                uint8_t match_byte = (cur_pos > rep[0] + 1) ? src[cur_pos - 1 - rep[0] - 1] : 0;
                uint32_t m = 1;
                for (int i = 7; i >= 0; i--) {
                    uint32_t match_bit = (match_byte >> i) & 1;
                    uint32_t bit = (cur_byte >> i) & 1;
                    uint32_t prob_idx = ((1 + match_bit) << 8) + m;
                    ttzip_rc_encode_bit(&rc, &lit_probs[prob_idx], (int)bit);
                    m = (m << 1) | bit;
                    if (match_bit != bit) {
                        for (i--; i >= 0; i--) {
                            bit = (cur_byte >> i) & 1;
                            ttzip_rc_encode_bit(&rc, &lit_probs[m], (int)bit);
                            m = (m << 1) | bit;
                        }
                        break;
                    }
                }
            }
            state = state < 4 ? 0 : (state < 10 ? state - 3 : state - 6);
        } else {
            ttzip_rc_encode_bit(&rc, &probs->is_match[state][pos_state], 1);
            ttzip_rc_encode_bit(&rc, &probs->is_rep[state], 0);
            state = state < 7 ? 7 : 10;
            
            encode_len(&rc, best_len, probs->match_len_choice, probs->match_len_low,
                       probs->match_len_mid, probs->match_len_high, pos_state);
            
            uint32_t dist_slot = get_dist_slot(best_dist);
            uint32_t len_state = best_len - 2;
            if (len_state > 3) len_state = 3;
            
            ttzip_rc_encode_bit_tree(&rc, probs->dist_slot[len_state], 6, dist_slot);
            
            if (dist_slot >= 4) {
                uint32_t num_direct_bits = (dist_slot >> 1) - 1;
                uint32_t base_dist = (2 | (dist_slot & 1)) << num_direct_bits;
                uint32_t direct_bits = best_dist - base_dist;
                
                if (dist_slot < 14) {
                    ttzip_rc_encode_reverse_bit_tree(&rc, probs->dist_special + base_dist - dist_slot - 1,
                                                      num_direct_bits, direct_bits);
                } else {
                    ttzip_rc_encode_direct(&rc, direct_bits >> 4, num_direct_bits - 4);
                    ttzip_rc_encode_reverse_bit_tree(&rc, probs->dist_align, 4, direct_bits & 0xF);
                }
            }
            
            rep[3] = rep[2];
            rep[2] = rep[1];
            rep[1] = rep[0];
            rep[0] = best_dist;
            
            ttzip_hc4_skip(&mf, best_len - 1);
        }
    }
    
    ttzip_rc_flush(&rc);
    size_t packed_payload_size = ttzip_rc_get_processed_size(&rc);
    
    // Fallback: If compressed output >= src_len, emit raw uncompressed chunks (0x01 / 0x02)
    if (packed_payload_size >= src_len) {
        size_t out_idx = 0;
        size_t unp_rem = src_len;
        const uint8_t* s_ptr = src;
        bool is_first = true;
        const size_t kMaxUncompressedChunkSize = 65536;

        while (unp_rem > 0) {
            size_t chunk_sz = unp_rem < kMaxUncompressedChunkSize ? unp_rem : kMaxUncompressedChunkSize;
            dst[out_idx++] = is_first ? 0x01 : 0x02;
            is_first = false;
            uint16_t sz_minus_1 = (uint16_t)(chunk_sz - 1);
            dst[out_idx++] = (uint8_t)(sz_minus_1 >> 8);
            dst[out_idx++] = (uint8_t)(sz_minus_1 & 0xFF);
            memcpy(dst + out_idx, s_ptr, chunk_sz);
            out_idx += chunk_sz;
            s_ptr += chunk_sz;
            unp_rem -= chunk_sz;
        }
        dst[out_idx++] = 0x00; // LZMA2 End Marker
        *out_compressed_len = out_idx;
        
        free(rc_buf);
        free(probs);
        ttzip_hc4_free(&mf);
        return 0;
    }
    
    const size_t kMaxChunkUnpackSize = 2 * 1024 * 1024;
    size_t out_idx = 0;
    
    if (src_len <= kMaxChunkUnpackSize) {
        uint8_t control_byte = 0xE0 | (uint8_t)((src_len - 1) >> 16);
        uint16_t unp_size_low = (uint16_t)((src_len - 1) & 0xFFFF);
        uint16_t pack_size_low = (uint16_t)((packed_payload_size - 1) & 0xFFFF);
        uint8_t pack_size_high = (uint8_t)((packed_payload_size - 1) >> 16);
        uint8_t props_byte = 0x5D;
        
        dst[out_idx++] = control_byte;
        dst[out_idx++] = (uint8_t)(unp_size_low >> 8);
        dst[out_idx++] = (uint8_t)(unp_size_low & 0xFF);
        dst[out_idx++] = pack_size_high;
        dst[out_idx++] = (uint8_t)(pack_size_low >> 8);
        dst[out_idx++] = (uint8_t)(pack_size_low & 0xFF);
        dst[out_idx++] = props_byte;
        memcpy(dst + out_idx, rc_buf, packed_payload_size);
        out_idx += packed_payload_size;
    } else {
        size_t unp_rem = src_len;
        bool is_first_chunk = true;
        
        while (unp_rem > 0) {
            size_t chunk_unp = unp_rem < kMaxChunkUnpackSize ? unp_rem : kMaxChunkUnpackSize;
            size_t chunk_pack = (packed_payload_size * chunk_unp) / src_len + 16;
            if (chunk_pack > packed_payload_size) chunk_pack = packed_payload_size;
            
            uint8_t control_byte = is_first_chunk ? (0xE0 | (uint8_t)((chunk_unp - 1) >> 16))
                                                 : (0x80 | (uint8_t)((chunk_unp - 1) >> 16));
            uint16_t unp_size_low = (uint16_t)((chunk_unp - 1) & 0xFFFF);
            uint16_t pack_size_low = (uint16_t)((chunk_pack - 1) & 0xFFFF);
            uint8_t pack_size_high = (uint8_t)((chunk_pack - 1) >> 16);
            
            dst[out_idx++] = control_byte;
            dst[out_idx++] = (uint8_t)(unp_size_low >> 8);
            dst[out_idx++] = (uint8_t)(unp_size_low & 0xFF);
            dst[out_idx++] = pack_size_high;
            dst[out_idx++] = (uint8_t)(pack_size_low >> 8);
            dst[out_idx++] = (uint8_t)(pack_size_low & 0xFF);
            
            if (is_first_chunk) {
                dst[out_idx++] = 0x5D;
                is_first_chunk = false;
            }
            
            size_t bytes_to_copy = chunk_pack < packed_payload_size ? chunk_pack : packed_payload_size;
            memcpy(dst + out_idx, rc_buf, bytes_to_copy);
            out_idx += bytes_to_copy;
            
            unp_rem -= chunk_unp;
        }
    }
    
    dst[out_idx++] = 0x00; // LZMA2 End Marker
    *out_compressed_len = out_idx;
    
    free(rc_buf);
    free(probs);
    ttzip_hc4_free(&mf);
    
    return 0;
}

#include <lzma.h>

int ttzip_lzma2_compress_block_tuned(
    const uint8_t* src,
    size_t src_len,
    uint8_t* dst,
    size_t dst_capacity,
    size_t* out_compressed_len,
    int level,
    bool is_zero_block,
    uint32_t* out_dict_size
) {
    if (!src || !dst || !out_compressed_len) return -1;

    lzma_options_lzma opts;
    uint32_t preset = (uint32_t)level;
    if (lzma_lzma_preset(&opts, preset)) {
        return -2;
    }

    if (is_zero_block) {
        opts.mode = LZMA_MODE_FAST;
        opts.mf = LZMA_MF_HC3;
        opts.nice_len = 273;
        opts.depth = 1;
        opts.dict_size = 4096;
    } else if (level == 1) {
        opts.mode = LZMA_MODE_FAST;
        opts.mf = LZMA_MF_HC3;
        opts.nice_len = 6;
        opts.depth = 1;
        opts.dict_size = 65536;
    } else if (level <= 5) {
        opts.mode = LZMA_MODE_FAST;
        opts.mf = LZMA_MF_HC4;
        opts.nice_len = 16;
        opts.depth = 2;
        opts.dict_size = 524288;
    }

    if (opts.dict_size > (uint32_t)src_len && src_len > 0) {
        uint32_t ds = 4096;
        while (ds < (uint32_t)src_len && ds < opts.dict_size) {
            ds <<= 1;
        }
        opts.dict_size = ds;
    }

    if (out_dict_size) {
        *out_dict_size = opts.dict_size;
    }

    lzma_filter filters[2];
    filters[0].id = LZMA_FILTER_LZMA2;
    filters[0].options = &opts;
    filters[1].id = LZMA_VLI_UNKNOWN;

    size_t out_pos = 0;
    lzma_ret ret = lzma_raw_buffer_encode(filters, NULL, src, src_len, dst, &out_pos, dst_capacity);
    if (ret == LZMA_OK) {
        *out_compressed_len = out_pos;
        return 0;
    }
    return -4;
}
