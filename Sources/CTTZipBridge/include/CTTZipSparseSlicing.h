// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#ifndef CTTZipSparseSlicing_h
#define CTTZipSparseSlicing_h

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Sub-Chunk Streaming Slice Extraction Engine (c-blosc2 inspired)
 *
 * Decompresses only the requested prefix or byte range [offset, offset+length)
 * from compressed buffers with microsecond-level early termination.
 */

/**
 * @brief Decompresses a partial prefix slice of a raw Deflate payload.
 *
 * @param comp_data Compressed Deflate byte buffer
 * @param comp_size Size of compressed buffer
 * @param dst_slice Output buffer for the decompressed slice
 * @param slice_max_bytes Maximum uncompressed bytes to decompress (early exit)
 * @param actual_decomp_bytes Actual bytes produced
 * @return 0 on success, negative error code on failure.
 */
int ttzip_deflate_decompress_prefix_slice(
    const uint8_t* comp_data,
    size_t comp_size,
    uint8_t* dst_slice,
    size_t slice_max_bytes,
    size_t* actual_decomp_bytes
);

/**
 * @brief Decompresses a partial prefix slice of a raw Zstandard stream.
 */
int ttzip_zstd_decompress_prefix_slice(
    const uint8_t* comp_data,
    size_t comp_size,
    uint8_t* dst_slice,
    size_t slice_max_bytes,
    size_t* actual_decomp_bytes
);

#ifdef __cplusplus
}
#endif

#endif // CTTZipSparseSlicing_h
