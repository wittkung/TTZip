// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine.

#include "include/ttzip_api.h"
#include "include/CTTZipStreamCoder.h"
#include "include/ttzip_zopfli_engine.h"
#include "fast-lzma2/fast-lzma2.h"
#include "lzfse/lzfse.h"
#include "snappy/snappy-c.h"
#include <libdeflate.h>
#include <zstd.h>
#include <string.h>

uint32_t ttzip_version_number(void) {
    return (TTZIP_VERSION_MAJOR << 16) | (TTZIP_VERSION_MINOR << 8) | TTZIP_VERSION_PATCH;
}

const char *ttzip_version_string(void) {
    return TTZIP_VERSION_STRING;
}

size_t ttzip_compress_bound(ttzip_api_codec_t codec, size_t in_size) {
    switch (codec) {
    case TTZIP_API_CODEC_STORE:
        return in_size;
    case TTZIP_API_CODEC_DEFLATE:
    case TTZIP_API_CODEC_ZOPFLI:
        return libdeflate_deflate_compress_bound(NULL, in_size);
    case TTZIP_API_CODEC_ZSTD:
        return ZSTD_compressBound(in_size);
    case TTZIP_API_CODEC_LZMA2:
        return FL2_compressBound(in_size);
    case TTZIP_API_CODEC_LZFSE:
        return in_size + 4096;
    case TTZIP_API_CODEC_SNAPPY:
        return snappy_max_compressed_length(in_size);
    default:
        return in_size + (in_size >> 3) + 128;
    }
}

size_t ttzip_compress_buffer(
    ttzip_api_codec_t codec,
    const void *src,
    size_t src_len,
    void *dst,
    size_t dst_cap,
    int level
) {
    if (!src || !dst) return 0;
    if (src_len == 0) return 0;

    switch (codec) {
    case TTZIP_API_CODEC_STORE:
        if (dst_cap < src_len) return 0;
        memcpy(dst, src, src_len);
        return src_len;

    case TTZIP_API_CODEC_DEFLATE:
        return ttzip_libdeflate_compress(src, src_len, dst, dst_cap, level > 0 ? level : 6);

    case TTZIP_API_CODEC_ZSTD:
        return ZSTD_compress(dst, dst_cap, src, src_len, level > 0 ? level : 3);

    case TTZIP_API_CODEC_LZMA2:
        return FL2_compress(dst, dst_cap, src, src_len, level > 0 ? level : 6);

    case TTZIP_API_CODEC_LZFSE:
        return lzfse_encode_buffer((uint8_t *)dst, dst_cap, (const uint8_t *)src, src_len, NULL);

    case TTZIP_API_CODEC_SNAPPY: {
        size_t out_len = dst_cap;
        if (snappy_compress((const char *)src, src_len, (char *)dst, &out_len) == SNAPPY_OK) {
            return out_len;
        }
        return 0;
    }

    case TTZIP_API_CODEC_ZOPFLI: {
        TTZipZopfliOptions opts;
        ttzip_zopfli_init_options(&opts, level > 0 ? level : 6);
        return ttzip_zopfli_compress_block_with_history(
            (const uint8_t *)src, src_len, NULL, 0, (uint8_t *)dst, dst_cap, &opts, 1
        );
    }

    default:
        return 0;
    }
}

size_t ttzip_decompress_buffer(
    ttzip_api_codec_t codec,
    const void *src,
    size_t src_len,
    void *dst,
    size_t dst_cap
) {
    if (!src || !dst) return 0;
    if (src_len == 0) return 0;

    switch (codec) {
    case TTZIP_API_CODEC_STORE:
        if (dst_cap < src_len) return 0;
        memcpy(dst, src, src_len);
        return src_len;

    case TTZIP_API_CODEC_DEFLATE:
    case TTZIP_API_CODEC_ZOPFLI:
        return ttzip_libdeflate_decompress(src, src_len, dst, dst_cap);

    case TTZIP_API_CODEC_ZSTD:
        return ZSTD_decompress(dst, dst_cap, src, src_len);

    case TTZIP_API_CODEC_LZMA2:
        return FL2_decompress(dst, dst_cap, src, src_len);

    case TTZIP_API_CODEC_LZFSE:
        return lzfse_decode_buffer((uint8_t *)dst, dst_cap, (const uint8_t *)src, src_len, NULL);

    case TTZIP_API_CODEC_SNAPPY: {
        size_t out_len = dst_cap;
        if (snappy_uncompress((const char *)src, src_len, (char *)dst, &out_len) == SNAPPY_OK) {
            return out_len;
        }
        return 0;
    }

    default:
        return 0;
    }
}
