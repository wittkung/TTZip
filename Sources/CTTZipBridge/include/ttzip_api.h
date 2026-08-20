// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine.

/**
 * @file ttzip_api.h
 * @brief TTZip Public C ABI Specification (Version 1.0.0).
 * @details Zero-dependency, pure C11 cross-platform API for compression, hashing, threadpooling, and container framing.
 */

#ifndef TTZIP_API_H
#define TTZIP_API_H

#include "ttzip_platform.h"
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

#define TTZIP_VERSION_MAJOR 1
#define TTZIP_VERSION_MINOR 0
#define TTZIP_VERSION_PATCH 0
#define TTZIP_VERSION_STRING "1.0.0"

typedef enum ttzip_api_codec {
    TTZIP_API_CODEC_STORE    = 0,
    TTZIP_API_CODEC_DEFLATE  = 1,
    TTZIP_API_CODEC_ZSTD     = 2,
    TTZIP_API_CODEC_LZMA2    = 3,
    TTZIP_API_CODEC_LZFSE    = 4,
    TTZIP_API_CODEC_SNAPPY   = 5,
    TTZIP_API_CODEC_ZOPFLI   = 6,
    TTZIP_API_CODEC_BLOSC2   = 7
} ttzip_api_codec_t;

typedef enum ttzip_api_status {
    TTZIP_API_OK                    = 0,
    TTZIP_API_ERR_INVALID_PARAM     = -1,
    TTZIP_API_ERR_BUFFER_TOO_SMALL  = -2,
    TTZIP_API_ERR_CORRUPT_DATA      = -3,
    TTZIP_API_ERR_OUT_OF_MEMORY     = -4,
    TTZIP_API_ERR_UNSUPPORTED_CODEC = -5,
    TTZIP_API_ERR_IO_FAILURE        = -6
} ttzip_api_status_t;

#include "ttzip_threadpool.h"
#include "ttzip_thread_budget.h"
#include "ttzip_mem_budget.h"
#include "ttzip_fs.h"
#include "ttzip_crc64.h"
#include "ttzip_container_fast.h"
#include "ttzip_zip_container.h"
#include "ttzip_tar_container.h"
#include "ttzip_7z_container.h"
#include "ttzip_magic_sniff.h"
#include "ttzip_strnatcmp.h"
#include "ttzip_archive_tree.h"
#include "ttzip_split.h"
#include "ttzip_inplace.h"
#include "ttzip_security.h"
#include "ttzip_archive.h"

/**
 * @brief Returns semantic version integer (e.g. 0x010000 for 1.0.0).
 */
TTZIP_API uint32_t ttzip_version_number(void);

/**
 * @brief Returns semantic version string ("1.0.0").
 */
TTZIP_API const char *ttzip_version_string(void);

/**
 * @brief Calculates the maximum upper-bound compressed size for a given input size and codec.
 */
TTZIP_API size_t ttzip_compress_bound(ttzip_api_codec_t codec, size_t in_size);

/**
 * @brief Compresses an in-memory buffer using the specified codec and compression level.
 * @return Compressed byte count, or 0 on error.
 */
TTZIP_API size_t ttzip_compress_buffer(
    ttzip_api_codec_t codec,
    const void *src,
    size_t src_len,
    void *dst,
    size_t dst_cap,
    int level
);

/**
 * @brief Decompresses an in-memory buffer using the specified codec.
 * @return Decompressed byte count, or 0 on error.
 */
TTZIP_API size_t ttzip_decompress_buffer(
    ttzip_api_codec_t codec,
    const void *src,
    size_t src_len,
    void *dst,
    size_t dst_cap
);

#ifdef __cplusplus
}
#endif

#endif /* TTZIP_API_H */
