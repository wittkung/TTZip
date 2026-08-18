// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/CTTZipChecksum.h"
#include "include/ttzip_platform.h"
#include <libdeflate.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>

#define TTZIP_ADLER32_DIVISOR       65521U
#define TTZIP_ADLER32_MAX_CHUNK     5552U

#define TTZIP_MIN(a, b) ((a) < (b) ? (a) : (b))

/* ============================================================================
 * 1. 标量 Fallback 算法 (4 字节代数展开 + 5552 字节延迟取模)
 *
 * 数学证明 (Proof of NMAX = 5552):
 * 设块长度 M = 4K。在每个 4 字节迭代中：
 *   Δs1 = p0 + p1 + p2 + p3
 *   Δs2 = 4*s1_old + 4*p0 + 3*p1 + 2*p2 + p3
 * 在最坏输入条件 (d_i = 255, s1_0 = s2_0 = 65520) 下：
 *   s2(M) = [255*M^2 + 386610*M + 131040] / 2 <= UINT32_MAX
 * 解得 M <= 5552.41。取 M = 5552 时 s2(5552) = 4,294,690,200 < 2^32-1，保证绝不溢出。
 * ============================================================================ */
#define TTZIP_ADLER32_SCALAR_CHUNK(s1, s2, p, n)                            \
do {                                                                        \
    if ((n) >= 4) {                                                         \
        uint32_t s1_sum = 0;                                                \
        uint32_t b0_sum = 0, b1_sum = 0, b2_sum = 0, b3_sum = 0;           \
        do {                                                                \
            s1_sum += (s1);                                                 \
            (s1) += (uint32_t)(p)[0] + (p)[1] + (p)[2] + (p)[3];            \
            b0_sum += (p)[0];                                               \
            b1_sum += (p)[1];                                               \
            b2_sum += (p)[2];                                               \
            b3_sum += (p)[3];                                               \
            (p) += 4;                                                       \
            (n) -= 4;                                                       \
        } while ((n) >= 4);                                                 \
        (s2) += (4 * (s1_sum + b0_sum)) + (3 * b1_sum) +                    \
                (2 * b2_sum) + b3_sum;                                      \
    }                                                                       \
    for (; (n) > 0; (n)--, (p)++) {                                         \
        (s1) += *(p);                                                       \
        (s2) += (s1);                                                       \
    }                                                                       \
    (s1) %= TTZIP_ADLER32_DIVISOR;                                          \
    (s2) %= TTZIP_ADLER32_DIVISOR;                                          \
} while (0)

static inline uint32_t ttzip_adler32_scalar(uint32_t adler, const uint8_t *p, size_t len) {
    uint32_t s1 = adler & 0xFFFFU;
    uint32_t s2 = adler >> 16;

    while (len > 0) {
        size_t n = TTZIP_MIN(len, (size_t)(TTZIP_ADLER32_MAX_CHUNK & ~3U));
        len -= n;
        TTZIP_ADLER32_SCALAR_CHUNK(s1, s2, p, n);
    }
    return (s2 << 16) | s1;
}

/* ============================================================================
 * 2. ARM64 NEON & DotProd 实现 (Apple Silicon 25~30+ GB/s)
 * ============================================================================ */
#if defined(__ARM_NEON) || defined(__aarch64__)
#include <arm_neon.h>

#if defined(__ARM_FEATURE_DOTPROD) || defined(__APPLE__)
#if defined(__clang__)
__attribute__((target("dotprod")))
#elif defined(__GNUC__)
__attribute__((target("+dotprod")))
#endif
static uint32_t ttzip_adler32_neon_dotprod(uint32_t adler, const uint8_t *p, size_t len) {
    static const uint8_t __attribute__((aligned(16))) mults[64] = {
        64, 63, 62, 61, 60, 59, 58, 57, 56, 55, 54, 53, 52, 51, 50, 49,
        48, 47, 46, 45, 44, 43, 42, 41, 40, 39, 38, 37, 36, 35, 34, 33,
        32, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17,
        16, 15, 14, 13, 12, 11, 10,  9,  8,  7,  6,  5,  4,  3,  2,  1,
    };
    const uint8x16_t mults_a = vld1q_u8(&mults[0]);
    const uint8x16_t mults_b = vld1q_u8(&mults[16]);
    const uint8x16_t mults_c = vld1q_u8(&mults[32]);
    const uint8x16_t mults_d = vld1q_u8(&mults[48]);
    const uint8x16_t ones    = vdupq_n_u8(1);

    uint32_t s1 = adler & 0xFFFFU;
    uint32_t s2 = adler >> 16;

    if (len > 32768 && ((uintptr_t)p & 15)) {
        do {
            s1 += *p++;
            s2 += s1;
            len--;
        } while ((uintptr_t)p & 15);
        s1 %= TTZIP_ADLER32_DIVISOR;
        s2 %= TTZIP_ADLER32_DIVISOR;
    }

    while (len > 0) {
        size_t n = TTZIP_MIN(len, (size_t)(TTZIP_ADLER32_MAX_CHUNK & ~63U));
        len -= n;

        if (n >= 64) {
            uint32x4_t v_s1_a = vdupq_n_u32(0);
            uint32x4_t v_s1_b = vdupq_n_u32(0);
            uint32x4_t v_s1_c = vdupq_n_u32(0);
            uint32x4_t v_s1_d = vdupq_n_u32(0);

            uint32x4_t v_s2_a = vdupq_n_u32(0);
            uint32x4_t v_s2_b = vdupq_n_u32(0);
            uint32x4_t v_s2_c = vdupq_n_u32(0);
            uint32x4_t v_s2_d = vdupq_n_u32(0);

            uint32x4_t v_s1_sums_a = vdupq_n_u32(0);
            uint32x4_t v_s1_sums_b = vdupq_n_u32(0);
            uint32x4_t v_s1_sums_c = vdupq_n_u32(0);
            uint32x4_t v_s1_sums_d = vdupq_n_u32(0);

            s2 += s1 * (uint32_t)(n & ~63U);

            do {
                const uint8x16_t data_a = vld1q_u8(p + 0);
                const uint8x16_t data_b = vld1q_u8(p + 16);
                const uint8x16_t data_c = vld1q_u8(p + 32);
                const uint8x16_t data_d = vld1q_u8(p + 48);

                v_s1_sums_a = vaddq_u32(v_s1_sums_a, v_s1_a);
                v_s1_a = vdotq_u32(v_s1_a, data_a, ones);
                v_s2_a = vdotq_u32(v_s2_a, data_a, mults_a);

                v_s1_sums_b = vaddq_u32(v_s1_sums_b, v_s1_b);
                v_s1_b = vdotq_u32(v_s1_b, data_b, ones);
                v_s2_b = vdotq_u32(v_s2_b, data_b, mults_b);

                v_s1_sums_c = vaddq_u32(v_s1_sums_c, v_s1_c);
                v_s1_c = vdotq_u32(v_s1_c, data_c, ones);
                v_s2_c = vdotq_u32(v_s2_c, data_c, mults_c);

                v_s1_sums_d = vaddq_u32(v_s1_sums_d, v_s1_d);
                v_s1_d = vdotq_u32(v_s1_d, data_d, ones);
                v_s2_d = vdotq_u32(v_s2_d, data_d, mults_d);

                p += 64;
                n -= 64;
            } while (n >= 64);

            uint32x4_t v_s1 = vaddq_u32(vaddq_u32(v_s1_a, v_s1_b),
                                        vaddq_u32(v_s1_c, v_s1_d));
            uint32x4_t v_s2 = vaddq_u32(vaddq_u32(v_s2_a, v_s2_b),
                                        vaddq_u32(v_s2_c, v_s2_d));
            uint32x4_t v_s1_sums = vaddq_u32(vaddq_u32(v_s1_sums_a, v_s1_sums_b),
                                             vaddq_u32(v_s1_sums_c, v_s1_sums_d));

            v_s2 = vaddq_u32(v_s2, vqshlq_n_u32(v_s1_sums, 6));

            s1 += vaddvq_u32(v_s1);
            s2 += vaddvq_u32(v_s2);
        }

        TTZIP_ADLER32_SCALAR_CHUNK(s1, s2, p, n);
    }
    return (s2 << 16) | s1;
}
#endif // DOTPROD

static uint32_t ttzip_adler32_neon_baseline(uint32_t adler, const uint8_t *p, size_t len) {
    static const uint16_t __attribute__((aligned(16))) mults[64] = {
        64, 63, 62, 61, 60, 59, 58, 57, 56, 55, 54, 53, 52, 51, 50, 49,
        48, 47, 46, 45, 44, 43, 42, 41, 40, 39, 38, 37, 36, 35, 34, 33,
        32, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17,
        16, 15, 14, 13, 12, 11, 10,  9,  8,  7,  6,  5,  4,  3,  2,  1,
    };
    const uint16x8_t mults_a = vld1q_u16(&mults[0]);
    const uint16x8_t mults_b = vld1q_u16(&mults[8]);
    const uint16x8_t mults_c = vld1q_u16(&mults[16]);
    const uint16x8_t mults_d = vld1q_u16(&mults[24]);
    const uint16x8_t mults_e = vld1q_u16(&mults[32]);
    const uint16x8_t mults_f = vld1q_u16(&mults[40]);
    const uint16x8_t mults_g = vld1q_u16(&mults[48]);
    const uint16x8_t mults_h = vld1q_u16(&mults[56]);

    uint32_t s1 = adler & 0xFFFFU;
    uint32_t s2 = adler >> 16;

    while (len > 0) {
        size_t n = TTZIP_MIN(len, (size_t)(TTZIP_ADLER32_MAX_CHUNK & ~63U));
        len -= n;

        if (n >= 64) {
            uint32x4_t v_s1 = vdupq_n_u32(0);
            uint32x4_t v_s2 = vdupq_n_u32(0);

            uint16x8_t bsum_a = vdupq_n_u16(0), bsum_b = vdupq_n_u16(0);
            uint16x8_t bsum_c = vdupq_n_u16(0), bsum_d = vdupq_n_u16(0);
            uint16x8_t bsum_e = vdupq_n_u16(0), bsum_f = vdupq_n_u16(0);
            uint16x8_t bsum_g = vdupq_n_u16(0), bsum_h = vdupq_n_u16(0);

            s2 += s1 * (uint32_t)(n & ~63U);

            do {
                const uint8x16_t data_a = vld1q_u8(p + 0);
                const uint8x16_t data_b = vld1q_u8(p + 16);
                const uint8x16_t data_c = vld1q_u8(p + 32);
                const uint8x16_t data_d = vld1q_u8(p + 48);

                v_s2 = vaddq_u32(v_s2, v_s1);

                uint16x8_t tmp = vpaddlq_u8(data_a);
                bsum_a = vaddw_u8(bsum_a, vget_low_u8(data_a));
                bsum_b = vaddw_u8(bsum_b, vget_high_u8(data_a));

                tmp = vpadalq_u8(tmp, data_b);
                bsum_c = vaddw_u8(bsum_c, vget_low_u8(data_b));
                bsum_d = vaddw_u8(bsum_d, vget_high_u8(data_b));

                tmp = vpadalq_u8(tmp, data_c);
                bsum_e = vaddw_u8(bsum_e, vget_low_u8(data_c));
                bsum_f = vaddw_u8(bsum_f, vget_high_u8(data_c));

                tmp = vpadalq_u8(tmp, data_d);
                bsum_g = vaddw_u8(bsum_g, vget_low_u8(data_d));
                bsum_h = vaddw_u8(bsum_h, vget_high_u8(data_d));

                v_s1 = vpadalq_u16(v_s1, tmp);

                p += 64;
                n -= 64;
            } while (n >= 64);

            v_s2 = vqshlq_n_u32(v_s2, 6);
            v_s2 = vmlal_u16(v_s2, vget_low_u16(bsum_a), vget_low_u16(mults_a));
            v_s2 = vmlal_high_u16(v_s2, bsum_a, mults_a);
            v_s2 = vmlal_u16(v_s2, vget_low_u16(bsum_b), vget_low_u16(mults_b));
            v_s2 = vmlal_high_u16(v_s2, bsum_b, mults_b);
            v_s2 = vmlal_u16(v_s2, vget_low_u16(bsum_c), vget_low_u16(mults_c));
            v_s2 = vmlal_high_u16(v_s2, bsum_c, mults_c);
            v_s2 = vmlal_u16(v_s2, vget_low_u16(bsum_d), vget_low_u16(mults_d));
            v_s2 = vmlal_high_u16(v_s2, bsum_d, mults_d);
            v_s2 = vmlal_u16(v_s2, vget_low_u16(bsum_e), vget_low_u16(mults_e));
            v_s2 = vmlal_high_u16(v_s2, bsum_e, mults_e);
            v_s2 = vmlal_u16(v_s2, vget_low_u16(bsum_f), vget_low_u16(mults_f));
            v_s2 = vmlal_high_u16(v_s2, bsum_f, mults_f);
            v_s2 = vmlal_u16(v_s2, vget_low_u16(bsum_g), vget_low_u16(mults_g));
            v_s2 = vmlal_high_u16(v_s2, bsum_g, mults_g);
            v_s2 = vmlal_u16(v_s2, vget_low_u16(bsum_h), vget_low_u16(mults_h));
            v_s2 = vmlal_high_u16(v_s2, bsum_h, mults_h);

            s1 += vaddvq_u32(v_s1);
            s2 += vaddvq_u32(v_s2);
        }

        TTZIP_ADLER32_SCALAR_CHUNK(s1, s2, p, n);
    }
    return (s2 << 16) | s1;
}
#endif // ARM_NEON

/* ============================================================================
 * 3. 统一跨平台对外 API 入口 (T005)
 * ============================================================================ */
uint32_t ttzip_adler32_fast(uint32_t adler, const uint8_t *data, size_t len) {
    if (data == NULL || len == 0) {
        return (data == NULL) ? 1U : adler;
    }

#if defined(__ARM_NEON) || defined(__aarch64__)
#  if defined(__ARM_FEATURE_DOTPROD) || defined(__APPLE__)
    return ttzip_adler32_neon_dotprod(adler, data, len);
#  else
    return ttzip_adler32_neon_baseline(adler, data, len);
#  endif
#else
    return ttzip_adler32_scalar(adler, data, len);
#endif
}

uint32_t ttzip_crc32_fast(uint32_t crc, const uint8_t *data, size_t len) {
    if (data == NULL || len == 0) return crc;
    return libdeflate_crc32(crc, data, len);
}
