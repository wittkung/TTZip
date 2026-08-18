// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file CTTZipBridge_ZipChunkedStream.h
 * @brief Large-file chunked streaming multithreaded DEFLATE compressor.
 * @details RFC 1951 aligned chunk concatenation with bounded memory pool (<= 64MB RSS).
 */

#ifndef CTTZIP_BRIDGE_ZIP_CHUNKED_STREAM_H
#define CTTZIP_BRIDGE_ZIP_CHUNKED_STREAM_H

#include "CTTZipPlatform.h"
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

#define TTZIP_CHUNK_SIZE_BYTES (1024 * 1024)  /* 1MB */
#define TTZIP_CHUNK_MAX_IN_FLIGHT 32          /* 32 slots -> max 64MB RSS */

typedef struct ttzip_zip_chunked_stream ttzip_zip_chunked_stream_t;

/**
 * @brief Initialize chunked stream compressor.
 * @param out_fd Target output file descriptor with write permission.
 * @param level  Compression level (1..12, default 6).
 * @return Opaque compressor handle, or NULL on failure.
 */
TTZIP_API ttzip_zip_chunked_stream_t* ttzip_zip_chunked_stream_create(int out_fd, int level);

/**
 * @brief Write data chunk into streaming pipeline.
 * @param stream Compressor handle.
 * @param data   Input buffer.
 * @param size   Input size in bytes.
 * @return Bytes written on success, or negative error code on failure.
 */
TTZIP_API int64_t ttzip_zip_chunked_stream_write(ttzip_zip_chunked_stream_t* stream, const void* data, size_t size);

/**
 * @brief Finalize stream and flush all in-flight chunks with DEFLATE termination marker.
 * @param stream               Compressor handle.
 * @param out_total_compressed Optional output pointer for total compressed size.
 * @param out_final_crc32      Optional output pointer for overall CRC-32 checksum.
 * @return 0 on success, negative error code on failure.
 */
TTZIP_API int ttzip_zip_chunked_stream_finish(ttzip_zip_chunked_stream_t* stream, uint64_t* out_total_compressed, uint32_t* out_final_crc32);

/**
 * @brief Destroy compressor handle and free all allocated ring buffers.
 * @param stream Compressor handle.
 */
TTZIP_API void ttzip_zip_chunked_stream_destroy(ttzip_zip_chunked_stream_t* stream);

#ifdef __cplusplus
}
#endif

#endif /* CTTZIP_BRIDGE_ZIP_CHUNKED_STREAM_H */
