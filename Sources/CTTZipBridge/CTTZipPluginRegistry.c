// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/CTTZipPluginRegistry.h"
#include "include/CTTZipFilterPipeline.h"
#include "include/CTTZipBitGroom.h"
#include <stdatomic.h>
#include <pthread.h>
#include <string.h>

// Static BSS storage: zero heap allocation at runtime
static _Atomic(const ttzip_filter_plugin_t*) g_user_filter_registry[TTZIP_USER_PLUGIN_SLOTS];
static _Atomic(const ttzip_codec_plugin_t*)  g_user_codec_registry[TTZIP_USER_PLUGIN_SLOTS];
static pthread_mutex_t g_registry_mutex = PTHREAD_MUTEX_INITIALIZER;

int ttzip_plugin_register_filter(const ttzip_filter_plugin_t* plugin) {
    if (!plugin || plugin->id < TTZIP_FILTER_USER_START || plugin->id > TTZIP_FILTER_USER_STOP) {
        return -1;
    }
    if (!plugin->forward || !plugin->backward) {
        return -2;
    }

    uint8_t index = plugin->id - TTZIP_FILTER_USER_START;
    pthread_mutex_lock(&g_registry_mutex);
    atomic_store_explicit(&g_user_filter_registry[index], plugin, memory_order_release);
    pthread_mutex_unlock(&g_registry_mutex);
    return 0;
}

int ttzip_plugin_register_codec(const ttzip_codec_plugin_t* plugin) {
    if (!plugin || plugin->id < TTZIP_FILTER_USER_START || plugin->id > TTZIP_FILTER_USER_STOP) {
        return -1;
    }
    if (!plugin->encode || !plugin->decode) {
        return -2;
    }

    uint8_t index = plugin->id - TTZIP_FILTER_USER_START;
    pthread_mutex_lock(&g_registry_mutex);
    atomic_store_explicit(&g_user_codec_registry[index], plugin, memory_order_release);
    pthread_mutex_unlock(&g_registry_mutex);
    return 0;
}

int ttzip_plugin_invoke_filter_forward(
    uint8_t filter_id,
    const uint8_t* src,
    uint8_t* dst,
    size_t size,
    uint8_t type_size,
    uint8_t meta
) {
    // 1. Built-in fast path (Zero indirect jump overhead)
    switch (filter_id) {
        case TTZIP_FILTER_NONE:
            if (src != dst) memcpy(dst, src, size);
            return 0;
        case TTZIP_FILTER_SHUFFLE:
            ttzip_filter_shuffle_forward(src, dst, size, type_size);
            return 0;
        case TTZIP_FILTER_BITSHUFFLE:
            ttzip_filter_bitshuffle_forward_neon(src, dst, size, type_size);
            return 0;
        case TTZIP_FILTER_DELTA:
            ttzip_filter_bytedelta_forward_neon(src, dst, size, type_size);
            return 0;
        case TTZIP_FILTER_TRUNCATE_FLOAT32:
            ttzip_filter_truncate_float32_neon((const float*)src, (float*)dst, size / sizeof(float), meta > 0 ? meta : 7);
            return 0;
        case TTZIP_FILTER_TRUNCATE_FLOAT64:
            ttzip_filter_truncate_float64_neon((const double*)src, (double*)dst, size / sizeof(double), meta > 0 ? meta : 14);
            return 0;
        default:
            break;
    }

    // 2. User-Defined Plugin Range Check (160..255)
    if (__builtin_expect(filter_id >= TTZIP_FILTER_USER_START && filter_id <= TTZIP_FILTER_USER_STOP, 0)) {
        uint8_t index = filter_id - TTZIP_FILTER_USER_START;
        const ttzip_filter_plugin_t* p = atomic_load_explicit(&g_user_filter_registry[index], memory_order_acquire);
        if (__builtin_expect(p != NULL && p->forward != NULL, 1)) {
            return p->forward(src, dst, size, type_size, meta);
        }
    }

    return -1; // Unregistered filter ID
}

int ttzip_plugin_invoke_filter_backward(
    uint8_t filter_id,
    const uint8_t* src,
    uint8_t* dst,
    size_t size,
    uint8_t type_size,
    uint8_t meta
) {
    // 1. Built-in fast path
    switch (filter_id) {
        case TTZIP_FILTER_NONE:
            if (src != dst) memcpy(dst, src, size);
            return 0;
        case TTZIP_FILTER_SHUFFLE:
            ttzip_filter_shuffle_backward(src, dst, size, type_size);
            return 0;
        case TTZIP_FILTER_BITSHUFFLE:
            ttzip_filter_bitshuffle_backward_neon(src, dst, size, type_size);
            return 0;
        case TTZIP_FILTER_DELTA:
            ttzip_filter_bytedelta_backward_neon(src, dst, size, type_size);
            return 0;
        case TTZIP_FILTER_TRUNCATE_FLOAT32:
        case TTZIP_FILTER_TRUNCATE_FLOAT64:
            if (src != dst) memcpy(dst, src, size);
            return 0;
        default:
            break;
    }

    // 2. User-Defined Plugin Range Check (160..255)
    if (__builtin_expect(filter_id >= TTZIP_FILTER_USER_START && filter_id <= TTZIP_FILTER_USER_STOP, 0)) {
        uint8_t index = filter_id - TTZIP_FILTER_USER_START;
        const ttzip_filter_plugin_t* p = atomic_load_explicit(&g_user_filter_registry[index], memory_order_acquire);
        if (__builtin_expect(p != NULL && p->backward != NULL, 1)) {
            return p->backward(src, dst, size, type_size, meta);
        }
    }

    return -1; // Unregistered filter ID
}

int ttzip_plugin_dispatch_filter_forward(
    uint8_t filter_id,
    const uint8_t* src,
    uint8_t* dst,
    size_t size,
    uint8_t type_size,
    uint8_t meta
) {
    return ttzip_plugin_invoke_filter_forward(filter_id, src, dst, size, type_size, meta);
}

int ttzip_plugin_dispatch_filter_backward(
    uint8_t filter_id,
    const uint8_t* src,
    uint8_t* dst,
    size_t size,
    uint8_t type_size,
    uint8_t meta
) {
    return ttzip_plugin_invoke_filter_backward(filter_id, src, dst, size, type_size, meta);
}
