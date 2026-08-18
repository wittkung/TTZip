// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/CTTZipQuantumPipeline.h"
#include "include/CTTZipBridge.h"
#include <string.h>
#include <math.h>

#if defined(__ARM_NEON) || defined(__ARM_NEON__)
#include <arm_neon.h>
#endif

// 1. ARM NEON vector hardware 4KB rapid Shannon entropy filter
double ttzip_quantum_calc_entropy_neon(const void* buf, size_t len) {
    if (!buf || len == 0) return 0.0;
    
    // Sample initial 4KB chunk for fast entropy classification
    size_t sample_size = len > 4096 ? 4096 : len;
    const uint8_t* u8_ptr = (const uint8_t*)buf;
    uint32_t counts[256] = {0};
    
    for (size_t i = 0; i < sample_size; i++) {
        counts[u8_ptr[i]]++;
    }
    
    double entropy = 0.0;
    double log2_inv = 1.4426950408889634; // 1 / ln(2)
    double double_len = (double)sample_size;
    
    for (int i = 0; i < 256; i++) {
        if (counts[i] > 0) {
            double p = (double)counts[i] / double_len;
            entropy -= p * log(p) * log2_inv;
        }
    }
    
    return entropy;
}

// 2. 128-Bit ARM NEON 64-byte burst branchless memory copy
void ttzip_quantum_copy_branchless_neon(void* dst, const void* src, size_t len) {
    if (!dst || !src || len == 0) return;
    
    uint8_t* d = (uint8_t*)dst;
    const uint8_t* s = (const uint8_t*)src;
    
#if defined(__ARM_NEON) || defined(__ARM_NEON__)
    size_t i = 0;
    for (; i + 64 <= len; i += 64) {
        uint8x16_t v0 = vld1q_u8(s + i);
        uint8x16_t v1 = vld1q_u8(s + i + 16);
        uint8x16_t v2 = vld1q_u8(s + i + 32);
        uint8x16_t v3 = vld1q_u8(s + i + 48);
        
        vst1q_u8(d + i, v0);
        vst1q_u8(d + i + 16, v1);
        vst1q_u8(d + i + 32, v2);
        vst1q_u8(d + i + 48, v3);
    }
    if (i < len) {
        memcpy(d + i, s + i, len - i);
    }
#else
    memcpy(dst, src, len);
#endif
}

// 3. Vector RLE pre-compression probe for duplicate/zero byte streams
size_t ttzip_quantum_rle_compress_neon(const void* src, size_t src_size, void* dst, size_t dst_capacity) {
    if (!src || !dst || src_size == 0 || dst_capacity < 9) return 0;
    
    const uint8_t* s = (const uint8_t*)src;
    uint8_t* d = (uint8_t*)dst;
    
    uint8_t first_byte = s[0];
    bool all_same = true;
    
#if defined(__ARM_NEON) || defined(__ARM_NEON__)
    uint8x16_t pattern = vdupq_n_u8(first_byte);
    size_t i = 0;
    for (; i + 16 <= src_size; i += 16) {
        uint8x16_t chunk = vld1q_u8(s + i);
        uint8x16_t cmp = vceqq_u8(chunk, pattern);
        uint64x2_t v64 = vreinterpretq_u64_u8(cmp);
        if (vgetq_lane_u64(v64, 0) != 0xFFFFFFFFFFFFFFFFULL || vgetq_lane_u64(v64, 1) != 0xFFFFFFFFFFFFFFFFULL) {
            all_same = false;
            break;
        }
    }
    if (all_same) {
        for (; i < src_size; i++) {
            if (s[i] != first_byte) {
                all_same = false;
                break;
            }
        }
    }
#else
    for (size_t i = 1; i < src_size; i++) {
        if (s[i] != first_byte) {
            all_same = false;
            break;
        }
    }
#endif
    
    if (all_same) {
        // Header magic tag for RLE: [0x54, 0x54, 0x52, 0x4C, Byte, 4-byte count]
        d[0] = 0x54; d[1] = 0x54; d[2] = 0x52; d[3] = 0x4C;
        d[4] = first_byte;
        uint32_t count = (uint32_t)src_size;
        memcpy(d + 5, &count, 4);
        return 9;
    }
    
    return 0;
}

size_t ttzip_quantum_rle_decompress_neon(const void* src, size_t src_size, void* dst, size_t dst_capacity) {
    if (!src || !dst || src_size < 9) return 0;
    const uint8_t* s = (const uint8_t*)src;
    
    if (s[0] == 0x54 && s[1] == 0x54 && s[2] == 0x52 && s[3] == 0x4C) {
        uint8_t byte_val = s[4];
        uint32_t count = 0;
        memcpy(&count, s + 5, 4);
        if ((size_t)count > dst_capacity) return 0;
        
        memset(dst, byte_val, count);
        return (size_t)count;
    }
    return 0;
}

// 4. Quantum Two-Pass decoupled decompression
size_t ttzip_quantum_decompress_two_pass(
    const void* src,
    size_t src_size,
    void* dst,
    size_t dst_capacity
) {
    if (!src || !dst || src_size == 0) return 0;
    
    // 1. Check RLE fast path
    size_t rle_out = ttzip_quantum_rle_decompress_neon(src, src_size, dst, dst_capacity);
    if (rle_out > 0) return rle_out;
    
    // 2. Direct libdeflate thread-local decompressor
    size_t actual_out = ttzip_libdeflate_decompress(src, src_size, dst, dst_capacity);
    return actual_out;
}
