// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#ifndef CTTZipTensorSlicing_h
#define CTTZipTensorSlicing_h

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>
#include "ttzip_platform.h"

#ifdef __cplusplus
extern "C" {
#endif

#define TTZIP_TENSOR_MAX_NDIM 8

typedef struct {
    int8_t ndim;                                // Number of dimensions (1..8)
    uint8_t item_size;                          // Element byte size (1, 2, 4, 8, 16)
    int64_t shape[TTZIP_TENSOR_MAX_NDIM];       // Full array dimension lengths
    int32_t chunkshape[TTZIP_TENSOR_MAX_NDIM];  // Chunk dimension lengths
    int32_t blockshape[TTZIP_TENSOR_MAX_NDIM];  // Block dimension lengths
    int64_t chunk_strides[TTZIP_TENSOR_MAX_NDIM];
    int32_t block_strides[TTZIP_TENSOR_MAX_NDIM];
    int32_t elem_strides[TTZIP_TENSOR_MAX_NDIM];
} ttzip_tensor_geom_t;

typedef struct {
    int64_t start[TTZIP_TENSOR_MAX_NDIM];
    int64_t stop[TTZIP_TENSOR_MAX_NDIM];
    int64_t step[TTZIP_TENSOR_MAX_NDIM];
} ttzip_tensor_slice_req_t;

/**
 * @brief Computes row-major linear strides across Chunk, Block, and Element planes.
 */
int ttzip_tensor_geom_init(
    ttzip_tensor_geom_t* geom,
    int8_t ndim,
    uint8_t item_size,
    const int64_t* shape,
    const int32_t* chunkshape,
    const int32_t* blockshape
);

/**
 * @brief Translates global N-dimensional coordinates X to (Chunk Index, Block Index, Element Byte Offset).
 */
void ttzip_tensor_coord_to_index(
    const ttzip_tensor_geom_t* geom,
    const int64_t* coords,
    int64_t* out_chunk_idx,
    int32_t* out_block_idx,
    size_t* out_elem_byte_offset
);

/**
 * @brief Extracts an arbitrary strided slice from a contiguous tensor memory buffer into dst_slice.
 */
int ttzip_tensor_extract_strided_slice(
    const ttzip_tensor_geom_t* geom,
    const uint8_t* src_tensor,
    const ttzip_tensor_slice_req_t* slice,
    uint8_t* dst_slice,
    size_t dst_capacity_bytes,
    size_t* out_extracted_bytes
);

typedef struct {
    int64_t chunk_idx;
    int32_t block_idx_in_chunk;
    int64_t chunk_coords[TTZIP_TENSOR_MAX_NDIM];
    int64_t block_coords[TTZIP_TENSOR_MAX_NDIM];
    int64_t global_start_coords[TTZIP_TENSOR_MAX_NDIM];
} ttzip_tensor_intersect_block_t;

/**
 * @brief Enumerates all intersecting atomic micro-blocks for an N-dimensional bounding box slice.
 */
TTZIP_API size_t ttzip_tensor_find_intersecting_blocks(
    const ttzip_tensor_geom_t* geom,
    const ttzip_tensor_slice_req_t* slice,
    ttzip_tensor_intersect_block_t* out_blocks,
    size_t max_blocks
);

#ifdef __cplusplus
}
#endif

#endif // CTTZipTensorSlicing_h
