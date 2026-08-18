// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file CTTZipBridge_LZFSE.h
 * @brief Native Apple LZFSE compression and streaming interfaces.
 */

#ifndef CTTZIP_BRIDGE_LZFSE_H
#define CTTZIP_BRIDGE_LZFSE_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

bool ttzip_lzfse_is_available(void);

size_t ttzip_lzfse_compress(const void* src, size_t src_size, void* dst, size_t dst_capacity);
size_t ttzip_lzfse_decompress(const void* src, size_t src_size, void* dst, size_t dst_capacity);

int ttzip_lzfse_compress_file_stream(const char* src_path, const char* dst_path);
int ttzip_lzfse_decompress_file_stream(const char* src_path, const char* dst_path);

#ifdef __cplusplus
}
#endif

#endif /* CTTZIP_BRIDGE_LZFSE_H */
