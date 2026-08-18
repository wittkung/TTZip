// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/CTTZipPrefetchPipeline.h"
#include "include/CTTZipSysAlloc.h"
#include <stdlib.h>
#include <string.h>

ttzip_prefetch_pipeline_t* ttzip_prefetch_create(size_t slot_capacity_bytes) {
    if (slot_capacity_bytes == 0) slot_capacity_bytes = 8 * 1024 * 1024; // 8MB default

    ttzip_prefetch_pipeline_t* pipe = (ttzip_prefetch_pipeline_t*)calloc(1, sizeof(ttzip_prefetch_pipeline_t));
    if (!pipe) return NULL;

    pipe->slot_capacity = slot_capacity_bytes;
    pthread_mutex_init(&pipe->lock, NULL);
    pthread_cond_init(&pipe->cond_ready, NULL);
    pthread_cond_init(&pipe->cond_empty, NULL);
    pipe->is_stopped = false;

    for (int i = 0; i < TTZIP_PREFETCH_DEFAULT_SLOTS; i++) {
        pipe->slots[i].capacity = slot_capacity_bytes;
        pipe->slots[i].buffer = (uint8_t*)ttzip_core_aligned_alloc_128b(slot_capacity_bytes);
        pipe->slots[i].valid_bytes = 0;
        pipe->slots[i].chunk_index = -1;
        atomic_store_explicit(&pipe->slots[i].state, TTZIP_PREFETCH_SLOT_EMPTY, memory_order_relaxed);
    }

    return pipe;
}

int ttzip_prefetch_commit_slot(
    ttzip_prefetch_pipeline_t* pipe,
    int64_t chunk_index,
    const uint8_t* data,
    size_t size
) {
    if (!pipe || !data || size == 0) return -1;

    int slot_idx = (int)(chunk_index % TTZIP_PREFETCH_DEFAULT_SLOTS);
    if (slot_idx < 0) slot_idx = -slot_idx;
    ttzip_prefetch_slot_t* slot = &pipe->slots[slot_idx];

    pthread_mutex_lock(&pipe->lock);
    while (atomic_load_explicit(&slot->state, memory_order_acquire) != TTZIP_PREFETCH_SLOT_EMPTY && !pipe->is_stopped) {
        pthread_cond_wait(&pipe->cond_empty, &pipe->lock);
    }

    if (pipe->is_stopped) {
        pthread_mutex_unlock(&pipe->lock);
        return -2;
    }

    atomic_store_explicit(&slot->state, TTZIP_PREFETCH_SLOT_LOADING, memory_order_release);

    size_t copy_len = (size <= slot->capacity) ? size : slot->capacity;
    memcpy(slot->buffer, data, copy_len);
    slot->valid_bytes = copy_len;
    slot->chunk_index = chunk_index;

    atomic_store_explicit(&slot->state, TTZIP_PREFETCH_SLOT_READY, memory_order_release);
    pthread_cond_broadcast(&pipe->cond_ready);
    pthread_mutex_unlock(&pipe->lock);

    return 0;
}

int ttzip_prefetch_acquire_slot(
    ttzip_prefetch_pipeline_t* pipe,
    int64_t chunk_index,
    uint8_t** out_buffer,
    size_t* out_size
) {
    if (!pipe || !out_buffer || !out_size) return -1;

    int slot_idx = (int)(chunk_index % TTZIP_PREFETCH_DEFAULT_SLOTS);
    if (slot_idx < 0) slot_idx = -slot_idx;
    ttzip_prefetch_slot_t* slot = &pipe->slots[slot_idx];

    pthread_mutex_lock(&pipe->lock);
    while (atomic_load_explicit(&slot->state, memory_order_acquire) != TTZIP_PREFETCH_SLOT_READY && !pipe->is_stopped) {
        pthread_cond_wait(&pipe->cond_ready, &pipe->lock);
    }

    if (pipe->is_stopped) {
        pthread_mutex_unlock(&pipe->lock);
        return -2;
    }

    atomic_store_explicit(&slot->state, TTZIP_PREFETCH_SLOT_CONSUMING, memory_order_release);
    *out_buffer = slot->buffer;
    *out_size = slot->valid_bytes;
    pthread_mutex_unlock(&pipe->lock);

    return 0;
}

void ttzip_prefetch_release_slot(
    ttzip_prefetch_pipeline_t* pipe,
    int64_t chunk_index
) {
    if (!pipe) return;

    int slot_idx = (int)(chunk_index % TTZIP_PREFETCH_DEFAULT_SLOTS);
    if (slot_idx < 0) slot_idx = -slot_idx;
    ttzip_prefetch_slot_t* slot = &pipe->slots[slot_idx];

    pthread_mutex_lock(&pipe->lock);
    atomic_store_explicit(&slot->state, TTZIP_PREFETCH_SLOT_EMPTY, memory_order_release);
    slot->valid_bytes = 0;
    slot->chunk_index = -1;
    pthread_cond_broadcast(&pipe->cond_empty);
    pthread_mutex_unlock(&pipe->lock);
}

void ttzip_prefetch_destroy(ttzip_prefetch_pipeline_t* pipe) {
    if (!pipe) return;

    pthread_mutex_lock(&pipe->lock);
    pipe->is_stopped = true;
    pthread_cond_broadcast(&pipe->cond_ready);
    pthread_cond_broadcast(&pipe->cond_empty);
    pthread_mutex_unlock(&pipe->lock);

    for (int i = 0; i < TTZIP_PREFETCH_DEFAULT_SLOTS; i++) {
        if (pipe->slots[i].buffer) {
            ttzip_core_aligned_free_128b(pipe->slots[i].buffer);
            pipe->slots[i].buffer = NULL;
        }
    }

    pthread_mutex_destroy(&pipe->lock);
    pthread_cond_destroy(&pipe->cond_ready);
    pthread_cond_destroy(&pipe->cond_empty);
    free(pipe);
}
