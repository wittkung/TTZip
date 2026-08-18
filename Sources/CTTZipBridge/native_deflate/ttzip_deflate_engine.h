// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_deflate_engine.h
 * @brief Public interface and shared data structures for native Apple Silicon Deflate engine.
 * @details Unifies bitstream emitters, greedy/lazy match finders, canonical Huffman builders,
 *          and multi-tier compression options for zero-dependency in-process Deflate streams.
 */

#ifndef TTZIP_DEFLATE_ENGINE_H
#define TTZIP_DEFLATE_ENGINE_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include "ttzip_deflate_bitstream.h"
#include "ttzip_deflate_huffman.h"

#ifdef __cplusplus
extern "C" {
#endif

#define TTZIP_DEFLATE_WINDOW_SIZE   32768
#define TTZIP_DEFLATE_MAX_MATCH_LEN 258
#define TTZIP_DEFLATE_MIN_MATCH_LEN 3

typedef int16_t ttzip_mf_pos_t;

/**
 * @brief Tier 1/2 Fast 2-Way direct pointer match finder cache (aligned to 64-byte cache line).
 */
typedef struct __attribute__((aligned(64))) {
    const uint8_t *hash_tab[32768][2];
} ttzip_deflate_fast_mf_t;

/**
 * @brief Tier 3/4 Lazy Hash3 + Hash4 chained pointer match finder cache (aligned to 64-byte cache line).
 */
typedef struct __attribute__((aligned(64))) {
    const uint8_t *hash3_tab[32768];
    const uint8_t *hash4_tab[32768];
    const uint8_t *next_tab[32768];
} ttzip_deflate_lazy_mf_t;

/**
 * @brief Intermediate LZ77 token representing either a literal byte or a match pair.
 */
typedef struct {
    uint16_t length; /**< 0 = literal (stored in low 8 bits of offset), 3..258 = match length. */
    uint16_t offset; /**< 1..32768 match distance backward from current position. */
} ttzip_deflate_token_t;

/* Length slot lookup table (3..258) */
extern uint8_t        s_length_slot[259];
extern const uint16_t s_length_base[29];
extern const uint8_t  s_length_extra_bits[29];

/* Distance slot lookup table (1..32768) */
extern uint8_t        s_offset_slot[32769];
extern const uint16_t s_offset_base[30];
extern const uint8_t  s_offset_extra_bits[30];

/**
 * @brief Compression tuning options for native Deflate block compression.
 */
typedef struct {
    int32_t  tier_level;            /**< Compression tier (1..7). */
    uint32_t max_chain_depth;       /**< Maximum hash chain traversal depth. */
    uint32_t nice_match_len;        /**< Early match cutoff threshold. */
    bool     dynamic_huffman;       /**< True to emit dynamic Huffman trees; false for static. */
    bool     enable_history_warmup; /**< True to seed match finder with 32KB cross-tile history. */
} ttzip_native_deflate_options_t;

/**
 * @brief Compresses a single block or tile using the native in-process Deflate engine.
 *
 * @param[in]  in           Input uncompressed data buffer.
 * @param[in]  in_size      Length of uncompressed data in bytes.
 * @param[in]  history      Pointer to preceding 32KB history dictionary, or NULL.
 * @param[in]  history_size Size of preceding history dictionary in bytes (<= 32768).
 * @param[out] out          Destination buffer receiving Deflate bitstream.
 * @param[in]  out_capacity Total allocated capacity of out buffer in bytes.
 * @param[in]  options      Tuning options (tier level, chain depth, dynamic Huffman).
 * @param[in]  is_final     True if this is the final block (BFINAL=1) in the stream.
 *
 * @return Number of compressed bytes written to out, or 0 on overflow / error.
 */
size_t ttzip_native_deflate_compress_block_with_history(
    const uint8_t *in,
    size_t in_size,
    const uint8_t *history,
    size_t history_size,
    uint8_t *out,
    size_t out_capacity,
    const ttzip_native_deflate_options_t *options,
    bool is_final
);

#ifdef __cplusplus
}
#endif

#endif /* TTZIP_DEFLATE_ENGINE_H */
