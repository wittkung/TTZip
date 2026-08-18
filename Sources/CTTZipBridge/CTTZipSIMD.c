// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/CTTZipSIMD.h"
#include <libdeflate.h>

uint32_t ttzip_simd_crc32(uint32_t crc, const void* buf, size_t len) {
    if (!buf || len == 0) return crc;
    return libdeflate_crc32(crc, buf, len);
}

size_t ttzip_varint_write_u64(uint8_t* dst, uint64_t value) {
    if (!dst) return 0;
    if (value < 0x80) {
        dst[0] = (uint8_t)value;
        return 1;
    }
    uint8_t mask = 0x80;
    size_t extra = 0;
    for (int i = 1; i <= 8; i++) {
        if (value < (1ULL << (7 * i))) {
            extra = (size_t)i;
            break;
        }
        mask |= (0x80 >> i);
    }
    if (extra == 0) extra = 8;
    dst[0] = mask | (uint8_t)(value >> (extra * 8));
    for (size_t i = 0; i < extra; i++) {
        dst[1 + i] = (uint8_t)(value >> (i * 8));
    }
    return 1 + extra;
}

bool ttzip_simd_is_all_zero_64b(const void* buf, size_t len) {
    if (!buf || len == 0) return true;
    const uint8_t* p = (const uint8_t*)buf;
    size_t i = 0;

#if defined(__ARM_NEON) || defined(__ARM_NEON__) || defined(__aarch64__)
    uint8x16_t acc = vdupq_n_u8(0);
    for (; i + 64 <= len; i += 64) {
        uint8x16_t v0 = vld1q_u8(p + i);
        uint8x16_t v1 = vld1q_u8(p + i + 16);
        uint8x16_t v2 = vld1q_u8(p + i + 32);
        uint8x16_t v3 = vld1q_u8(p + i + 48);
        acc = vorrq_u8(acc, vorrq_u8(vorrq_u8(v0, v1), vorrq_u8(v2, v3)));
        if (vmaxvq_u8(acc) != 0) {
            return false;
        }
    }
    for (; i + 16 <= len; i += 16) {
        uint8x16_t v = vld1q_u8(p + i);
        if (vmaxvq_u8(v) != 0) return false;
    }
#else
    for (; i + 64 <= len; i += 64) {
        const uint64_t* u = (const uint64_t*)(p + i);
        uint64_t diff = u[0] | u[1] | u[2] | u[3] | u[4] | u[5] | u[6] | u[7];
        if (diff != 0) return false;
    }
#endif

    for (; i < len; i++) {
        if (p[i] != 0) return false;
    }
    return true;
}

bool ttzip_simd_is_uniform_64b(const void* buf, size_t len, uint64_t* out_pattern) {
    if (!buf || len == 0) {
        if (out_pattern) *out_pattern = 0;
        return true;
    }
    if (len < 8) {
        const uint8_t* p = (const uint8_t*)buf;
        uint8_t first = p[0];
        for (size_t k = 1; k < len; k++) {
            if (p[k] != first) return false;
        }
        if (out_pattern) {
            uint64_t pat = 0;
            for (int k = 0; k < 8; k++) pat |= ((uint64_t)first << (k * 8));
            *out_pattern = pat;
        }
        return true;
    }

    const uint64_t* u64 = (const uint64_t*)buf;
    uint64_t pat = u64[0];
    size_t words = len / sizeof(uint64_t);
    size_t k = 0;

    for (; k + 8 <= words; k += 8) {
        uint64_t diff = (u64[k] ^ pat) | (u64[k+1] ^ pat) | (u64[k+2] ^ pat) | (u64[k+3] ^ pat) |
                        (u64[k+4] ^ pat) | (u64[k+5] ^ pat) | (u64[k+6] ^ pat) | (u64[k+7] ^ pat);
        if (diff != 0) return false;
    }
    for (; k < words; k++) {
        if (u64[k] != pat) return false;
    }

    size_t rem = len % sizeof(uint64_t);
    if (rem > 0) {
        const uint8_t* p = ((const uint8_t*)buf) + words * sizeof(uint64_t);
        const uint8_t* pat_bytes = (const uint8_t*)&pat;
        for (size_t j = 0; j < rem; j++) {
            if (p[j] != pat_bytes[j]) return false;
        }
    }

    if (out_pattern) *out_pattern = pat;
    return true;
}

