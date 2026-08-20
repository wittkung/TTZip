/**
 * @file test_adler_crc64.c
 * @brief Unit tests for Adler-32 NEON SIMD and CRC64-XZ hardware/scalar vector oracles.
 * 
 * SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
 * Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>. All rights reserved.
 */

#include "ttzip_test_harness.h"
#include "CTTZipChecksum.h"
#include "ttzip_crc64.h"

TEST_CASE(test_adler32_golden_vectors) {
    // 1. Empty buffer -> initial Adler 1
    uint32_t adler_empty = ttzip_adler32_fast(1, NULL, 0);
    ASSERT_EQ(adler_empty, 1U);

    // 2. RFC 1950 golden vector "123456789" -> 0x091E01DE (152961502)
    const uint8_t vec1[] = "123456789";
    uint32_t adler1 = ttzip_adler32_fast(1, vec1, 9);
    ASSERT_EQ(adler1, 0x091E01DEU);

    // 3. Single byte 'a' (0x61 = 97) -> s1 = 1 + 97 = 98, s2 = 98 -> (98 << 16) | 98 = 0x00620062
    const uint8_t vec2[] = "a";
    uint32_t adler2 = ttzip_adler32_fast(1, vec2, 1);
    ASSERT_EQ(adler2, 0x00620062U);
}

TEST_CASE(test_adler32_modulo_boundary_overflow) {
    // NMAX = 5552 bytes; test buffer of 8192 bytes filled with 0xFF to stress deferred modulo reduction
    uint8_t large_buf[8192];
    memset(large_buf, 0xFF, sizeof(large_buf));

    uint32_t adler_neon = ttzip_adler32_fast(1, large_buf, sizeof(large_buf));
    ASSERT_TRUE(adler_neon != 0);

    // Cumulative streaming vs one-shot parity
    uint32_t adler_chunk1 = ttzip_adler32_fast(1, large_buf, 4000);
    uint32_t adler_stream = ttzip_adler32_fast(adler_chunk1, large_buf + 4000, 4192);
    ASSERT_EQ(adler_stream, adler_neon);
}

TEST_CASE(test_crc64_xz_differential_oracle) {
    // Test across misaligned buffers and length sweeps
    uint8_t raw[1024];
    for (size_t i = 0; i < sizeof(raw); ++i) {
        raw[i] = (uint8_t)((i * 37 + 11) & 0xFF);
    }

    for (size_t len = 0; len <= 256; len += 7) {
        for (size_t align = 0; align < 16; ++align) {
            uint64_t crc_fast = ttzip_crc64(raw + align, len, 0);
            uint64_t crc_scalar = ttzip_crc64_scalar(raw + align, len, 0);
            ASSERT_EQ(crc_fast, crc_scalar);
        }
    }
}

void run_adler_crc64_tests(void) {
    ttzip_test_init_suite("Adler-32 & CRC64-XZ");
    RUN_TEST(test_adler32_golden_vectors);
    RUN_TEST(test_adler32_modulo_boundary_overflow);
    RUN_TEST(test_crc64_xz_differential_oracle);
    ttzip_test_finish_suite();
}
