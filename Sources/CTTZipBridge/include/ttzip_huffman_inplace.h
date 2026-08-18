// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_huffman_inplace.h
 * @brief In-Place Zero-Heap Canonical Length-Limited Huffman Tree Generator.
 * @details Implements Van Leeuwen two-queue in-place leaf merging, reverse topological
 *          depth computation, shallow-leaf borrowing, and ARM64 RBIT bit-reversal.
 */

#ifndef TTZIP_HUFFMAN_INPLACE_H
#define TTZIP_HUFFMAN_INPLACE_H

#include "ttzip_platform.h"
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

#define TTZIP_HUFF_SYM_BITS     10
#define TTZIP_HUFF_SYM_MASK     ((1U << TTZIP_HUFF_SYM_BITS) - 1U)
#define TTZIP_HUFF_FREQ_MASK    (~TTZIP_HUFF_SYM_MASK)
#define TTZIP_HUFF_MAX_CODE_LEN 15

/**
 * @brief Flips the lowest `len` bits of a 16-bit canonical codeword (LSB-first emission).
 *
 * @param[in] code The canonical codeword (numerically MSB-first).
 * @param[in] len  The codeword length in bits (1 <= len <= 15).
 * @return Bit-reversed codeword.
 */
TTZIP_API uint32_t ttzip_canonical_bit_reverse(uint32_t code, uint8_t len);

/**
 * @brief In-Place Length-Limited Canonical Huffman Code Generator.
 *
 * @param[in]  num_syms         Total alphabet size (e.g., 288 for litlen, 32 for offset, 19 for precode).
 * @param[in]  max_codeword_len Maximum allowed codeword length in bits (typically <= 15).
 * @param[in]  freqs            Array of symbol frequencies (length = num_syms).
 * @param[out] lens             Array to receive codeword bit lengths (length = num_syms).
 * @param[out] codewords        Working and output array (length = num_syms). Used in-place as A[] during tree generation.
 * @param[in]  bit_reverse      True to emit RFC 1951 bit-reversed codewords.
 *
 * @pre `num_syms >= 2 && max_codeword_len <= 15 && freqs != NULL && lens != NULL && codewords != NULL`
 * @post `codewords` contains canonical codewords; `lens` contains codeword bit lengths satisfying Kraft-McMillan.
 * @complexity Time: O(N) | Space: O(1) auxiliary (zero heap allocation).
 * @threadsafe 100% reentrant and thread-safe.
 */
TTZIP_API void ttzip_make_canonical_huffman_code_inplace(
    unsigned num_syms,
    unsigned max_codeword_len,
    const uint32_t freqs[],
    uint8_t lens[],
    uint32_t codewords[],
    bool bit_reverse
);

#ifdef __cplusplus
}
#endif

#endif // TTZIP_HUFFMAN_INPLACE_H
