// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#ifndef CTTZipPrefetchPipeline_h
#define CTTZipPrefetchPipeline_h

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>
#include <pthread.h>
#include <stdatomic.h>

#ifdef __cplusplus
extern "C" {
#endif

#define TTZIP_PREFETCH_DEFAULT_SLOTS 2

typedef enum {
    TTZIP_PREFETCH_SLOT_EMPTY     = 0,
    TTZIP_PREFETCH_SLOT_LOADING   = 1,
    TTZIP_PREFETCH_SLOT_READY     = 2,
    TTZIP_PREFETCH_SLOT_CONSUMING = 3
} ttzip_prefetch_slot_state_t;

typedef struct {
    uint8_t* buffer;           // 128-byte cacheline aligned memory buffer
    size_t capacity;           // Capacity in bytes
    size_t valid_bytes;        // Actual byte length stored
    int64_t chunk_index;       // Logical chunk index
    _Atomic ttzip_prefetch_slot_state_t state;
} __attribute__((aligned(64))) ttzip_prefetch_slot_t;

typedef struct {
    ttzip_prefetch_slot_t slots[TTZIP_PREFETCH_DEFAULT_SLOTS];
    pthread_mutex_t lock;
    pthread_cond_t cond_ready;
    pthread_cond_t cond_empty;
    bool is_stopped;
    size_t slot_capacity;
} ttzip_prefetch_pipeline_t;

/**
 * @brief Creates and initializes a double-buffered prefetch pipeline.
 */
ttzip_prefetch_pipeline_t* ttzip_prefetch_create(size_t slot_capacity_bytes);

/**
 * @brief Producer commits freshly loaded/decompressed data into slot for chunk_index.
 */
int ttzip_prefetch_commit_slot(
    ttzip_prefetch_pipeline_t* pipe,
    int64_t chunk_index,
    const uint8_t* data,
    size_t size
);

/**
 * @brief Consumer acquires ready slot for chunk_index (blocks until ready).
 */
int ttzip_prefetch_acquire_slot(
    ttzip_prefetch_pipeline_t* pipe,
    int64_t chunk_index,
    uint8_t** out_buffer,
    size_t* out_size
);

/**
 * @brief Consumer releases slot after consumption, recycling it for prefetch.
 */
void ttzip_prefetch_release_slot(
    ttzip_prefetch_pipeline_t* pipe,
    int64_t chunk_index
);

/**
 * @brief Stops and releases all resources associated with the pipeline.
 */
void ttzip_prefetch_destroy(ttzip_prefetch_pipeline_t* pipe);

#ifdef __cplusplus
}
#endif

#endif // CTTZipPrefetchPipeline_h
