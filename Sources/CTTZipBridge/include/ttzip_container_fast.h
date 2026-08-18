// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_container_fast.h
 * @brief Zero-Overhead RFC 1950 (ZLIB) and RFC 1952 (GZIP) Container Framing & Decompression.
 * @details Direct in-place framing with fused hardware-vectorized CRC-32 and Adler-32 checksums.
 */

#ifndef TTZIP_CONTAINER_FAST_H
#define TTZIP_CONTAINER_FAST_H

#include "ttzip_platform.h"
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

#define TTZIP_GZIP_MIN_OVERHEAD 18
#define TTZIP_ZLIB_MIN_OVERHEAD 6

TTZIP_API size_t ttzip_gzip_compress_bound(size_t in_nbytes);
TTZIP_API size_t ttzip_zlib_compress_bound(size_t in_nbytes);

TTZIP_API size_t ttzip_gzip_compress_fast(
    const void *in,
    size_t in_nbytes,
    void *out,
    size_t out_nbytes_avail,
    int level
);

TTZIP_API size_t ttzip_gzip_decompress_fast(
    const void *in,
    size_t in_nbytes,
    void *out,
    size_t out_nbytes_avail
);

TTZIP_API size_t ttzip_zlib_compress_fast(
    const void *in,
    size_t in_nbytes,
    void *out,
    size_t out_nbytes_avail,
    int level
);

TTZIP_API size_t ttzip_zlib_decompress_fast(
    const void *in,
    size_t in_nbytes,
    void *out,
    size_t out_nbytes_avail
);

#ifdef __cplusplus
}
#endif

#endif /* TTZIP_CONTAINER_FAST_H */
