// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_deflate_huffman.h
 * @brief RFC 1951 Canonical Huffman code generators, headers, and lookup tables.
 * @details Provides length-limited canonical Huffman prefix code construction,
 *          dynamic header RLE encoding, and pre-computed static table singletons.
 */

#ifndef TTZIP_DEFLATE_HUFFMAN_H
#define TTZIP_DEFLATE_HUFFMAN_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include "ttzip_deflate_bitstream.h"

#ifdef __cplusplus
extern "C" {
#endif

#define TTZIP_DEFLATE_NUM_LITLEN_SYMS  286
#define TTZIP_DEFLATE_NUM_OFFSET_SYMS  30
#define TTZIP_DEFLATE_NUM_PRECODE_SYMS 19

#define TTZIP_DEFLATE_MAX_CODEWORD_LEN 15
#define TTZIP_DEFLATE_MAX_PRECODE_LEN  7

/**
 * @brief RFC 1951 Canonical Huffman Code tables container.
 */
typedef struct {
    uint32_t codewords_litlen[TTZIP_DEFLATE_NUM_LITLEN_SYMS + 2]; /**< Bit-reversed literal/length canonical codewords. */
    uint8_t  lens_litlen[TTZIP_DEFLATE_NUM_LITLEN_SYMS + 2];      /**< Bit lengths for literal/length symbols. */
    uint32_t codewords_offset[TTZIP_DEFLATE_NUM_OFFSET_SYMS + 2]; /**< Bit-reversed offset canonical codewords. */
    uint8_t  lens_offset[TTZIP_DEFLATE_NUM_OFFSET_SYMS + 2];      /**< Bit lengths for offset symbols. */
} ttzip_huffman_codes_t;

/**
 * @brief Deflate symbol frequency histogram.
 */
typedef struct {
    uint32_t litlen[TTZIP_DEFLATE_NUM_LITLEN_SYMS + 2]; /**< Literal (0..255), EOB (256), and Length (257..285) counts. */
    uint32_t offset[TTZIP_DEFLATE_NUM_OFFSET_SYMS + 2]; /**< Distance slot (0..29) counts. */
} ttzip_symbol_freqs_t;

/**
 * @brief Returns the process-wide immutable singleton for static RFC 1951 Huffman codes.
 *
 * @return Pointer to pre-initialized static Huffman code table.
 */
const ttzip_huffman_codes_t *ttzip_get_static_huffman_codes(void);

/**
 * @brief Generates length-limited Canonical Huffman code lengths and bit-reversed codewords.
 *
 * @param[in]  freqs            Array of symbol frequencies (length = num_syms).
 * @param[in]  num_syms         Alphabet size (e.g. 286, 30, or 19).
 * @param[in]  max_codeword_len Maximum allowable codeword bit length (<= 15).
 * @param[out] lens_out         Output array receiving codeword bit lengths (length = num_syms).
 * @param[out] codewords_out    Optional output array receiving bit-reversed codewords (length = num_syms).
 */
void ttzip_build_canonical_huffman_tree(const uint32_t *freqs,
                                        unsigned num_syms,
                                        unsigned max_codeword_len,
                                        uint8_t *lens_out,
                                        uint32_t *codewords_out);

/**
 * @brief Writes RFC 1951 dynamic Huffman tree header (HLIT, HDIST, HCLEN, and precode RLE stream).
 *
 * @param[in,out] bs               Active bitstream writer.
 * @param[in]     lens_litlen      Array of literal/length codeword lengths.
 * @param[in]     num_litlen_syms  Number of literal/length symbols (257..286).
 * @param[in]     lens_offset      Array of distance codeword lengths.
 * @param[in]     num_offset_syms  Number of distance symbols (1..30).
 */
void ttzip_write_dynamic_huffman_header(ttzip_bitstream_t *bs,
                                        const uint8_t *lens_litlen,
                                        unsigned num_litlen_syms,
                                        const uint8_t *lens_offset,
                                        unsigned num_offset_syms);

#ifdef __cplusplus
}
#endif

#endif /* TTZIP_DEFLATE_HUFFMAN_H */
