// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/ttzip_container_fast.h"
#include "include/CTTZipStreamCoder.h"
#include "include/CTTZipChecksum.h"
#include <libdeflate.h>
#include <string.h>

#if defined(__GNUC__) || defined(__clang__)
#  define TTZIP_BSWAP16(v) __builtin_bswap16(v)
#  define TTZIP_BSWAP32(v) __builtin_bswap32(v)
#else
static inline uint16_t TTZIP_BSWAP16(uint16_t v) { return (v >> 8) | (v << 8); }
static inline uint32_t TTZIP_BSWAP32(uint32_t v) {
    return ((v >> 24) & 0xFF) | ((v >> 8) & 0xFF00) |
           ((v << 8) & 0xFF0000) | ((v << 24) & 0xFF000000);
}
#endif

static inline void put_le32(uint32_t v, uint8_t *p) {
#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
    memcpy(p, &v, sizeof(v));
#else
    uint32_t swapped = TTZIP_BSWAP32(v);
    memcpy(p, &swapped, sizeof(swapped));
#endif
}

static inline void put_be16(uint16_t v, uint8_t *p) {
#if __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
    memcpy(p, &v, sizeof(v));
#else
    uint16_t swapped = TTZIP_BSWAP16(v);
    memcpy(p, &swapped, sizeof(swapped));
#endif
}

static inline void put_be32(uint32_t v, uint8_t *p) {
#if __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
    memcpy(p, &v, sizeof(v));
#else
    uint32_t swapped = TTZIP_BSWAP32(v);
    memcpy(p, &swapped, sizeof(swapped));
#endif
}

static inline uint32_t get_le32(const uint8_t *p) {
    uint32_t v;
    memcpy(&v, p, sizeof(v));
#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
    return v;
#else
    return TTZIP_BSWAP32(v);
#endif
}

static inline uint32_t get_be32(const uint8_t *p) {
    uint32_t v;
    memcpy(&v, p, sizeof(v));
#if __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
    return v;
#else
    return TTZIP_BSWAP32(v);
#endif
}

size_t ttzip_gzip_compress_bound(size_t in_nbytes) {
    struct libdeflate_compressor* c = ttzip_get_tls_compressor(6);
    if (!c) return in_nbytes + 512;
    return TTZIP_GZIP_MIN_OVERHEAD + libdeflate_deflate_compress_bound(c, in_nbytes);
}

size_t ttzip_zlib_compress_bound(size_t in_nbytes) {
    struct libdeflate_compressor* c = ttzip_get_tls_compressor(6);
    if (!c) return in_nbytes + 512;
    return TTZIP_ZLIB_MIN_OVERHEAD + libdeflate_deflate_compress_bound(c, in_nbytes);
}

size_t ttzip_gzip_compress_fast(
    const void *in,
    size_t in_nbytes,
    void *out,
    size_t out_nbytes_avail,
    int level
) {
    if (!in || !out || out_nbytes_avail <= TTZIP_GZIP_MIN_OVERHEAD) return 0;

    struct libdeflate_compressor *c = ttzip_get_tls_compressor(level);
    if (!c) return 0;

    uint8_t *p = (uint8_t *)out;

    // 1. RFC 1952 10-byte fixed header
    p[0] = 0x1F;        // ID1
    p[1] = 0x8B;        // ID2
    p[2] = 8;           // CM = Deflate
    p[3] = 0;           // FLG = None
    put_le32(0, p + 4); // MTIME = 0
    p[8] = 0;           // XFL = 0
    p[9] = 255;         // OS = 255 (unknown)

    // 2. Direct in-place Deflate compression at offset 10
    size_t deflate_sz = libdeflate_deflate_compress(
        c,
        in,
        in_nbytes,
        p + 10,
        out_nbytes_avail - TTZIP_GZIP_MIN_OVERHEAD
    );
    if (deflate_sz == 0) return 0;

    uint8_t *trailer = p + 10 + deflate_sz;

    // 3. Fused hardware CRC-32 & ISIZE trailer (little-endian)
    uint32_t crc = ttzip_crc32_fast(0, (const uint8_t*)in, in_nbytes);
    put_le32(crc, trailer);
    put_le32((uint32_t)in_nbytes, trailer + 4);

    return 10 + deflate_sz + 8;
}

size_t ttzip_gzip_decompress_fast(
    const void *in,
    size_t in_nbytes,
    void *out,
    size_t out_nbytes_avail
) {
    if (!in || in_nbytes < TTZIP_GZIP_MIN_OVERHEAD || !out) return 0;

    const uint8_t *p = (const uint8_t *)in;
    if (p[0] != 0x1F || p[1] != 0x8B || p[2] != 8) return 0;

    size_t header_len = 10;
    uint8_t flg = p[3];

    // Optional FEXTRA
    if (flg & 0x04) {
        if (header_len + 2 > in_nbytes) return 0;
        uint16_t xlen = (uint16_t)p[header_len] | ((uint16_t)p[header_len + 1] << 8);
        header_len += 2 + xlen;
    }
    // Optional FNAME
    if (flg & 0x08) {
        while (header_len < in_nbytes && p[header_len] != 0) header_len++;
        header_len++;
    }
    // Optional FCOMMENT
    if (flg & 0x10) {
        while (header_len < in_nbytes && p[header_len] != 0) header_len++;
        header_len++;
    }
    // Optional FHCRC
    if (flg & 0x02) {
        header_len += 2;
    }

    if (header_len + 8 > in_nbytes) return 0;

    size_t deflate_len = in_nbytes - header_len - 8;
    const uint8_t *deflate_src = p + header_len;

    struct libdeflate_decompressor *dec = ttzip_get_tls_decompressor();
    if (!dec) return 0;

    size_t actual_out = 0;
    enum libdeflate_result res = libdeflate_deflate_decompress(
        dec,
        deflate_src,
        deflate_len,
        out,
        out_nbytes_avail,
        &actual_out
    );

    if (res != LIBDEFLATE_SUCCESS) return 0;

    // Verify CRC-32 & ISIZE trailer
    const uint8_t *trailer = p + in_nbytes - 8;
    uint32_t expected_crc = get_le32(trailer);
    uint32_t expected_isize = get_le32(trailer + 4);

    if ((uint32_t)actual_out != expected_isize) return 0;

    uint32_t actual_crc = ttzip_crc32_fast(0, (const uint8_t*)out, actual_out);
    if (actual_crc != expected_crc) return 0;

    return actual_out;
}

size_t ttzip_zlib_compress_fast(
    const void *in,
    size_t in_nbytes,
    void *out,
    size_t out_nbytes_avail,
    int level
) {
    if (!in || !out || out_nbytes_avail <= TTZIP_ZLIB_MIN_OVERHEAD) return 0;

    struct libdeflate_compressor *c = ttzip_get_tls_compressor(level);
    if (!c) return 0;

    uint8_t *p = (uint8_t *)out;

    // 1. RFC 1950 2-byte header: CMF/FLG (big-endian)
    uint16_t hdr = (7 << 12) | (8 << 8) | (2 << 6);
    hdr |= 31 - (hdr % 31);
    put_be16(hdr, p);

    // 2. Direct in-place Deflate compression at offset 2
    size_t deflate_sz = libdeflate_deflate_compress(
        c,
        in,
        in_nbytes,
        p + 2,
        out_nbytes_avail - TTZIP_ZLIB_MIN_OVERHEAD
    );
    if (deflate_sz == 0) return 0;

    uint8_t *trailer = p + 2 + deflate_sz;

    // 3. Fused hardware Adler-32 trailer (big-endian)
    uint32_t adler = ttzip_adler32_fast(1, (const uint8_t*)in, in_nbytes);
    put_be32(adler, trailer);

    return 2 + deflate_sz + 4;
}

size_t ttzip_zlib_decompress_fast(
    const void *in,
    size_t in_nbytes,
    void *out,
    size_t out_nbytes_avail
) {
    if (!in || in_nbytes < TTZIP_ZLIB_MIN_OVERHEAD || !out) return 0;

    const uint8_t *p = (const uint8_t *)in;
    uint16_t hdr = ((uint16_t)p[0] << 8) | (uint16_t)p[1];
    if ((hdr % 31) != 0) return 0;

    uint8_t cm = p[0] & 0x0F;
    uint8_t cinfo = (p[0] >> 4) & 0x0F;
    if (cm != 8 || cinfo > 7) return 0;

    size_t header_len = 2;
    if (p[1] & 0x20) { // FDICT
        header_len += 4;
    }

    if (header_len + 4 > in_nbytes) return 0;

    size_t deflate_len = in_nbytes - header_len - 4;
    const uint8_t *deflate_src = p + header_len;

    struct libdeflate_decompressor *dec = ttzip_get_tls_decompressor();
    if (!dec) return 0;

    size_t actual_out = 0;
    enum libdeflate_result res = libdeflate_deflate_decompress(
        dec,
        deflate_src,
        deflate_len,
        out,
        out_nbytes_avail,
        &actual_out
    );

    if (res != LIBDEFLATE_SUCCESS) return 0;

    // Verify Adler-32 trailer (big-endian)
    const uint8_t *trailer = p + in_nbytes - 4;
    uint32_t expected_adler = get_be32(trailer);
    uint32_t actual_adler = ttzip_adler32_fast(1, (const uint8_t*)out, actual_out);

    if (actual_adler != expected_adler) return 0;

    return actual_out;
}
