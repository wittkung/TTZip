// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/ttzip_context_pool.h"
#include <stdlib.h>
#include <string.h>

#define TTZIP_POOL_ALIGNMENT 64

ttzip_context_pool_t* ttzip_context_pool_create(size_t worker_count, size_t scratchpad_size) {
    if (worker_count == 0 || scratchpad_size == 0) return NULL;

    ttzip_context_pool_t* pool = (ttzip_context_pool_t*)calloc(1, sizeof(ttzip_context_pool_t));
    if (!pool) return NULL;

    pool->worker_count = worker_count;
    pool->scratchpad_size = scratchpad_size;
    pool->scratchpads = (ttzip_scratchpad_t*)calloc(worker_count, sizeof(ttzip_scratchpad_t));
    if (!pool->scratchpads) {
        free(pool);
        return NULL;
    }

    for (size_t i = 0; i < worker_count; i++) {
        void* ptr = NULL;
        if (posix_memalign(&ptr, TTZIP_POOL_ALIGNMENT, scratchpad_size) == 0 && ptr) {
            pool->scratchpads[i].raw_ptr = ptr;
            pool->scratchpads[i].aligned_ptr = (uint8_t*)ptr;
            pool->scratchpads[i].capacity = scratchpad_size;
            pool->scratchpads[i].in_use = 0;
            pool->scratchpads[i].active = false;
        } else {
            ttzip_context_pool_destroy(pool);
            return NULL;
        }
    }

    return pool;
}

uint8_t* ttzip_context_pool_acquire(ttzip_context_pool_t* pool, size_t worker_id) {
    if (!pool || worker_id >= pool->worker_count) return NULL;
    ttzip_scratchpad_t* sp = &pool->scratchpads[worker_id];
    sp->active = true;
    sp->in_use = 0;
    return sp->aligned_ptr;
}

void ttzip_context_pool_release(ttzip_context_pool_t* pool, size_t worker_id) {
    if (!pool || worker_id >= pool->worker_count) return;
    pool->scratchpads[worker_id].active = false;
    pool->scratchpads[worker_id].in_use = 0;
}

void ttzip_context_pool_destroy(ttzip_context_pool_t* pool) {
    if (!pool) return;
    if (pool->scratchpads) {
        for (size_t i = 0; i < pool->worker_count; i++) {
            if (pool->scratchpads[i].raw_ptr) {
                free(pool->scratchpads[i].raw_ptr);
            }
        }
        free(pool->scratchpads);
    }
    free(pool);
}
