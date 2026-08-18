// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#ifndef TTZIP_CONTEXT_POOL_H
#define TTZIP_CONTEXT_POOL_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    void* raw_ptr;
    uint8_t* aligned_ptr;
    size_t capacity;
    size_t in_use;
    bool active;
} ttzip_scratchpad_t;

typedef struct ttzip_context_pool_s {
    size_t worker_count;
    size_t scratchpad_size;
    ttzip_scratchpad_t* scratchpads;
} ttzip_context_pool_t;

/**
 * Creates a thread-local context memory pool allocating 64-byte / 16KB aligned scratchpads.
 */
ttzip_context_pool_t* ttzip_context_pool_create(size_t worker_count, size_t scratchpad_size);

/**
 * Acquires a pre-allocated working scratchpad for worker thread index.
 */
uint8_t* ttzip_context_pool_acquire(ttzip_context_pool_t* pool, size_t worker_id);

/**
 * Releases worker scratchpad back to the pool.
 */
void ttzip_context_pool_release(ttzip_context_pool_t* pool, size_t worker_id);

/**
 * Destroys context pool and frees all aligned memory buffers.
 */
void ttzip_context_pool_destroy(ttzip_context_pool_t* pool);

#ifdef __cplusplus
}
#endif

#endif /* TTZIP_CONTEXT_POOL_H */
