// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#ifndef TTZIP_BRANCHLESS_DECOMP_H
#define TTZIP_BRANCHLESS_DECOMP_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

#define TTZIP_HUFFMAN_LUT_BITS 11
#define TTZIP_HUFFMAN_LUT_SIZE (1U << TTZIP_HUFFMAN_LUT_BITS) // 2048

/**
 * @brief 64-bit Bitstream Reader state machine.
 */
typedef struct {
    uint64_t bit_buf;
    int32_t bit_count;
    const uint8_t *in_ptr;
    const uint8_t *in_limit;
    uint32_t is_eof;
} ttzip_bitstream_reader_t;

/**
 * @brief 11-bit direct lookup Huffman decoder table.
 * Lookup entry format: high 16 bits = code length (len), low 16 bits = symbol value.
 */
typedef struct {
    uint32_t table_bits;
    uint32_t max_code_len;
    uint32_t table_max_code;
    uint32_t num_symbols;
    uint32_t lookup[TTZIP_HUFFMAN_LUT_SIZE];
} ttzip_huffman_lut_t;

/**
 * @brief Power-of-two circular ring dictionary state.
 */
typedef struct {
    uint8_t *dict_buf;
    size_t dict_size;
    size_t dict_size_mask;
    size_t write_pos;
    size_t total_written;
} ttzip_ring_dict_t;

/**
 * @brief Initialize a 64-bit bitstream reader.
 */
void ttzip_bitstream_init(ttzip_bitstream_reader_t *reader, const uint8_t *in_buf, size_t in_size);

/**
 * @brief Refill bitstream buffer ensuring at least 24 bits available.
 */
void ttzip_bitstream_refill(ttzip_bitstream_reader_t *reader);

/**
 * @brief Build 11-bit fast lookup table from canonical code lengths.
 */
int ttzip_huffman_build_lut(
    ttzip_huffman_lut_t *lut,
    const uint8_t *code_lengths,
    uint32_t num_symbols
);

/**
 * @brief Branchless single-cycle decode of next Huffman symbol from bitstream.
 */
static inline uint32_t ttzip_huffman_decode_symbol(
    ttzip_bitstream_reader_t *reader,
    const ttzip_huffman_lut_t *lut,
    uint16_t *out_symbol
) {
    if (reader->bit_count < TTZIP_HUFFMAN_LUT_BITS) {
        ttzip_bitstream_refill(reader);
    }
    uint32_t idx = (uint32_t)(reader->bit_buf >> (64 - TTZIP_HUFFMAN_LUT_BITS));
    uint32_t entry = lut->lookup[idx];
    *out_symbol = (uint16_t)(entry & 0xFFFF);
    uint32_t len = entry >> 16;
    reader->bit_buf <<= len;
    reader->bit_count -= len;
    return len;
}

/**
 * @brief Initialize a power-of-two circular ring dictionary.
 */
int ttzip_ring_dict_init(
    ttzip_ring_dict_t *dict,
    uint8_t *buffer,
    size_t dict_size
);

/**
 * @brief Perform optimized match copy with Fast-Path / Slow-Path bifurcation.
 */
int ttzip_ring_dict_copy_match(
    ttzip_ring_dict_t *dict,
    size_t match_dist,
    size_t match_len
);

#ifdef __cplusplus
}
#endif

#endif // TTZIP_BRANCHLESS_DECOMP_H
