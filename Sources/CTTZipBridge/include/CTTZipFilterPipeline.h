// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#ifndef CTTZipFilterPipeline_h
#define CTTZipFilterPipeline_h

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Filter Type Identifiers for Zero-Alloc Pre-compression Transformation
 */
typedef enum {
    TTZIP_FILTER_NONE      = 0,
    TTZIP_FILTER_SHUFFLE   = 1, // ARM NEON Byte Shuffle (4/8/16-byte transposition)
    TTZIP_FILTER_DELTA     = 2, // 1st-order Delta Differential (ByteDiff)
    TTZIP_FILTER_BITSHUFFLE = 3 // 8-bit vector bit transposition
} ttzip_filter_type_t;

/**
 * @brief Zero-Allocation In-Place / Stack-Buffered Filter Pipeline
 */
typedef struct {
    ttzip_filter_type_t filters[4];
    uint8_t type_sizes[4]; // Element type size (1, 2, 4, 8)
    size_t count;
} ttzip_filter_pipeline_t;

/**
 * @brief Applies NEON Byte Shuffle on a buffer (forward transformation).
 */
void ttzip_filter_shuffle_forward(const uint8_t* src, uint8_t* dst, size_t size, uint8_t typesize);

/**
 * @brief Applies NEON Byte Unshuffle on a buffer (backward / inverse transformation).
 */
void ttzip_filter_shuffle_backward(const uint8_t* src, uint8_t* dst, size_t size, uint8_t typesize);

/**
 * @brief Applies Delta differential transformation (forward).
 */
void ttzip_filter_delta_forward(uint8_t* buf, size_t size);

/**
 * @brief Applies Delta prefix sum inverse transformation (backward).
 */
void ttzip_filter_delta_backward(uint8_t* buf, size_t size);

/**
 * @brief Executes a full filter pipeline forward with zero dynamic heap allocation
 * using 64KB stack double-buffering.
 */
int ttzip_filter_pipeline_apply_forward(
    const ttzip_filter_pipeline_t* pipeline,
    const uint8_t* src,
    uint8_t* dst,
    size_t size
);

/**
 * @brief Inverses a full filter pipeline backward with zero dynamic heap allocation.
 */
int ttzip_filter_pipeline_apply_backward(
    const ttzip_filter_pipeline_t* pipeline,
    const uint8_t* src,
    uint8_t* dst,
    size_t size
);

#ifdef __cplusplus
}
#endif

#endif // CTTZipFilterPipeline_h
