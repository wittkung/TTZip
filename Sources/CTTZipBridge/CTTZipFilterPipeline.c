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

#include "include/CTTZipSIMD.h"

void ttzip_filter_bitshuffle_forward_neon(const uint8_t* src, uint8_t* dst, size_t size, uint8_t typesize) {
    if (!src || !dst || size == 0) return;
    if (typesize == 0) typesize = 1;

    // 1. Stage 1: Byte Shuffle
    ttzip_filter_shuffle_forward(src, dst, size, typesize);

    // 2. Stage 2: Bit-Plane Transposition (on each 8-byte sub-matrix)
    size_t full_words = size / 8;
    size_t offset = 0;

#if (defined(__ARM_NEON) || defined(__aarch64__))
    uint64x2_t mask1 = vdupq_n_u64(0x00AA00AA00AA00AAULL);
    uint64x2_t mask2 = vdupq_n_u64(0x0000CCCC0000CCCCULL);
    uint64x2_t mask3 = vdupq_n_u64(0x00000000F0F0F0F0ULL);

    // 64-byte unrolled loop (4 NEON vectors = 8 matrices of 8x8 bits)
    while (offset + 64 <= size) {
        uint64x2_t v0 = vld1q_u64((const uint64_t*)(dst + offset));
        uint64x2_t v1 = vld1q_u64((const uint64_t*)(dst + offset + 16));
        uint64x2_t v2 = vld1q_u64((const uint64_t*)(dst + offset + 32));
        uint64x2_t v3 = vld1q_u64((const uint64_t*)(dst + offset + 48));

        v0 = ttzip_neon_transpose_8x8_2x(v0, mask1, mask2, mask3);
        v1 = ttzip_neon_transpose_8x8_2x(v1, mask1, mask2, mask3);
        v2 = ttzip_neon_transpose_8x8_2x(v2, mask1, mask2, mask3);
        v3 = ttzip_neon_transpose_8x8_2x(v3, mask1, mask2, mask3);

        vst1q_u64((uint64_t*)(dst + offset), v0);
        vst1q_u64((uint64_t*)(dst + offset + 16), v1);
        vst1q_u64((uint64_t*)(dst + offset + 32), v2);
        vst1q_u64((uint64_t*)(dst + offset + 48), v3);

        offset += 64;
    }

    // 16-byte single vector loop
    while (offset + 16 <= size) {
        uint64x2_t v = vld1q_u64((const uint64_t*)(dst + offset));
        v = ttzip_neon_transpose_8x8_2x(v, mask1, mask2, mask3);
        vst1q_u64((uint64_t*)(dst + offset), v);
        offset += 16;
    }
#endif

    // 8-byte scalar loop
    while (offset + 8 <= size) {
        uint64_t w = *(const uint64_t*)(dst + offset);
        *(uint64_t*)(dst + offset) = ttzip_scalar_transpose_8x8(w);
        offset += 8;
    }

    // Trailing 1..7 bytes remain as-is (tail boundary integrity)
}

void ttzip_filter_bitshuffle_backward_neon(const uint8_t* src, uint8_t* dst, size_t size, uint8_t typesize) {
    if (!src || !dst || size == 0) return;
    if (typesize == 0) typesize = 1;

    // Bit-matrix transposition is symmetric involution ((M^T)^T = M)
    // 1. Stage 1: Untranspose bits
    if (src != dst) memcpy(dst, src, size);

    size_t offset = 0;

#if (defined(__ARM_NEON) || defined(__aarch64__))
    uint64x2_t mask1 = vdupq_n_u64(0x00AA00AA00AA00AAULL);
    uint64x2_t mask2 = vdupq_n_u64(0x0000CCCC0000CCCCULL);
    uint64x2_t mask3 = vdupq_n_u64(0x00000000F0F0F0F0ULL);

    while (offset + 64 <= size) {
        uint64x2_t v0 = vld1q_u64((const uint64_t*)(dst + offset));
        uint64x2_t v1 = vld1q_u64((const uint64_t*)(dst + offset + 16));
        uint64x2_t v2 = vld1q_u64((const uint64_t*)(dst + offset + 32));
        uint64x2_t v3 = vld1q_u64((const uint64_t*)(dst + offset + 48));

        v0 = ttzip_neon_transpose_8x8_2x(v0, mask1, mask2, mask3);
        v1 = ttzip_neon_transpose_8x8_2x(v1, mask1, mask2, mask3);
        v2 = ttzip_neon_transpose_8x8_2x(v2, mask1, mask2, mask3);
        v3 = ttzip_neon_transpose_8x8_2x(v3, mask1, mask2, mask3);

        vst1q_u64((uint64_t*)(dst + offset), v0);
        vst1q_u64((uint64_t*)(dst + offset + 16), v1);
        vst1q_u64((uint64_t*)(dst + offset + 32), v2);
        vst1q_u64((uint64_t*)(dst + offset + 48), v3);

        offset += 64;
    }

    while (offset + 16 <= size) {
        uint64x2_t v = vld1q_u64((const uint64_t*)(dst + offset));
        v = ttzip_neon_transpose_8x8_2x(v, mask1, mask2, mask3);
        vst1q_u64((uint64_t*)(dst + offset), v);
        offset += 16;
    }
#endif

    while (offset + 8 <= size) {
        uint64_t w = *(const uint64_t*)(dst + offset);
        *(uint64_t*)(dst + offset) = ttzip_scalar_transpose_8x8(w);
        offset += 8;
    }

    // 2. Stage 2: Byte Unshuffle
    uint8_t stack_tmp[65536];
    uint8_t* tmp_buf = (size <= sizeof(stack_tmp)) ? stack_tmp : (uint8_t*)malloc(size);
    if (tmp_buf) {
        memcpy(tmp_buf, dst, size);
        ttzip_filter_shuffle_backward(tmp_buf, dst, size, typesize);
        if (tmp_buf != stack_tmp) free(tmp_buf);
    }
}

#if (defined(__ARM_NEON) || defined(__aarch64__))
static inline uint8x16_t neon_prefix_sum_16b(uint8x16_t x) {
    uint8x16_t zero = vdupq_n_u8(0);
    x = vaddq_u8(x, vextq_u8(zero, x, 15));
    x = vaddq_u8(x, vextq_u8(zero, x, 14));
    x = vaddq_u8(x, vextq_u8(zero, x, 12));
    x = vaddq_u8(x, vextq_u8(zero, x, 8));
    return x;
}
#endif

void ttzip_filter_bytedelta_forward_neon(const uint8_t* src, uint8_t* dst, size_t size, uint8_t typesize) {
    if (!src || !dst || size == 0) return;
    if (typesize <= 1) {
        // Flat byte stream differencing
#if (defined(__ARM_NEON) || defined(__aarch64__))
        if (size >= 16) {
            uint8x16_t v_prev = vdupq_n_u8(0);
            size_t offset = 0;
            while (offset + 16 <= size) {
                uint8x16_t v_curr = vld1q_u8(src + offset);
                uint8x16_t v_prev_shifted = vextq_u8(v_prev, v_curr, 15);
                uint8x16_t v_delta = vsubq_u8(v_curr, v_prev_shifted);
                vst1q_u8(dst + offset, v_delta);
                v_prev = v_curr;
                offset += 16;
            }
            if (offset < size) {
                uint8_t last = src[offset - 1];
                for (size_t i = offset; i < size; i++) {
                    dst[i] = (uint8_t)(src[i] - last);
                    last = src[i];
                }
            }
            return;
        }
#endif
        uint8_t last = 0;
        for (size_t i = 0; i < size; i++) {
            dst[i] = (uint8_t)(src[i] - last);
            last = src[i];
        }
        return;
    }

    // Transposed multi-plane differencing (plane by plane)
    size_t num_elements = size / typesize;
    for (size_t p = 0; p < typesize; p++) {
        const uint8_t* p_src = src + p * num_elements;
        uint8_t* p_dst = dst + p * num_elements;
        uint8_t last = 0;
        for (size_t i = 0; i < num_elements; i++) {
            p_dst[i] = (uint8_t)(p_src[i] - last);
            last = p_src[i];
        }
    }
    size_t rem = size % typesize;
    if (rem > 0) {
        memcpy(dst + num_elements * typesize, src + num_elements * typesize, rem);
    }
}

void ttzip_filter_bytedelta_backward_neon(const uint8_t* src, uint8_t* dst, size_t size, uint8_t typesize) {
    if (!src || !dst || size == 0) return;
    if (typesize <= 1) {
#if (defined(__ARM_NEON) || defined(__aarch64__))
        if (size >= 128) {
            uint8_t carry = 0;
            size_t offset = 0;
            while (offset + 128 <= size) {
                uint8x16_t v0 = vld1q_u8(src + offset + 0 * 16);
                uint8x16_t v1 = vld1q_u8(src + offset + 1 * 16);
                uint8x16_t v2 = vld1q_u8(src + offset + 2 * 16);
                uint8x16_t v3 = vld1q_u8(src + offset + 3 * 16);
                uint8x16_t v4 = vld1q_u8(src + offset + 4 * 16);
                uint8x16_t v5 = vld1q_u8(src + offset + 5 * 16);
                uint8x16_t v6 = vld1q_u8(src + offset + 6 * 16);
                uint8x16_t v7 = vld1q_u8(src + offset + 7 * 16);

                v0 = neon_prefix_sum_16b(v0);
                v1 = neon_prefix_sum_16b(v1);
                v2 = neon_prefix_sum_16b(v2);
                v3 = neon_prefix_sum_16b(v3);
                v4 = neon_prefix_sum_16b(v4);
                v5 = neon_prefix_sum_16b(v5);
                v6 = neon_prefix_sum_16b(v6);
                v7 = neon_prefix_sum_16b(v7);

                uint8_t s0 = vgetq_lane_u8(v0, 15);
                uint8_t s1 = vgetq_lane_u8(v1, 15);
                uint8_t s2 = vgetq_lane_u8(v2, 15);
                uint8_t s3 = vgetq_lane_u8(v3, 15);
                uint8_t s4 = vgetq_lane_u8(v4, 15);
                uint8_t s5 = vgetq_lane_u8(v5, 15);
                uint8_t s6 = vgetq_lane_u8(v6, 15);
                uint8_t s7 = vgetq_lane_u8(v7, 15);

                uint8_t b0 = carry;
                uint8_t b1 = b0 + s0;
                uint8_t b2 = b1 + s1;
                uint8_t b3 = b2 + s2;
                uint8_t b4 = b3 + s3;
                uint8_t b5 = b4 + s4;
                uint8_t b6 = b5 + s5;
                uint8_t b7 = b6 + s6;
                carry = b7 + s7;

                v0 = vaddq_u8(v0, vdupq_n_u8(b0));
                v1 = vaddq_u8(v1, vdupq_n_u8(b1));
                v2 = vaddq_u8(v2, vdupq_n_u8(b2));
                v3 = vaddq_u8(v3, vdupq_n_u8(b3));
                v4 = vaddq_u8(v4, vdupq_n_u8(b4));
                v5 = vaddq_u8(v5, vdupq_n_u8(b5));
                v6 = vaddq_u8(v6, vdupq_n_u8(b6));
                v7 = vaddq_u8(v7, vdupq_n_u8(b7));

                vst1q_u8(dst + offset + 0 * 16, v0);
                vst1q_u8(dst + offset + 1 * 16, v1);
                vst1q_u8(dst + offset + 2 * 16, v2);
                vst1q_u8(dst + offset + 3 * 16, v3);
                vst1q_u8(dst + offset + 4 * 16, v4);
                vst1q_u8(dst + offset + 5 * 16, v5);
                vst1q_u8(dst + offset + 6 * 16, v6);
                vst1q_u8(dst + offset + 7 * 16, v7);

                offset += 128;
            }
            if (offset < size) {
                for (size_t i = offset; i < size; i++) {
                    carry += src[i];
                    dst[i] = carry;
                }
            }
            return;
        }
#endif
        uint8_t running = 0;
        for (size_t i = 0; i < size; i++) {
            running += src[i];
            dst[i] = running;
        }
        return;
    }

    size_t num_elements = size / typesize;
    for (size_t p = 0; p < typesize; p++) {
        const uint8_t* p_src = src + p * num_elements;
        uint8_t* p_dst = dst + p * num_elements;
        uint8_t running = 0;
        for (size_t i = 0; i < num_elements; i++) {
            running += p_src[i];
            p_dst[i] = running;
        }
    }
    size_t rem = size % typesize;
    if (rem > 0) {
        memcpy(dst + num_elements * typesize, src + num_elements * typesize, rem);
    }
}

void ttzip_filter_delta_forward(uint8_t* buf, size_t size) {
    if (!buf || size <= 1) return;
    ttzip_filter_bytedelta_forward_neon(buf, buf, size, 1);
}

void ttzip_filter_delta_backward(uint8_t* buf, size_t size) {
    if (!buf || size <= 1) return;
    ttzip_filter_bytedelta_backward_neon(buf, buf, size, 1);
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
            case TTZIP_FILTER_BITSHUFFLE:
                ttzip_filter_bitshuffle_forward_neon(cur_in, cur_out, size, typesize);
                break;
            case TTZIP_FILTER_DELTA:
                ttzip_filter_bytedelta_forward_neon(cur_in, cur_out, size, typesize);
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
            case TTZIP_FILTER_BITSHUFFLE:
                ttzip_filter_bitshuffle_backward_neon(cur_in, cur_out, size, typesize);
                break;
            case TTZIP_FILTER_DELTA:
                ttzip_filter_bytedelta_backward_neon(cur_in, cur_out, size, typesize);
                break;
            case TTZIP_FILTER_TRUNCATE_FLOAT32:
            case TTZIP_FILTER_TRUNCATE_FLOAT64:
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

