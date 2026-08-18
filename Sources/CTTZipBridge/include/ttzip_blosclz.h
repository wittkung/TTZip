// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#ifndef TTZIP_BLOSCLZ_H
#define TTZIP_BLOSCLZ_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

#define TTZIP_BLOSCLZ_VERSION "2.5.1"
#define TTZIP_BLOSCLZ_VERSION_MAJOR 2
#define TTZIP_BLOSCLZ_VERSION_MINOR 5

/**
 * Compresses input buffer using native BloscLZ byte-oriented LZ77 engine.
 *
 * @param input Pointer to uncompressed source data
 * @param length Source data length in bytes
 * @param output Pointer to destination buffer (must be at least length + 16 bytes)
 * @param maxout Maximum writable bytes in output
 * @param clevel Compression level (1..9)
 * @param hash_log Hash table bit size (12..14, default: 13 for level <= 4, 14 for level >= 5)
 * @return Number of compressed bytes written, or 0 if output buffer is too small
 */
int ttzip_blosclz_compress(
    const void* input,
    int length,
    void* output,
    int maxout,
    int clevel,
    int hash_log
);

/**
 * Decompresses BloscLZ compressed stream into destination buffer.
 *
 * @param input Pointer to compressed source stream
 * @param length Compressed data length in bytes
 * @param output Pointer to uncompressed destination buffer
 * @param maxout Maximum writable uncompressed bytes in output
 * @return Number of uncompressed bytes decompressed, or 0 on corruption/overflow
 */
int ttzip_blosclz_decompress(
    const void* input,
    int length,
    void* output,
    int maxout
);

#ifdef __cplusplus
}
#endif

#endif /* TTZIP_BLOSCLZ_H */
