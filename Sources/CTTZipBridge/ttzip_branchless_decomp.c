// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_branchless_decomp.c
 * @brief High-performance branchless decompression state machine & power-of-two circular dictionary.
 */

#include "include/ttzip_branchless_decomp.h"
#include <string.h>

#if defined(__ARM_NEON) || defined(__ARM_NEON__)
#include <arm_neon.h>
#endif

#ifndef LZHAM_MAX
#define LZHAM_MAX(a, b) ((a) > (b) ? (a) : (b))
#endif

void ttzip_bitstream_init(ttzip_bitstream_reader_t *reader, const uint8_t *in_buf, size_t in_size) {
    if (!reader) return;
    reader->bit_buf = 0;
    reader->bit_count = 0;
    reader->in_ptr = in_buf;
    reader->in_limit = in_buf ? (in_buf + in_size) : NULL;
    reader->is_eof = (in_buf && in_size > 0) ? 0 : 1;
    ttzip_bitstream_refill(reader);
}

void ttzip_bitstream_refill(ttzip_bitstream_reader_t *reader) {
    if (!reader || reader->is_eof) return;

    // Fast-path: 32-bit chunk big-endian refill when >= 4 bytes available
    while (reader->bit_count <= 32 && (reader->in_limit - reader->in_ptr) >= 4) {
        uint32_t b0 = reader->in_ptr[0];
        uint32_t b1 = reader->in_ptr[1];
        uint32_t b2 = reader->in_ptr[2];
        uint32_t b3 = reader->in_ptr[3];
        uint32_t word = (b0 << 24) | (b1 << 16) | (b2 << 8) | b3;
        reader->in_ptr += 4;
        reader->bit_buf |= ((uint64_t)word << (32 - reader->bit_count));
        reader->bit_count += 32;
    }

    // Byte-by-byte tail refill
    while (reader->bit_count <= 56 && reader->in_ptr < reader->in_limit) {
        uint64_t byte = *reader->in_ptr++;
        reader->bit_count += 8;
        reader->bit_buf |= (byte << (64 - reader->bit_count));
    }

    if (reader->in_ptr >= reader->in_limit) {
        reader->is_eof = 1;
    }
}

int ttzip_huffman_build_lut(
    ttzip_huffman_lut_t *lut,
    const uint8_t *code_lengths,
    uint32_t num_symbols
) {
    if (!lut || !code_lengths || num_symbols == 0) {
        return -1;
    }

    lut->table_bits = TTZIP_HUFFMAN_LUT_BITS;
    lut->num_symbols = num_symbols;
    lut->max_code_len = 0;
    lut->table_max_code = 0;

    // Count frequencies of each code length (0..16)
    uint32_t bl_count[17] = {0};
    for (uint32_t i = 0; i < num_symbols; i++) {
        uint8_t len = code_lengths[i];
        if (len > 16) return -2;
        if (len > 0) {
            bl_count[len]++;
            if (len > lut->max_code_len) {
                lut->max_code_len = len;
            }
        }
    }

    // Compute base code for each length
    uint32_t next_code[17] = {0};
    uint32_t code = 0;
    for (uint32_t bits = 1; bits <= 16; bits++) {
        code = (code + bl_count[bits - 1]) << 1;
        next_code[bits] = code;
    }

    // Initialize all LUT entries with invalid marker
    memset(lut->lookup, 0, sizeof(lut->lookup));

    // Assign canonical codes and populate 11-bit lookup table
    for (uint32_t sym = 0; sym < num_symbols; sym++) {
        uint32_t len = code_lengths[sym];
        if (len == 0) continue;

        uint32_t sym_code = next_code[len]++;
        if (len <= TTZIP_HUFFMAN_LUT_BITS) {
            // Fill all entries matching this prefix in the 11-bit table
            uint32_t entry = (len << 16) | (sym & 0xFFFF);
            uint32_t num_entries = 1U << (TTZIP_HUFFMAN_LUT_BITS - len);
            uint32_t base_idx = sym_code << (TTZIP_HUFFMAN_LUT_BITS - len);
            for (uint32_t j = 0; j < num_entries; j++) {
                lut->lookup[base_idx + j] = entry;
            }
        }
    }

    return 0;
}

int ttzip_ring_dict_init(
    ttzip_ring_dict_t *dict,
    uint8_t *buffer,
    size_t dict_size
) {
    if (!dict || !buffer || dict_size < 32768) {
        return -1;
    }
    // Dict size must be power of two
    if ((dict_size & (dict_size - 1)) != 0) {
        return -2;
    }

    dict->dict_buf = buffer;
    dict->dict_size = dict_size;
    dict->dict_size_mask = dict_size - 1;
    dict->write_pos = 0;
    dict->total_written = 0;
    return 0;
}

int ttzip_ring_dict_copy_match(
    ttzip_ring_dict_t *dict,
    size_t match_dist,
    size_t match_len
) {
    if (!dict || !dict->dict_buf || match_dist == 0 || match_dist > dict->dict_size || match_len == 0) {
        return -1;
    }

    uint8_t *pDst = dict->dict_buf;
    size_t dict_mask = dict->dict_size_mask;
    size_t dst_ofs = dict->write_pos;
    size_t src_ofs = (dst_ofs - match_dist) & dict_mask;

    // Fast-Path: Neither src nor dst wraps across the end of circular dictionary
    if (__builtin_expect(((LZHAM_MAX(src_ofs, dst_ofs) + match_len) <= dict_mask), 1)) {
        uint8_t *pCopy_dst = pDst + dst_ofs;
        const uint8_t *pCopy_src = pDst + src_ofs;

        if (__builtin_expect(match_dist == 1, 0)) {
            // RLE byte run specialization
            uint8_t c = *pCopy_src;
            if (match_len < 8) {
                for (size_t i = 0; i < match_len; i++) {
                    pCopy_dst[i] = c;
                }
            } else {
                memset(pCopy_dst, c, match_len);
            }
        } else if (__builtin_expect((match_len < 8 || match_len > match_dist), 1)) {
            // Self-overlapping match or tiny copy: byte-by-byte sequential
            for (size_t i = 0; i < match_len; i++) {
                pCopy_dst[i] = pCopy_src[i];
            }
        } else {
            // Non-overlapping bulk match: ARM NEON vector copy
#if defined(__ARM_NEON) || defined(__ARM_NEON__)
            size_t rem = match_len;
            while (rem >= 64) {
                uint8x16_t v0 = vld1q_u8(pCopy_src);
                uint8x16_t v1 = vld1q_u8(pCopy_src + 16);
                uint8x16_t v2 = vld1q_u8(pCopy_src + 32);
                uint8x16_t v3 = vld1q_u8(pCopy_src + 48);
                vst1q_u8(pCopy_dst, v0);
                vst1q_u8(pCopy_dst + 16, v1);
                vst1q_u8(pCopy_dst + 32, v2);
                vst1q_u8(pCopy_dst + 48, v3);
                pCopy_src += 64;
                pCopy_dst += 64;
                rem -= 64;
            }
            while (rem >= 16) {
                uint8x16_t v = vld1q_u8(pCopy_src);
                vst1q_u8(pCopy_dst, v);
                pCopy_src += 16;
                pCopy_dst += 16;
                rem -= 16;
            }
            while (rem--) {
                *pCopy_dst++ = *pCopy_src++;
            }
#else
            memcpy(pCopy_dst, pCopy_src, match_len);
#endif
        }

        dict->write_pos = (dst_ofs + match_len) & dict_mask;
        dict->total_written += match_len;
        return 0;
    }

    // Slow-Path: Wrap-around boundary handling (< 0.01% of occurrences)
    for (size_t i = 0; i < match_len; i++) {
        pDst[dst_ofs] = pDst[src_ofs];
        dst_ofs = (dst_ofs + 1) & dict_mask;
        src_ofs = (src_ofs + 1) & dict_mask;
    }

    dict->write_pos = dst_ofs;
    dict->total_written += match_len;
    return 0;
}
