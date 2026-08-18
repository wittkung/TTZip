// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/CTTZipFilterPipeline.h"
#include <string.h>
#include <stdlib.h>
#include <unistd.h>

#if (defined(__ARM_NEON) || defined(__aarch64__)) && !defined(__arm64_disabled__)
#include <arm_neon.h>
#endif

void ttzip_filter_shuffle_forward(const uint8_t* src, uint8_t* dst, size_t size, uint8_t typesize) {
    if (!src || !dst || size == 0 || typesize <= 1) {
        if (src && dst && src != dst && size > 0) {
            memcpy(dst, src, size);
        }
        return;
    }

    size_t num_elements = size / typesize;
    if (num_elements == 0) {
        memcpy(dst, src, size);
        return;
    }

#if (defined(__ARM_NEON) || defined(__aarch64__))
    if (typesize == 4 && num_elements >= 16) {
        size_t vec_count = num_elements / 16;
        const uint8_t* s_ptr = src;
        
        for (size_t i = 0; i < vec_count; i++) {
            uint8x16x4_t loaded = vld4q_u8(s_ptr);
            vst1q_u8(dst + 0 * num_elements + i * 16, loaded.val[0]);
            vst1q_u8(dst + 1 * num_elements + i * 16, loaded.val[1]);
            vst1q_u8(dst + 2 * num_elements + i * 16, loaded.val[2]);
            vst1q_u8(dst + 3 * num_elements + i * 16, loaded.val[3]);
            s_ptr += 64;
        }

        size_t processed_elems = vec_count * 16;
        for (size_t i = processed_elems; i < num_elements; i++) {
            for (size_t j = 0; j < typesize; j++) {
                dst[j * num_elements + i] = src[i * typesize + j];
            }
        }
        
        size_t remainder = size % typesize;
        if (remainder > 0) {
            memcpy(dst + num_elements * typesize, src + num_elements * typesize, remainder);
        }
        return;
    }
#endif

    for (size_t j = 0; j < typesize; j++) {
        uint8_t* out_plane = dst + j * num_elements;
        for (size_t i = 0; i < num_elements; i++) {
            out_plane[i] = src[i * typesize + j];
        }
    }

    size_t remainder = size % typesize;
    if (remainder > 0) {
        memcpy(dst + num_elements * typesize, src + num_elements * typesize, remainder);
    }
}

void ttzip_filter_shuffle_backward(const uint8_t* src, uint8_t* dst, size_t size, uint8_t typesize) {
    if (!src || !dst || size == 0 || typesize <= 1) {
        if (src && dst && src != dst && size > 0) {
            memcpy(dst, src, size);
        }
        return;
    }

    size_t num_elements = size / typesize;
    if (num_elements == 0) {
        memcpy(dst, src, size);
        return;
    }

#if (defined(__ARM_NEON) || defined(__aarch64__))
    if (typesize == 4 && num_elements >= 16) {
        size_t vec_count = num_elements / 16;
        uint8_t* d_ptr = dst;

        for (size_t i = 0; i < vec_count; i++) {
            uint8x16x4_t gathered;
            gathered.val[0] = vld1q_u8(src + 0 * num_elements + i * 16);
            gathered.val[1] = vld1q_u8(src + 1 * num_elements + i * 16);
            gathered.val[2] = vld1q_u8(src + 2 * num_elements + i * 16);
            gathered.val[3] = vld1q_u8(src + 3 * num_elements + i * 16);
            vst4q_u8(d_ptr, gathered);
            d_ptr += 64;
        }

        size_t processed_elems = vec_count * 16;
        for (size_t i = processed_elems; i < num_elements; i++) {
            for (size_t j = 0; j < typesize; j++) {
                dst[i * typesize + j] = src[j * num_elements + i];
            }
        }

        size_t remainder = size % typesize;
        if (remainder > 0) {
            memcpy(dst + num_elements * typesize, src + num_elements * typesize, remainder);
        }
        return;
    }
#endif

    for (size_t i = 0; i < num_elements; i++) {
        for (size_t j = 0; j < typesize; j++) {
            dst[i * typesize + j] = src[j * num_elements + i];
        }
    }

    size_t remainder = size % typesize;
    if (remainder > 0) {
        memcpy(dst + num_elements * typesize, src + num_elements * typesize, remainder);
    }
}

void ttzip_filter_truncate_float32_neon(const float* src, float* dst, size_t count, uint8_t keep_bits) {
    if (!src || !dst || count == 0) return;
    if (keep_bits >= 23) {
        if (src != dst) memcpy(dst, src, count * sizeof(float));
        return;
    }
    if (keep_bits == 0) keep_bits = 1;

    uint32_t q = 23 - keep_bits;
    uint32_t mask_val = ~((1U << q) - 1U);
    uint32_t bias_val = 1U << (q - 1);

#if (defined(__ARM_NEON) || defined(__aarch64__))
    uint32x4_t v_mask = vdupq_n_u32(mask_val);
    uint32x4_t v_bias = vdupq_n_u32(bias_val);
    size_t vec_count = count / 4;

    const uint32_t* s_ptr = (const uint32_t*)src;
    uint32_t* d_ptr = (uint32_t*)dst;

    for (size_t i = 0; i < vec_count; i++) {
        uint32x4_t v_in = vld1q_u32(s_ptr);
        uint32x4_t v_rounded = vaddq_u32(v_in, v_bias);
        uint32x4_t v_out = vandq_u32(v_rounded, v_mask);
        vst1q_u32(d_ptr, v_out);
        s_ptr += 4;
        d_ptr += 4;
    }

    size_t rem = count % 4;
    for (size_t i = 0; i < rem; i++) {
        uint32_t val = *s_ptr++;
        *d_ptr++ = (val + bias_val) & mask_val;
    }
#else
    const uint32_t* s_ptr = (const uint32_t*)src;
    uint32_t* d_ptr = (uint32_t*)dst;
    for (size_t i = 0; i < count; i++) {
        uint32_t val = s_ptr[i];
        d_ptr[i] = (val + bias_val) & mask_val;
    }
#endif
}

void ttzip_filter_truncate_float64_neon(const double* src, double* dst, size_t count, uint8_t keep_bits) {
    if (!src || !dst || count == 0) return;
    if (keep_bits >= 52) {
        if (src != dst) memcpy(dst, src, count * sizeof(double));
        return;
    }
    if (keep_bits == 0) keep_bits = 1;

    uint64_t q = 52 - keep_bits;
    uint64_t mask_val = ~((1ULL << q) - 1ULL);
    uint64_t bias_val = 1ULL << (q - 1);

#if (defined(__ARM_NEON) || defined(__aarch64__))
    uint64x2_t v_mask = vdupq_n_u64(mask_val);
    uint64x2_t v_bias = vdupq_n_u64(bias_val);
    size_t vec_count = count / 2;

    const uint64_t* s_ptr = (const uint64_t*)src;
    uint64_t* d_ptr = (uint64_t*)dst;

    for (size_t i = 0; i < vec_count; i++) {
        uint64x2_t v_in = vld1q_u64(s_ptr);
        uint64x2_t v_rounded = vaddq_u64(v_in, v_bias);
        uint64x2_t v_out = vandq_u64(v_rounded, v_mask);
        vst1q_u64(d_ptr, v_out);
        s_ptr += 2;
        d_ptr += 2;
    }

    size_t rem = count % 2;
    for (size_t i = 0; i < rem; i++) {
        uint64_t val = *s_ptr++;
        *d_ptr++ = (val + bias_val) & mask_val;
    }
#else
    const uint64_t* s_ptr = (const uint64_t*)src;
    uint64_t* d_ptr = (uint64_t*)dst;
    for (size_t i = 0; i < count; i++) {
        uint64_t val = s_ptr[i];
        d_ptr[i] = (val + bias_val) & mask_val;
    }
#endif
}

void ttzip_filter_delta_forward(uint8_t* buf, size_t size) {
    if (!buf || size <= 1) return;
    for (size_t i = size - 1; i > 0; i--) {
        buf[i] = (uint8_t)(buf[i] - buf[i - 1]);
    }
}

void ttzip_filter_delta_backward(uint8_t* buf, size_t size) {
    if (!buf || size <= 1) return;
    for (size_t i = 1; i < size; i++) {
        buf[i] = (uint8_t)(buf[i] + buf[i - 1]);
    }
}

int ttzip_filter_pipeline_apply_forward(
    const ttzip_filter_pipeline_t* pipeline,
    const uint8_t* src,
    uint8_t* dst,
    size_t size
) {
    if (!src || !dst || size == 0) return -1;
    if (!pipeline || pipeline->count == 0) {
        if (src != dst) memcpy(dst, src, size);
        return 0;
    }

    uint8_t stack_buf1[65536];
    uint8_t stack_buf2[65536];
    uint8_t* buf1 = (size <= sizeof(stack_buf1)) ? stack_buf1 : (uint8_t*)malloc(size);
    uint8_t* buf2 = (size <= sizeof(stack_buf2)) ? stack_buf2 : (uint8_t*)malloc(size);
    if (!buf1 || !buf2) {
        if (buf1 && buf1 != stack_buf1) free(buf1);
        if (buf2 && buf2 != stack_buf2) free(buf2);
        return -1;
    }

    memcpy(buf1, src, size);
    uint8_t* cur_in = buf1;
    uint8_t* cur_out = buf2;

    for (size_t k = 0; k < pipeline->count; k++) {
        ttzip_filter_type_t filter = pipeline->filters[k];
        uint8_t typesize = pipeline->type_sizes[k];
        if (typesize == 0) typesize = 1;
        uint8_t t_bits = pipeline->truncate_bits[k];

        switch (filter) {
            case TTZIP_FILTER_SHUFFLE:
                ttzip_filter_shuffle_forward(cur_in, cur_out, size, typesize);
                break;
            case TTZIP_FILTER_DELTA:
                if (cur_in != cur_out) memcpy(cur_out, cur_in, size);
                ttzip_filter_delta_forward(cur_out, size);
                break;
            case TTZIP_FILTER_TRUNCATE_FLOAT32:
                ttzip_filter_truncate_float32_neon((const float*)cur_in, (float*)cur_out, size / sizeof(float), t_bits > 0 ? t_bits : 7);
                break;
            case TTZIP_FILTER_TRUNCATE_FLOAT64:
                ttzip_filter_truncate_float64_neon((const double*)cur_in, (double*)cur_out, size / sizeof(double), t_bits > 0 ? t_bits : 14);
                break;
            case TTZIP_FILTER_NONE:
            default:
                if (cur_in != cur_out) memcpy(cur_out, cur_in, size);
                break;
        }

        uint8_t* tmp = cur_in;
        cur_in = cur_out;
        cur_out = tmp;
    }

    memcpy(dst, cur_in, size);

    if (buf1 != stack_buf1) free(buf1);
    if (buf2 != stack_buf2) free(buf2);
    return 0;
}

int ttzip_filter_pipeline_apply_backward(
    const ttzip_filter_pipeline_t* pipeline,
    const uint8_t* src,
    uint8_t* dst,
    size_t size
) {
    if (!src || !dst || size == 0) return -1;
    if (!pipeline || pipeline->count == 0) {
        if (src != dst) memcpy(dst, src, size);
        return 0;
    }

    uint8_t stack_buf1[65536];
    uint8_t stack_buf2[65536];
    uint8_t* buf1 = (size <= sizeof(stack_buf1)) ? stack_buf1 : (uint8_t*)malloc(size);
    uint8_t* buf2 = (size <= sizeof(stack_buf2)) ? stack_buf2 : (uint8_t*)malloc(size);
    if (!buf1 || !buf2) {
        if (buf1 && buf1 != stack_buf1) free(buf1);
        if (buf2 && buf2 != stack_buf2) free(buf2);
        return -1;
    }

    memcpy(buf1, src, size);
    uint8_t* cur_in = buf1;
    uint8_t* cur_out = buf2;

    for (ssize_t k = (ssize_t)pipeline->count - 1; k >= 0; k--) {
        ttzip_filter_type_t filter = pipeline->filters[k];
        uint8_t typesize = pipeline->type_sizes[k];
        if (typesize == 0) typesize = 1;

        switch (filter) {
            case TTZIP_FILTER_SHUFFLE:
                ttzip_filter_shuffle_backward(cur_in, cur_out, size, typesize);
                break;
            case TTZIP_FILTER_DELTA:
                if (cur_in != cur_out) memcpy(cur_out, cur_in, size);
                ttzip_filter_delta_backward(cur_out, size);
                break;
            case TTZIP_FILTER_TRUNCATE_FLOAT32:
            case TTZIP_FILTER_TRUNCATE_FLOAT64:
                // Truncation is lossy; backward pass preserves current data
                if (cur_in != cur_out) memcpy(cur_out, cur_in, size);
                break;
            case TTZIP_FILTER_NONE:
            default:
                if (cur_in != cur_out) memcpy(cur_out, cur_in, size);
                break;
        }

        uint8_t* tmp = cur_in;
        cur_in = cur_out;
        cur_out = tmp;
    }

    memcpy(dst, cur_in, size);

    if (buf1 != stack_buf1) free(buf1);
    if (buf2 != stack_buf2) free(buf2);
    return 0;
}
