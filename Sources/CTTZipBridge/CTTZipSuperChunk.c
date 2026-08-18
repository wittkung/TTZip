// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/CTTZipSuperChunk.h"
#include "include/CTTZipQuantumPipeline.h"
#include "include/CTTZipSIMD.h"
#include "include/CTTZipUtils.h"
#include <stdlib.h>
#include <string.h>
#include <zstd.h>

typedef struct {
    uint8_t* data;
    size_t size;
    size_t capacity;
} ttzip_payload_arena_t;

typedef struct {
    ttzip_schunk_t base;
    ttzip_payload_arena_t payload_arena;
    ZSTD_CCtx* cctx;
    ZSTD_DCtx* dctx;
} ttzip_schunk_internal_t;

ttzip_schunk_t* ttzip_schunk_create(const ttzip_schunk_config_t* config) {
    ttzip_schunk_internal_t* impl = (ttzip_schunk_internal_t*)calloc(1, sizeof(ttzip_schunk_internal_t));
    if (!impl) return NULL;

    impl->base.magic = 0x54545343; // 'TTSC'
    impl->base.version = 1;
    impl->base.typesize = config ? (config->typesize > 0 ? config->typesize : 1) : 1;
    impl->base.chunk_size = config ? (config->chunk_size > 0 ? config->chunk_size : 2 * 1024 * 1024) : 2 * 1024 * 1024;
    impl->base.block_size = (uint32_t)ttzip_cache_get_optimal_block_size(); // 128KB for Apple Silicon
    impl->base.coffsets_capacity = 64;
    impl->base.coffsets = (int64_t*)malloc(impl->base.coffsets_capacity * sizeof(int64_t));

    impl->payload_arena.capacity = 4 * 1024 * 1024;
    impl->payload_arena.data = (uint8_t*)malloc(impl->payload_arena.capacity);
    impl->payload_arena.size = 0;

    impl->cctx = ZSTD_createCCtx();
    impl->dctx = ZSTD_createDCtx();

    if (!impl->base.coffsets || !impl->payload_arena.data || !impl->cctx || !impl->dctx) {
        ttzip_schunk_free(&impl->base);
        return NULL;
    }

    return &impl->base;
}

void ttzip_schunk_free(ttzip_schunk_t* schunk) {
    if (!schunk) return;
    ttzip_schunk_internal_t* impl = (ttzip_schunk_internal_t*)schunk;

    if (impl->base.coffsets) {
        free(impl->base.coffsets);
        impl->base.coffsets = NULL;
    }
    if (impl->payload_arena.data) {
        free(impl->payload_arena.data);
        impl->payload_arena.data = NULL;
    }
    if (impl->base.dict_buffer) {
        free(impl->base.dict_buffer);
        impl->base.dict_buffer = NULL;
    }
    if (impl->base.cdict_handle) {
        ZSTD_freeCDict((ZSTD_CDict*)impl->base.cdict_handle);
        impl->base.cdict_handle = NULL;
    }
    if (impl->base.ddict_handle) {
        ZSTD_freeDDict((ZSTD_DDict*)impl->base.ddict_handle);
        impl->base.ddict_handle = NULL;
    }
    if (impl->cctx) {
        ZSTD_freeCCtx(impl->cctx);
        impl->cctx = NULL;
    }
    if (impl->dctx) {
        ZSTD_freeDCtx(impl->dctx);
        impl->dctx = NULL;
    }
    free(impl);
}

int ttzip_schunk_train_dict(ttzip_schunk_t* schunk, const void* sample_data, size_t sample_size) {
    if (!schunk || !sample_data || sample_size == 0) return -1;
    ttzip_schunk_internal_t* impl = (ttzip_schunk_internal_t*)schunk;

    size_t dict_capacity = sample_size > 112 * 1024 ? 112 * 1024 : sample_size;
    if (impl->base.dict_buffer) free(impl->base.dict_buffer);
    if (impl->base.cdict_handle) ZSTD_freeCDict((ZSTD_CDict*)impl->base.cdict_handle);
    if (impl->base.ddict_handle) ZSTD_freeDDict((ZSTD_DDict*)impl->base.ddict_handle);

    impl->base.dict_buffer = (uint8_t*)malloc(dict_capacity);
    if (!impl->base.dict_buffer) return -1;

    // Use sample prefix as training dictionary
    memcpy(impl->base.dict_buffer, sample_data, dict_capacity);
    impl->base.dict_size = dict_capacity;

    impl->base.cdict_handle = ZSTD_createCDict(impl->base.dict_buffer, impl->base.dict_size, 3);
    impl->base.ddict_handle = ZSTD_createDDict(impl->base.dict_buffer, impl->base.dict_size);

    if (!impl->base.cdict_handle || !impl->base.ddict_handle) return -1;
    impl->base.flags |= 0x01; // shared dict active
    return 0;
}

int64_t ttzip_schunk_append_chunk(ttzip_schunk_t* schunk, const void* src, size_t nbytes) {
    if (!schunk || !src || nbytes == 0) return -1;
    ttzip_schunk_internal_t* impl = (ttzip_schunk_internal_t*)schunk;

    // 1. Expand offset table capacity if needed
    if (impl->base.nchunks >= impl->base.coffsets_capacity) {
        size_t new_cap = impl->base.coffsets_capacity * 2;
        int64_t* new_offsets = (int64_t*)realloc(impl->base.coffsets, new_cap * sizeof(int64_t));
        if (!new_offsets) return -1;
        impl->base.coffsets = new_offsets;
        impl->base.coffsets_capacity = new_cap;
    }

    // 2. Check for special value uniform chunk
    ttzip_special_desc_t special = ttzip_detect_uniform_block(src, nbytes, (uint8_t)impl->base.typesize);
    if (special.is_uniform) {
        // Encode special value directly in MSB tagged offset (0 payload bytes stored)
        int64_t offset_tag = (int64_t)(TTZIP_SPECIAL_TAG_MSB | ((uint64_t)special.special_code << 56) | (special.repeat_pattern & 0x00FFFFFFFFFFFFFFULL));
        impl->base.coffsets[impl->base.nchunks++] = offset_tag;
        impl->base.uncompressed_size += nbytes;
        return 0;
    }

    // 3. Normal compression into payload arena
    size_t max_dst = ZSTD_compressBound(nbytes);
    if (impl->payload_arena.size + max_dst > impl->payload_arena.capacity) {
        size_t new_cap = impl->payload_arena.capacity * 2 + max_dst;
        uint8_t* new_data = (uint8_t*)realloc(impl->payload_arena.data, new_cap);
        if (!new_data) return -1;
        impl->payload_arena.data = new_data;
        impl->payload_arena.capacity = new_cap;
    }

    uint8_t* dst_ptr = impl->payload_arena.data + impl->payload_arena.size;
    size_t csize = 0;

    if (impl->base.cdict_handle) {
        csize = ZSTD_compress_usingCDict(impl->cctx, dst_ptr, max_dst, src, nbytes, (const ZSTD_CDict*)impl->base.cdict_handle);
    } else {
        csize = ZSTD_compressCCtx(impl->cctx, dst_ptr, max_dst, src, nbytes, 3);
    }

    if (ZSTD_isError(csize)) return -1;

    int64_t chunk_offset = (int64_t)impl->payload_arena.size;
    impl->base.coffsets[impl->base.nchunks++] = chunk_offset;
    impl->payload_arena.size += csize;
    impl->base.compressed_size += csize;
    impl->base.uncompressed_size += nbytes;

    return (int64_t)csize;
}

int64_t ttzip_schunk_decompress_chunk(const ttzip_schunk_t* schunk, size_t chunk_idx, void* dst, size_t dst_capacity) {
    if (!schunk || !dst || chunk_idx >= schunk->nchunks) return -1;
    const ttzip_schunk_internal_t* impl = (const ttzip_schunk_internal_t*)schunk;

    int64_t offset_entry = impl->base.coffsets[chunk_idx];

    // 1. Check special value MSB tag
    if (offset_entry < 0 || ((uint64_t)offset_entry & TTZIP_SPECIAL_TAG_MSB) != 0) {
        uint64_t u_entry = (uint64_t)offset_entry;
        uint8_t code = (uint8_t)((u_entry >> 56) & 0x7F);
        uint64_t pattern = u_entry & 0x00FFFFFFFFFFFFFFULL;

        ttzip_special_desc_t desc;
        desc.is_uniform = true;
        desc.special_code = (ttzip_special_value_t)code;
        desc.repeat_pattern = pattern;
        desc.uncompressed_size = dst_capacity;

        size_t filled = ttzip_fill_special_value(dst, dst_capacity, desc);
        return (int64_t)filled;
    }

    // 2. Normal decompression from payload arena
    size_t chunk_offset = (size_t)offset_entry;
    if (chunk_offset >= impl->payload_arena.size) return -1;

    const uint8_t* src_ptr = impl->payload_arena.data + chunk_offset;
    size_t available_cbytes = impl->payload_arena.size - chunk_offset;

    size_t dsize = 0;
    if (impl->base.ddict_handle) {
        dsize = ZSTD_decompress_usingDDict(impl->dctx, dst, dst_capacity, src_ptr, available_cbytes, (const ZSTD_DDict*)impl->base.ddict_handle);
    } else {
        dsize = ZSTD_decompressDCtx(impl->dctx, dst, dst_capacity, src_ptr, available_cbytes);
    }

    if (ZSTD_isError(dsize)) return -1;
    return (int64_t)dsize;
}
