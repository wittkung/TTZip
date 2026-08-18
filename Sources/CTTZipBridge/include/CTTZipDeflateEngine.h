// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file CTTZipDeflateEngine.h
 * @brief Unified public C API for single-core ultra-high-throughput DEFLATE compression & decompression.
 */

#ifndef CTTZipDeflateEngine_h
#define CTTZipDeflateEngine_h

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

#define TTZIP_DEFLATE_WINSIZE 32768
#define TTZIP_DEFLATE_MAX_MATCH 258
#define TTZIP_DEFLATE_MIN_MATCH 3

typedef struct ttzip_deflate_compressor ttzip_deflate_compressor_t;
typedef struct ttzip_deflate_decompressor ttzip_deflate_decompressor_t;

/**
 * @brief Allocates and initializes a native single-core DEFLATE compressor context.
 * @param level Compression level (1..9). Level 1 = Fast Greedy / NEON 4-way, Level 6 = Balanced Near-Optimal.
 * @return Opaque compressor pointer, or NULL on error.
 */
ttzip_deflate_compressor_t *ttzip_deflate_compressor_alloc(int level);

/**
 * @brief Frees the compressor context.
 */
void ttzip_deflate_compressor_free(ttzip_deflate_compressor_t *c);

/**
 * @brief Compresses an uncompressed buffer into a raw RFC 1951 DEFLATE stream.
 * @param c Compressor context.
 * @param in Input uncompressed data.
 * @param in_size Size of input data in bytes.
 * @param out Output buffer.
 * @param out_capacity Maximum capacity of output buffer.
 * @return Number of compressed bytes written, or 0 on error / buffer overflow.
 */
size_t ttzip_deflate_compress(
    ttzip_deflate_compressor_t *c,
    const void *in,
    size_t in_size,
    void *out,
    size_t out_capacity
);

/**
 * @brief Allocates and initializes a native single-core DEFLATE decompressor context.
 * @return Opaque decompressor pointer, or NULL on error.
 */
ttzip_deflate_decompressor_t *ttzip_deflate_decompressor_alloc(void);

/**
 * @brief Frees the decompressor context.
 */
void ttzip_deflate_decompressor_free(ttzip_deflate_decompressor_t *d);

/**
 * @brief Decompresses a raw RFC 1951 DEFLATE stream into an output buffer using dual-symbol direct LUT.
 * @param d Decompressor context.
 * @param in Compressed input stream.
 * @param in_size Size of compressed input in bytes.
 * @param out Output buffer.
 * @param out_capacity Allocated capacity of output buffer.
 * @param actual_out_size Pointer to receive exact decompressed size.
 * @return 0 on success, non-zero on corrupt/invalid stream.
 */
int ttzip_deflate_decompress(
    ttzip_deflate_decompressor_t *d,
    const void *in,
    size_t in_size,
    void *out,
    size_t out_capacity,
    size_t *actual_out_size
);

typedef struct {
    uint32_t litlen[288];
    uint32_t offset[32];
} ttzip_symbol_freqs_t;

void ttzip_build_canonical_huffman_tree(
    const uint32_t *freqs,
    unsigned num_syms,
    unsigned max_codeword_len,
    uint8_t *lens_out,
    uint32_t *codewords_out
);

bool ttzip_eval_huffman_bit_costs(
    const ttzip_symbol_freqs_t *freqs,
    const uint8_t *dynamic_lens_litlen,
    const uint8_t *dynamic_lens_offset,
    uint64_t *out_static_bits,
    uint64_t *out_dynamic_bits
);

#ifdef __cplusplus
}
#endif

#endif /* CTTZipDeflateEngine_h */
