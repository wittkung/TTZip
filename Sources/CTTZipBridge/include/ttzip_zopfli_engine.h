// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_zopfli_engine.h
 * @brief High-ratio Deflate compressor and Zopfli wrapper with history warm-up.
 * @details Declares options structures and C entry points for in-process Deflate chunk
 *          compression, dictionary seeding, and dynamic block splitting.
 */

#ifndef TTZIP_ZOPFLI_ENGINE_H
#define TTZIP_ZOPFLI_ENGINE_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Configuration tuning parameters for in-process Zopfli iterative Deflate compression.
 */
typedef struct {
    int    compression_level;    /**< Target compression level (1..15). */
    int    num_iterations;       /**< Iteration count (Level 6: 5 passes, Level 7: 15 passes). */
    int    block_splitting;      /**< Non-zero to enable dynamic entropy-driven block splitting. */
    int    max_block_splits;     /**< Upper limit on the number of block splits (default 15). */
    double early_exit_threshold; /**< Asymptotic convergence threshold (default 0.0001 = 0.01%). */
} TTZipZopfliOptions;

/**
 * @brief Initializes a TTZipZopfliOptions structure with default parameters for a given level.
 *
 * @param[out] options Destination options structure to initialize.
 * @param[in]  level   Requested compression level (1..12).
 */
void ttzip_zopfli_init_options(TTZipZopfliOptions *options, int level);

/**
 * @brief Compresses a block using multi-pass Zopfli graph optimization with history dictionary warm-up.
 *
 * @param[in]  in           Input uncompressed data buffer.
 * @param[in]  in_size      Length of uncompressed data in bytes.
 * @param[in]  history      Pointer to preceding 32KB history dictionary, or NULL.
 * @param[in]  history_size Size of preceding history dictionary in bytes (<= 32768).
 * @param[out] out          Destination buffer receiving Deflate bitstream.
 * @param[in]  out_capacity Total allocated capacity of out buffer in bytes.
 * @param[in]  options      Tuning options (iterations, block splitting).
 * @param[in]  is_final     Non-zero if this is the final block in the stream.
 *
 * @return Number of compressed bytes written to out, or 0 on overflow / error.
 */
size_t ttzip_zopfli_compress_block_with_history(
    const uint8_t *in,
    size_t in_size,
    const uint8_t *history,
    size_t history_size,
    uint8_t *out,
    size_t out_capacity,
    const TTZipZopfliOptions *options,
    int is_final
);

/**
 * @brief Compresses a chunk using the native in-process Apple Silicon Deflate engine.
 *
 * @param[in]  in           Input uncompressed data buffer.
 * @param[in]  in_size      Length of uncompressed data in bytes.
 * @param[in]  history      Pointer to preceding 32KB history dictionary, or NULL.
 * @param[in]  history_size Size of preceding history dictionary in bytes (<= 32768).
 * @param[out] out          Destination buffer receiving Deflate bitstream.
 * @param[in]  out_capacity Total allocated capacity of out buffer in bytes.
 * @param[in]  tier_level   Tier level (1 = Fast, 2 = Fast+, 3 = Normal, 4 = Maximum).
 * @param[in]  is_final     Non-zero if this is the final chunk in the stream.
 *
 * @return Number of compressed bytes written to out, or 0 on overflow / error.
 */
size_t ttzip_native_deflate_compress_chunk_with_history(
    const uint8_t *in,
    size_t in_size,
    const uint8_t *history,
    size_t history_size,
    uint8_t *out,
    size_t out_capacity,
    int tier_level,
    int is_final
);

#ifdef __cplusplus
}
#endif

#endif /* TTZIP_ZOPFLI_ENGINE_H */
