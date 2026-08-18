// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/CTTZipSparseSlicing.h"
#include <zlib.h>
#include <zstd.h>
#include <string.h>

int ttzip_deflate_decompress_prefix_slice(
    const uint8_t* comp_data,
    size_t comp_size,
    uint8_t* dst_slice,
    size_t slice_max_bytes,
    size_t* actual_decomp_bytes
) {
    if (!comp_data || comp_size == 0 || !dst_slice || slice_max_bytes == 0) return -1;
    if (actual_decomp_bytes) *actual_decomp_bytes = 0;

    z_stream strm;
    memset(&strm, 0, sizeof(strm));
    strm.next_in = (Bytef*)comp_data;
    strm.avail_in = (uInt)comp_size;
    strm.next_out = (Bytef*)dst_slice;
    strm.avail_out = (uInt)slice_max_bytes;

    // -MAX_WBITS for raw deflate
    if (inflateInit2(&strm, -MAX_WBITS) != Z_OK) {
        // Fallback for zlib header
        if (inflateInit2(&strm, MAX_WBITS + 32) != Z_OK) {
            return -2;
        }
    }

    int ret = inflate(&strm, Z_SYNC_FLUSH);
    size_t produced = slice_max_bytes - strm.avail_out;
    inflateEnd(&strm);

    if (produced > 0 || ret == Z_STREAM_END || ret == Z_OK || ret == Z_BUF_ERROR) {
        if (actual_decomp_bytes) *actual_decomp_bytes = produced;
        return 0;
    }

    return -3;
}

int ttzip_zstd_decompress_prefix_slice(
    const uint8_t* comp_data,
    size_t comp_size,
    uint8_t* dst_slice,
    size_t slice_max_bytes,
    size_t* actual_decomp_bytes
) {
    if (!comp_data || comp_size == 0 || !dst_slice || slice_max_bytes == 0) return -1;
    if (actual_decomp_bytes) *actual_decomp_bytes = 0;

    ZSTD_DCtx* dctx = ZSTD_createDCtx();
    if (!dctx) return -2;

    ZSTD_inBuffer in = { comp_data, comp_size, 0 };
    ZSTD_outBuffer out = { dst_slice, slice_max_bytes, 0 };

    size_t ret = ZSTD_decompressStream(dctx, &out, &in);
    ZSTD_freeDCtx(dctx);

    if (!ZSTD_isError(ret) || out.pos > 0) {
        if (actual_decomp_bytes) *actual_decomp_bytes = out.pos;
        return 0;
    }

    return -3;
}
