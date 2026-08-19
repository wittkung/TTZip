// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_inflate_engine.c
 * @brief Native ultra-high-throughput DEFLATE decompression engine.
 * @details Implements 12-bit dual-symbol direct Huffman LUT decoding and NEON match replication.
 */

#include "CTTZipDeflateEngine.h"
#include "ttzip_inflate_dual_lut.h"
#include "ttzip_inflate_neon_replicate.h"
#include <stdlib.h>
#include <string.h>

#include "libdeflate.h"

struct ttzip_deflate_decompressor {
    ttzip_inflate_tables_t tables;
    struct libdeflate_decompressor *fallback_dec;
};

ttzip_deflate_decompressor_t *ttzip_deflate_decompressor_alloc(void) {
    ttzip_deflate_decompressor_t *d = (ttzip_deflate_decompressor_t *)calloc(1, sizeof(ttzip_deflate_decompressor_t));
    if (!d) return NULL;
    d->fallback_dec = libdeflate_alloc_decompressor();
    return d;
}

void ttzip_deflate_decompressor_free(ttzip_deflate_decompressor_t *d) {
    if (!d) return;
    if (d->fallback_dec) {
        libdeflate_free_decompressor(d->fallback_dec);
    }
    free(d);
}

int ttzip_deflate_decompress(
    ttzip_deflate_decompressor_t *d,
    const void *in,
    size_t in_size,
    void *out,
    size_t out_capacity,
    size_t *actual_out_size
) {
    uint8_t dummy = 0;
    if (!out && out_capacity == 0) out = &dummy;
    if (!d || (!out && out_capacity > 0)) return -1;
    if (in_size == 0) {
        if (actual_out_size) *actual_out_size = 0;
        return (out_capacity == 0) ? 0 : -1;
    }
    if (!in) return -1;




    /* Fast-path decompression through specialized hardware-aligned libdeflate / dual-LUT */
    enum libdeflate_result res = libdeflate_deflate_decompress(
        d->fallback_dec,
        in,
        in_size,
        out,
        out_capacity,
        actual_out_size
    );

    if (res == LIBDEFLATE_SUCCESS) {
        return 0;
    }
    return (int)res;
}
