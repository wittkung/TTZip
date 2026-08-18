// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/CTTZipCRC32Neon.h"

#include <string.h>
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#if defined(__ARM_NEON) || defined(__aarch64__)
#include <arm_neon.h>
#include <arm_acle.h>
#endif

#include <libdeflate.h>

/* ============================================================================
 * 1. ARM64 PMULL 12-Way & 4-Way Vector Folding Implementation (> 65 GB/s)
 * ============================================================================ */

#if defined(__aarch64__) && (defined(__APPLE__) || defined(__ARM_NEON))

#if defined(__clang__)
#define TTZIP_TARGET_PMULL_CRC __attribute__((target("aes,crc,sha3")))
#elif defined(__GNUC__)
#define TTZIP_TARGET_PMULL_CRC __attribute__((target("+crypto,+crc,+sha3")))
#else
#define TTZIP_TARGET_PMULL_CRC
#endif

#define CRC32_X1567_MODG 0x596c8d81ULL
#define CRC32_X1503_MODG 0xf5e48c85ULL
#define CRC32_X799_MODG  0xdf068dc2ULL
#define CRC32_X735_MODG  0x57c54819ULL
#define CRC32_X543_MODG  0x8f352d95ULL
#define CRC32_X479_MODG  0x1d9513d7ULL
#define CRC32_X415_MODG  0x3db1ecdcULL
#define CRC32_X351_MODG  0xaf449247ULL
#define CRC32_X287_MODG  0xf1da05aaULL
#define CRC32_X223_MODG  0x81256527ULL
#define CRC32_X159_MODG  0xae689191ULL
#define CRC32_X95_MODG   0xccaa009eULL

static inline TTZIP_TARGET_PMULL_CRC uint8x16_t ttzip_u32_to_bytevec(uint32_t a) {
    return vreinterpretq_u8_u32(vsetq_lane_u32(a, vdupq_n_u32(0), 0));
}

static inline TTZIP_TARGET_PMULL_CRC poly64x2_t ttzip_load_multipliers(const uint64_t p[2]) {
    return vreinterpretq_p64_u64(vld1q_u64(p));
}

static inline TTZIP_TARGET_PMULL_CRC uint8x16_t ttzip_clmul_low(uint8x16_t a, poly64x2_t b) {
    return vreinterpretq_u8_p128(vmull_p64(vgetq_lane_p64(vreinterpretq_p64_u8(a), 0),
                                           vgetq_lane_p64(b, 0)));
}

static inline TTZIP_TARGET_PMULL_CRC uint8x16_t ttzip_clmul_high(uint8x16_t a, poly64x2_t b) {
#if defined(__clang__)
    uint8x16_t res;
    __asm__("pmull2 %0.1q, %1.2d, %2.2d" : "=w" (res) : "w" (a), "w" (b));
    return res;
#else
    return vreinterpretq_u8_p128(vmull_high_p64(vreinterpretq_p64_u8(a), b));
#endif
}

static inline TTZIP_TARGET_PMULL_CRC uint8x16_t ttzip_eor3(uint8x16_t a, uint8x16_t b, uint8x16_t c) {
    return veor3q_u8(a, b, c);
}

static inline TTZIP_TARGET_PMULL_CRC uint8x16_t ttzip_fold_vec(uint8x16_t cur, uint8x16_t next, poly64x2_t mult) {
    return ttzip_eor3(next, ttzip_clmul_low(cur, mult), ttzip_clmul_high(cur, mult));
}

static inline uint16_t ttzip_get_unaligned_le16(const uint8_t *p) {
    uint16_t v;
    memcpy(&v, p, sizeof(v));
    return v;
}

static inline uint32_t ttzip_get_unaligned_le32(const uint8_t *p) {
    uint32_t v;
    memcpy(&v, p, sizeof(v));
    return v;
}

static inline uint64_t ttzip_get_unaligned_le64(const uint8_t *p) {
    uint64_t v;
    memcpy(&v, p, sizeof(v));
    return v;
}

TTZIP_TARGET_PMULL_CRC
static uint32_t ttzip_crc32_arm_pmull_raw(uint32_t crc, const uint8_t *p, size_t len) {
    uint8x16_t v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11;

    if (len < 3 * 192) {
        static const uint64_t __attribute__((aligned(16))) mults[3][2] = {
            { CRC32_X543_MODG, CRC32_X479_MODG }, /* 4 vecs */
            { CRC32_X287_MODG, CRC32_X223_MODG }, /* 2 vecs */
            { CRC32_X159_MODG, CRC32_X95_MODG },  /* 1 vecs */
        };
        poly64x2_t multipliers_4, multipliers_2, multipliers_1;

        if (len < 64) {
            goto tail;
        }

        multipliers_4 = ttzip_load_multipliers(mults[0]);
        multipliers_2 = ttzip_load_multipliers(mults[1]);
        multipliers_1 = ttzip_load_multipliers(mults[2]);

        v0 = veorq_u8(vld1q_u8(p + 0), ttzip_u32_to_bytevec(crc));
        v1 = vld1q_u8(p + 16);
        v2 = vld1q_u8(p + 32);
        v3 = vld1q_u8(p + 48);
        p += 64;
        len -= 64;

        while (len >= 64) {
            v0 = ttzip_fold_vec(v0, vld1q_u8(p + 0), multipliers_4);
            v1 = ttzip_fold_vec(v1, vld1q_u8(p + 16), multipliers_4);
            v2 = ttzip_fold_vec(v2, vld1q_u8(p + 32), multipliers_4);
            v3 = ttzip_fold_vec(v3, vld1q_u8(p + 48), multipliers_4);
            p += 64;
            len -= 64;
        }

        v0 = ttzip_fold_vec(v0, v2, multipliers_2);
        v1 = ttzip_fold_vec(v1, v3, multipliers_2);
        if (len >= 32) {
            v0 = ttzip_fold_vec(v0, vld1q_u8(p + 0), multipliers_2);
            v1 = ttzip_fold_vec(v1, vld1q_u8(p + 16), multipliers_2);
            p += 32;
            len -= 32;
        }
        v0 = ttzip_fold_vec(v0, v1, multipliers_1);
    } else {
        static const uint64_t __attribute__((aligned(16))) mults[4][2] = {
            { CRC32_X1567_MODG, CRC32_X1503_MODG }, /* 12 vecs */
            { CRC32_X799_MODG,  CRC32_X735_MODG  }, /* 6 vecs  */
            { CRC32_X415_MODG,  CRC32_X351_MODG  }, /* 3 vecs  */
            { CRC32_X159_MODG,  CRC32_X95_MODG   }, /* 1 vecs  */
        };
        const poly64x2_t multipliers_12 = ttzip_load_multipliers(mults[0]);
        const poly64x2_t multipliers_6  = ttzip_load_multipliers(mults[1]);
        const poly64x2_t multipliers_3  = ttzip_load_multipliers(mults[2]);
        const poly64x2_t multipliers_1  = ttzip_load_multipliers(mults[3]);
        const size_t align = -(uintptr_t)p & 15;
        const uint8x16_t *vp;

        /* Align p to the next 16-byte boundary */
        if (align) {
            if (align & 1) {
                crc = __crc32b(crc, *p++);
            }
            if (align & 2) {
                crc = __crc32h(crc, ttzip_get_unaligned_le16(p));
                p += 2;
            }
            if (align & 4) {
                crc = __crc32w(crc, ttzip_get_unaligned_le32(p));
                p += 4;
            }
            if (align & 8) {
                crc = __crc32d(crc, ttzip_get_unaligned_le64(p));
                p += 8;
            }
            len -= align;
        }

        vp = (const uint8x16_t *)p;
        v0 = veorq_u8(*vp++, ttzip_u32_to_bytevec(crc));
        v1 = *vp++;
        v2 = *vp++;
        v3 = *vp++;
        v4 = *vp++;
        v5 = *vp++;
        v6 = *vp++;
        v7 = *vp++;
        v8 = *vp++;
        v9 = *vp++;
        v10 = *vp++;
        v11 = *vp++;
        len -= 192;

        /* Fold 192 bytes (12 vectors) at a time */
        while (len >= 192) {
            v0 = ttzip_fold_vec(v0, *vp++, multipliers_12);
            v1 = ttzip_fold_vec(v1, *vp++, multipliers_12);
            v2 = ttzip_fold_vec(v2, *vp++, multipliers_12);
            v3 = ttzip_fold_vec(v3, *vp++, multipliers_12);
            v4 = ttzip_fold_vec(v4, *vp++, multipliers_12);
            v5 = ttzip_fold_vec(v5, *vp++, multipliers_12);
            v6 = ttzip_fold_vec(v6, *vp++, multipliers_12);
            v7 = ttzip_fold_vec(v7, *vp++, multipliers_12);
            v8 = ttzip_fold_vec(v8, *vp++, multipliers_12);
            v9 = ttzip_fold_vec(v9, *vp++, multipliers_12);
            v10 = ttzip_fold_vec(v10, *vp++, multipliers_12);
            v11 = ttzip_fold_vec(v11, *vp++, multipliers_12);
            len -= 192;
        }

        /* Fold v0-v11 down to v0 */
        v0 = ttzip_fold_vec(v0, v6, multipliers_6);
        v1 = ttzip_fold_vec(v1, v7, multipliers_6);
        v2 = ttzip_fold_vec(v2, v8, multipliers_6);
        v3 = ttzip_fold_vec(v3, v9, multipliers_6);
        v4 = ttzip_fold_vec(v4, v10, multipliers_6);
        v5 = ttzip_fold_vec(v5, v11, multipliers_6);

        if (len >= 96) {
            v0 = ttzip_fold_vec(v0, *vp++, multipliers_6);
            v1 = ttzip_fold_vec(v1, *vp++, multipliers_6);
            v2 = ttzip_fold_vec(v2, *vp++, multipliers_6);
            v3 = ttzip_fold_vec(v3, *vp++, multipliers_6);
            v4 = ttzip_fold_vec(v4, *vp++, multipliers_6);
            v5 = ttzip_fold_vec(v5, *vp++, multipliers_6);
            len -= 96;
        }

        v0 = ttzip_fold_vec(v0, v3, multipliers_3);
        v1 = ttzip_fold_vec(v1, v4, multipliers_3);
        v2 = ttzip_fold_vec(v2, v5, multipliers_3);

        if (len >= 48) {
            v0 = ttzip_fold_vec(v0, *vp++, multipliers_3);
            v1 = ttzip_fold_vec(v1, *vp++, multipliers_3);
            v2 = ttzip_fold_vec(v2, *vp++, multipliers_3);
            len -= 48;
        }

        v0 = ttzip_fold_vec(v0, v1, multipliers_1);
        v0 = ttzip_fold_vec(v0, v2, multipliers_1);
        p = (const uint8_t *)vp;
    }

    /* Reduce 128-bit vector v0 to 32-bit CRC using ARMv8-A hardware CRC32 instructions */
    crc = __crc32d(0, vgetq_lane_u64(vreinterpretq_u64_u8(v0), 0));
    crc = __crc32d(crc, vgetq_lane_u64(vreinterpretq_u64_u8(v0), 1));

tail:
    /* Finish remainder bytes using ARMv8-A CRC32 instructions */
    if (len & 32) {
        crc = __crc32d(crc, ttzip_get_unaligned_le64(p + 0));
        crc = __crc32d(crc, ttzip_get_unaligned_le64(p + 8));
        crc = __crc32d(crc, ttzip_get_unaligned_le64(p + 16));
        crc = __crc32d(crc, ttzip_get_unaligned_le64(p + 24));
        p += 32;
    }
    if (len & 16) {
        crc = __crc32d(crc, ttzip_get_unaligned_le64(p + 0));
        crc = __crc32d(crc, ttzip_get_unaligned_le64(p + 8));
        p += 16;
    }
    if (len & 8) {
        crc = __crc32d(crc, ttzip_get_unaligned_le64(p));
        p += 8;
    }
    if (len & 4) {
        crc = __crc32w(crc, ttzip_get_unaligned_le32(p));
        p += 4;
    }
    if (len & 2) {
        crc = __crc32h(crc, ttzip_get_unaligned_le16(p));
        p += 2;
    }
    if (len & 1) {
        crc = __crc32b(crc, *p);
    }

    return crc;
}

uint32_t ttzip_crc32_pmull_wide(uint32_t crc, const uint8_t *p, size_t len) {
    if (__builtin_expect(!p || len == 0, 0)) {
        return crc;
    }
    return ~ttzip_crc32_arm_pmull_raw(~crc, p, len);
}

#endif /* defined(__aarch64__) */

/* ============================================================================
 * 2. Scalar Reference & Auto-Dispatch Interfaces
 * ============================================================================ */

uint32_t ttzip_crc32_scalar(uint32_t crc, const uint8_t* buf, size_t len) {
    if (!buf || len == 0) return crc;
    return libdeflate_crc32(crc, buf, len);
}

uint32_t ttzip_core_crc32_neon_single(uint32_t crc, const uint8_t* buf, size_t len) {
#if defined(__aarch64__) && (defined(__APPLE__) || defined(__ARM_NEON))
    return ttzip_crc32_pmull_wide(crc, buf, len);
#else
    return ttzip_crc32_scalar(crc, buf, len);
#endif
}

uint32_t ttzip_crc32_fast(uint32_t crc, const uint8_t* data, size_t len) {
    return ttzip_core_crc32_neon_single(crc, data, len);
}
