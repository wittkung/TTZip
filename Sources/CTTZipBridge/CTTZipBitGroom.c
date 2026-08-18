// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/CTTZipBitGroom.h"
#include <math.h>
#include <string.h>

#if defined(__ARM_NEON) || defined(__ARM_NEON__)
#include <arm_neon.h>
#endif

uint32_t ttzip_bitgroom_calc_mantissa_bits(uint8_t nsd, bool is_double) {
    if (is_double) {
        if (nsd < 1) nsd = 1;
        if (nsd > 15) nsd = 15;
        uint32_t prc = (uint32_t)ceil(3.321928094887362 * (double)nsd) + 2;
        if (prc > 52) prc = 52;
        return prc;
    } else {
        if (nsd < 1) nsd = 1;
        if (nsd > 7) nsd = 7;
        uint32_t prc = (uint32_t)ceil(3.321928094887362 * (double)nsd) + 1;
        if (prc > 23) prc = 23;
        return prc;
    }
}

void ttzip_filter_bitgroom_float32_neon(
    const float* src,
    float* dst,
    size_t count,
    uint8_t nsd
) {
    if (!src || !dst || count == 0) return;

    uint32_t prc = ttzip_bitgroom_calc_mantissa_bits(nsd, false);
    if (prc >= 23) {
        if (src != dst) memcpy(dst, src, count * sizeof(float));
        return;
    }

    uint32_t n_discard = 23 - prc;
    uint32_t mask_shave = ~((1U << n_discard) - 1U);
    uint32_t mask_set = (1U << n_discard) - 1U;

    size_t i = 0;

#if defined(__ARM_NEON) || defined(__ARM_NEON__)
    // 4-element alternating mask [even, odd, even, odd]
    uint32x4_t v_mask_and = {mask_shave, 0xFFFFFFFFU, mask_shave, 0xFFFFFFFFU};
    uint32x4_t v_mask_or  = {0x00000000U, mask_set,    0x00000000U, mask_set};

    for (; i + 4 <= count; i += 4) {
        uint32x4_t vin = vld1q_u32((const uint32_t*)(src + i));
        uint32x4_t v_groomed = vorrq_u32(vandq_u32(vin, v_mask_and), v_mask_or);
        vst1q_u32((uint32_t*)(dst + i), v_groomed);
    }
#endif

    // Scalar tail
    const uint32_t* src_u32 = (const uint32_t*)src;
    uint32_t* dst_u32 = (uint32_t*)dst;
    for (; i < count; ++i) {
        if ((i & 1) == 0) {
            dst_u32[i] = src_u32[i] & mask_shave;
        } else {
            dst_u32[i] = src_u32[i] | mask_set;
        }
    }
}

void ttzip_filter_bitgroom_float64_neon(
    const double* src,
    double* dst,
    size_t count,
    uint8_t nsd
) {
    if (!src || !dst || count == 0) return;

    uint32_t prc = ttzip_bitgroom_calc_mantissa_bits(nsd, true);
    if (prc >= 52) {
        if (src != dst) memcpy(dst, src, count * sizeof(double));
        return;
    }

    uint32_t n_discard = 52 - prc;
    uint64_t mask_shave = ~((1ULL << n_discard) - 1ULL);
    uint64_t mask_set = (1ULL << n_discard) - 1ULL;

    size_t i = 0;

#if defined(__ARM_NEON) || defined(__ARM_NEON__)
    uint64x2_t v_mask_and = {mask_shave, 0xFFFFFFFFFFFFFFFFULL};
    uint64x2_t v_mask_or  = {0x0000000000000000ULL, mask_set};

    for (; i + 2 <= count; i += 2) {
        uint64x2_t vin = vld1q_u64((const uint64_t*)(src + i));
        uint64x2_t v_groomed = vorrq_u64(vandq_u64(vin, v_mask_and), v_mask_or);
        vst1q_u64((uint64_t*)(dst + i), v_groomed);
    }
#endif

    const uint64_t* src_u64 = (const uint64_t*)src;
    uint64_t* dst_u64 = (uint64_t*)dst;
    for (; i < count; ++i) {
        if ((i & 1) == 0) {
            dst_u64[i] = src_u64[i] & mask_shave;
        } else {
            dst_u64[i] = src_u64[i] | mask_set;
        }
    }
}

void ttzip_filter_bitround_float32_neon(
    const float* src,
    float* dst,
    size_t count,
    uint8_t nsd
) {
    if (!src || !dst || count == 0) return;

    uint32_t prc = ttzip_bitgroom_calc_mantissa_bits(nsd, false);
    if (prc >= 23) {
        if (src != dst) memcpy(dst, src, count * sizeof(float));
        return;
    }

    uint32_t n_discard = 23 - prc;
    uint32_t half_quantum = 1U << (n_discard - 1);
    uint32_t mask_shave = ~((1U << n_discard) - 1U);

    size_t i = 0;

#if defined(__ARM_NEON) || defined(__ARM_NEON__)
    uint32x4_t v_half = vdupq_n_u32(half_quantum);
    uint32x4_t v_mask = vdupq_n_u32(mask_shave);

    for (; i + 4 <= count; i += 4) {
        uint32x4_t vin = vld1q_u32((const uint32_t*)(src + i));
        uint32x4_t v_rounded = vandq_u32(vaddq_u32(vin, v_half), v_mask);
        vst1q_u32((uint32_t*)(dst + i), v_rounded);
    }
#endif

    const uint32_t* src_u32 = (const uint32_t*)src;
    uint32_t* dst_u32 = (uint32_t*)dst;
    for (; i < count; ++i) {
        dst_u32[i] = (src_u32[i] + half_quantum) & mask_shave;
    }
}
