// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file CTTZipBridge_LZFSE.h
 * @brief Native Apple LZFSE static compression, block decoding, and streaming interfaces.
 */

#ifndef CTTZIP_BRIDGE_LZFSE_H
#define CTTZIP_BRIDGE_LZFSE_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>
#include <sys/types.h>

#ifdef __cplusplus
extern "C" {
#endif

#define TTZIP_LZFSE_MAGIC 0x545A4653 // 'TZFS'

/**
 * @brief Checks if LZFSE engine is available (always true with static compilation).
 */
bool ttzip_lzfse_is_available(void);

/**
 * @brief Compresses a memory buffer using in-process static LZFSE with thread-local scratch.
 */
size_t ttzip_lzfse_compress(const void* src, size_t src_size, void* dst, size_t dst_capacity);

/**
 * @brief Decompresses a memory buffer using in-process static LZFSE with thread-local scratch.
 */
size_t ttzip_lzfse_decompress(const void* src, size_t src_size, void* dst, size_t dst_capacity);

/**
 * @brief Decompresses a single DMG / AAR LZFSE/LZVN block using thread-local scratch.
 */
size_t ttzip_lzfse_decompress_block(const void* src, size_t src_size, void* dst, size_t dst_capacity);

/**
 * @brief Micro-buffering stream compressor for .lzfse files.
 */
int ttzip_lzfse_compress_file_stream(const char* src_path, const char* dst_path);

/**
 * @brief Micro-buffering stream decompressor for .lzfse files.
 */
int ttzip_lzfse_decompress_file_stream(const char* src_path, const char* dst_path);

#ifdef __cplusplus
}
#endif

#endif /* CTTZIP_BRIDGE_LZFSE_H */
