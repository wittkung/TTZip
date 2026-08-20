// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/CTTZipTensorSlicing.h"
#include <string.h>

int ttzip_tensor_geom_init(
    ttzip_tensor_geom_t* geom,
    int8_t ndim,
    uint8_t item_size,
    const int64_t* shape,
    const int32_t* chunkshape,
    const int32_t* blockshape
) {
    if (!geom || ndim <= 0 || ndim > TTZIP_TENSOR_MAX_NDIM || item_size == 0) return -1;
    if (!shape || !chunkshape || !blockshape) return -1;

    memset(geom, 0, sizeof(ttzip_tensor_geom_t));
    geom->ndim = ndim;
    geom->item_size = item_size;

    for (int i = 0; i < ndim; i++) {
        if (shape[i] <= 0 || chunkshape[i] <= 0 || blockshape[i] <= 0) return -2;
        geom->shape[i] = shape[i];
        geom->chunkshape[i] = chunkshape[i];
        geom->blockshape[i] = blockshape[i];
    }

    // 1. Chunk plane strides
    int64_t n_chunks[TTZIP_TENSOR_MAX_NDIM];
    for (int i = 0; i < ndim; i++) {
        n_chunks[i] = (shape[i] + chunkshape[i] - 1) / chunkshape[i];
    }
    geom->chunk_strides[ndim - 1] = 1;
    for (int i = ndim - 2; i >= 0; i--) {
        geom->chunk_strides[i] = geom->chunk_strides[i + 1] * n_chunks[i + 1];
    }

    // 2. Block plane strides
    int32_t n_blocks[TTZIP_TENSOR_MAX_NDIM];
    for (int i = 0; i < ndim; i++) {
        n_blocks[i] = (chunkshape[i] + blockshape[i] - 1) / blockshape[i];
    }
    geom->block_strides[ndim - 1] = 1;
    for (int i = ndim - 2; i >= 0; i--) {
        geom->block_strides[i] = geom->block_strides[i + 1] * n_blocks[i + 1];
    }

    // 3. Element plane strides (inside block)
    geom->elem_strides[ndim - 1] = 1;
    for (int i = ndim - 2; i >= 0; i--) {
        geom->elem_strides[i] = geom->elem_strides[i + 1] * blockshape[i + 1];
    }

    return 0;
}

void ttzip_tensor_coord_to_index(
    const ttzip_tensor_geom_t* geom,
    const int64_t* coords,
    int64_t* out_chunk_idx,
    int32_t* out_block_idx,
    size_t* out_elem_byte_offset
) {
    if (!geom || !coords) return;

    int64_t c_idx = 0;
    int32_t b_idx = 0;
    int32_t e_off = 0;

    for (int i = 0; i < geom->ndim; i++) {
        int64_t x = coords[i];
        int64_t c_dim = geom->chunkshape[i];
        int64_t b_dim = geom->blockshape[i];

        int64_t p_c = x / c_dim;
        int64_t rem_c = x % c_dim;
        c_idx += p_c * geom->chunk_strides[i];

        int32_t p_b = (int32_t)(rem_c / b_dim);
        int32_t rem_b = (int32_t)(rem_c % b_dim);
        b_idx += p_b * geom->block_strides[i];

        e_off += rem_b * geom->elem_strides[i];
    }

    if (out_chunk_idx) *out_chunk_idx = c_idx;
    if (out_block_idx) *out_block_idx = b_idx;
    if (out_elem_byte_offset) *out_elem_byte_offset = (size_t)e_off * geom->item_size;
}

static void recursive_slice_copy(
    const ttzip_tensor_geom_t* geom,
    const uint8_t* src,
    uint8_t* dst,
    const ttzip_tensor_slice_req_t* slice,
    int dim,
    int64_t curr_src_offset_elem,
    size_t* dst_offset_bytes,
    size_t dst_capacity_bytes
) {
    int64_t global_stride = 1;
    for (int i = dim + 1; i < geom->ndim; i++) {
        global_stride *= geom->shape[i];
    }

    int64_t start = slice->start[dim];
    int64_t stop = slice->stop[dim];
    int64_t step = slice->step[dim] > 0 ? slice->step[dim] : 1;

    if (dim == geom->ndim - 1) {
        // Inner-most dimension: copy elements
        for (int64_t idx = start; idx < stop; idx += step) {
            if (*dst_offset_bytes + geom->item_size > dst_capacity_bytes) return;
            int64_t src_byte_off = (curr_src_offset_elem + idx) * geom->item_size;
            memcpy(dst + *dst_offset_bytes, src + src_byte_off, geom->item_size);
            *dst_offset_bytes += geom->item_size;
        }
    } else {
        // Outer dimensions: iterate coordinates
        for (int64_t idx = start; idx < stop; idx += step) {
            int64_t next_src_off = curr_src_offset_elem + idx * global_stride;
            recursive_slice_copy(geom, src, dst, slice, dim + 1, next_src_off, dst_offset_bytes, dst_capacity_bytes);
        }
    }
}

int ttzip_tensor_extract_strided_slice(
    const ttzip_tensor_geom_t* geom,
    const uint8_t* src_tensor,
    const ttzip_tensor_slice_req_t* slice,
    uint8_t* dst_slice,
    size_t dst_capacity_bytes,
    size_t* out_extracted_bytes
) {
    if (!geom || !src_tensor || !slice || !dst_slice || dst_capacity_bytes == 0) return -1;

    for (int i = 0; i < geom->ndim; i++) {
        if (slice->start[i] < 0 || slice->stop[i] > geom->shape[i] || slice->start[i] >= slice->stop[i]) {
            return -2;
        }
    }

    size_t written_bytes = 0;
    recursive_slice_copy(geom, src_tensor, dst_slice, slice, 0, 0, &written_bytes, dst_capacity_bytes);

    if (out_extracted_bytes) *out_extracted_bytes = written_bytes;
    return 0;
}

static void iterate_blocks_recursive(
    const ttzip_tensor_geom_t* geom,
    const int64_t* chunk_coord,
    int64_t chunk_idx,
    const int64_t* block_min,
    const int64_t* block_max,
    const int32_t* n_blocks,
    int b_dim,
    int64_t* current_block_coord,
    ttzip_tensor_intersect_block_t* out_blocks,
    size_t max_blocks,
    size_t* count
) {
    int rank = geom->ndim;
    if (b_dim == rank) {
        if (*count >= max_blocks) return;
        ttzip_tensor_intersect_block_t* block = &out_blocks[*count];
        block->chunk_idx = chunk_idx;

        int64_t b_idx = 0;
        int64_t b_stride = 1;
        for (int k = rank - 1; k >= 0; k--) {
            b_idx += current_block_coord[k] * b_stride;
            b_stride *= n_blocks[k];
        }
        block->block_idx_in_chunk = (int32_t)b_idx;

        for (int k = 0; k < rank; k++) {
            block->chunk_coords[k] = chunk_coord[k];
            block->block_coords[k] = current_block_coord[k];
            block->global_start_coords[k] = chunk_coord[k] * geom->chunkshape[k] + current_block_coord[k] * geom->blockshape[k];
        }
        (*count)++;
        return;
    }

    for (int64_t b = block_min[b_dim]; b <= block_max[b_dim]; b++) {
        current_block_coord[b_dim] = b;
        iterate_blocks_recursive(geom, chunk_coord, chunk_idx, block_min, block_max, n_blocks, b_dim + 1, current_block_coord, out_blocks, max_blocks, count);
    }
}

static void iterate_chunks_recursive(
    const ttzip_tensor_geom_t* geom,
    const ttzip_tensor_slice_req_t* slice,
    const int64_t* chunk_min,
    const int64_t* chunk_max,
    const int64_t* n_chunks,
    const int32_t* n_blocks,
    int dim,
    int64_t* current_chunk_coord,
    ttzip_tensor_intersect_block_t* out_blocks,
    size_t max_blocks,
    size_t* count
) {
    int rank = geom->ndim;
    if (dim == rank) {
        // Linear chunk index
        int64_t c_idx = 0;
        int64_t c_stride = 1;
        for (int k = rank - 1; k >= 0; k--) {
            c_idx += current_chunk_coord[k] * c_stride;
            c_stride *= n_chunks[k];
        }

        int64_t block_min[TTZIP_TENSOR_MAX_NDIM];
        int64_t block_max[TTZIP_TENSOR_MAX_NDIM];
        for (int i = 0; i < rank; i++) {
            int64_t chunk_start = current_chunk_coord[i] * geom->chunkshape[i];
            int64_t chunk_end = chunk_start + geom->chunkshape[i];
            if (chunk_end > geom->shape[i]) chunk_end = geom->shape[i];

            int64_t local_start = slice->start[i] > chunk_start ? (slice->start[i] - chunk_start) : 0;
            int64_t local_end = slice->stop[i] < chunk_end ? (slice->stop[i] - chunk_start) : (chunk_end - chunk_start);

            block_min[i] = local_start / geom->blockshape[i];
            block_max[i] = (local_end > 0 ? (local_end - 1) : 0) / geom->blockshape[i];
        }

        int64_t current_block_coord[TTZIP_TENSOR_MAX_NDIM] = {0};
        iterate_blocks_recursive(geom, current_chunk_coord, c_idx, block_min, block_max, n_blocks, 0, current_block_coord, out_blocks, max_blocks, count);
        return;
    }

    for (int64_t c = chunk_min[dim]; c <= chunk_max[dim]; c++) {
        current_chunk_coord[dim] = c;
        iterate_chunks_recursive(geom, slice, chunk_min, chunk_max, n_chunks, n_blocks, dim + 1, current_chunk_coord, out_blocks, max_blocks, count);
    }
}

size_t ttzip_tensor_find_intersecting_blocks(
    const ttzip_tensor_geom_t* geom,
    const ttzip_tensor_slice_req_t* slice,
    ttzip_tensor_intersect_block_t* out_blocks,
    size_t max_blocks
) {
    if (!geom || !slice || !out_blocks || max_blocks == 0) return 0;
    int rank = geom->ndim;
    if (rank <= 0 || rank > TTZIP_TENSOR_MAX_NDIM) return 0;

    int64_t n_chunks[TTZIP_TENSOR_MAX_NDIM];
    int32_t n_blocks[TTZIP_TENSOR_MAX_NDIM];
    int64_t chunk_min[TTZIP_TENSOR_MAX_NDIM];
    int64_t chunk_max[TTZIP_TENSOR_MAX_NDIM];

    for (int i = 0; i < rank; i++) {
        n_chunks[i] = (geom->shape[i] + geom->chunkshape[i] - 1) / geom->chunkshape[i];
        n_blocks[i] = (geom->chunkshape[i] + geom->blockshape[i] - 1) / geom->blockshape[i];

        chunk_min[i] = slice->start[i] / geom->chunkshape[i];
        int64_t max_idx = slice->start[i] > (slice->stop[i] - 1) ? slice->start[i] : (slice->stop[i] - 1);
        chunk_max[i] = max_idx / geom->chunkshape[i];
    }

    size_t count = 0;
    int64_t current_chunk_coord[TTZIP_TENSOR_MAX_NDIM] = {0};
    iterate_chunks_recursive(geom, slice, chunk_min, chunk_max, n_chunks, n_blocks, 0, current_chunk_coord, out_blocks, max_blocks, &count);

    return count;
}

