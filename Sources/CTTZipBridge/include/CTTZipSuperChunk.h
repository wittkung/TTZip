// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#ifndef CTTZipSuperChunk_h
#define CTTZipSuperChunk_h

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

#define TTZIP_SUPERCHUNK_MAGIC "TTZIP_SC"
#define TTZIP_SPECIAL_TAG_MSB (1ULL << 63)

typedef struct {
    uint32_t chunk_size;    // 1MB - 32MB
    uint32_t block_size;    // 128KB (Apple Silicon L1D)
    uint8_t typesize;
    uint8_t clevel;
    uint8_t compcode;
    bool use_dict;
} ttzip_schunk_config_t;

typedef struct {
    uint32_t magic;
    uint16_t version;
    uint32_t flags;
    uint32_t typesize;
    uint64_t uncompressed_size;
    uint64_t compressed_size;
    uint32_t chunk_size;
    uint32_t block_size;
    uint32_t nchunks;
    int64_t* coffsets;      // 64-bit chunk offsets table
    size_t coffsets_capacity;
    uint8_t* dict_buffer;
    size_t dict_size;
    void* cdict_handle;     // ZSTD_CDict*
    void* ddict_handle;     // ZSTD_DDict*
} ttzip_schunk_t;

ttzip_schunk_t* ttzip_schunk_create(const ttzip_schunk_config_t* config);
void ttzip_schunk_free(ttzip_schunk_t* schunk);
int ttzip_schunk_train_dict(ttzip_schunk_t* schunk, const void* sample_data, size_t sample_size);
int64_t ttzip_schunk_append_chunk(ttzip_schunk_t* schunk, const void* src, size_t nbytes);
int64_t ttzip_schunk_decompress_chunk(const ttzip_schunk_t* schunk, size_t chunk_idx, void* dst, size_t dst_capacity);

#ifdef __cplusplus
}
#endif

#endif // CTTZipSuperChunk_h
