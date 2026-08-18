// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#ifndef CTTZipPluginRegistry_h
#define CTTZipPluginRegistry_h

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

#define TTZIP_FILTER_USER_START 160
#define TTZIP_FILTER_USER_STOP  255
#define TTZIP_USER_PLUGIN_SLOTS (TTZIP_FILTER_USER_STOP - TTZIP_FILTER_USER_START + 1) // 96 slots

typedef int (*ttzip_filter_forward_fn)(const uint8_t* src, uint8_t* dst, size_t size, uint8_t type_size, uint8_t meta);
typedef int (*ttzip_filter_backward_fn)(const uint8_t* src, uint8_t* dst, size_t size, uint8_t type_size, uint8_t meta);

typedef struct {
    uint8_t id;
    const char* name;
    ttzip_filter_forward_fn forward;
    ttzip_filter_backward_fn backward;
} ttzip_filter_plugin_t;

typedef int (*ttzip_codec_encoder_fn)(const uint8_t* src, size_t src_len, uint8_t* dst, size_t dst_cap, size_t* out_len, int level);
typedef int (*ttzip_codec_decoder_fn)(const uint8_t* src, size_t src_len, uint8_t* dst, size_t dst_cap, size_t* out_len);

typedef struct {
    uint8_t id;
    const char* name;
    ttzip_codec_encoder_fn encode;
    ttzip_codec_decoder_fn decode;
} ttzip_codec_plugin_t;

/**
 * @brief Registers a user-defined filter plugin in range [160, 255].
 * @return 0 on success, negative error code on invalid ID or NULL callbacks.
 */
int ttzip_plugin_register_filter(const ttzip_filter_plugin_t* plugin);

/**
 * @brief Registers a user-defined codec plugin in range [160, 255].
 * @return 0 on success, negative error code on invalid ID or NULL callbacks.
 */
int ttzip_plugin_register_codec(const ttzip_codec_plugin_t* plugin);

/**
 * @brief Dispatches filter forward transform with built-in fast path and lock-free plugin table lookup.
 */
int ttzip_plugin_dispatch_filter_forward(
    uint8_t filter_id,
    const uint8_t* src,
    uint8_t* dst,
    size_t size,
    uint8_t type_size,
    uint8_t meta
);

/**
 * @brief Dispatches filter backward transform with built-in fast path and lock-free plugin table lookup.
 */
int ttzip_plugin_dispatch_filter_backward(
    uint8_t filter_id,
    const uint8_t* src,
    uint8_t* dst,
    size_t size,
    uint8_t type_size,
    uint8_t meta
);

#ifdef __cplusplus
}
#endif

#endif /* CTTZipPluginRegistry_h */
