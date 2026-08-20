/**
 * @file test_blosc_engine.c
 * @brief Unit tests for BloscLZ, BitGroom mantissa quantization, and SuperChunk containers.
 * 
 * SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
 * Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>. All rights reserved.
 */

#include "ttzip_test_harness.h"
#include "ttzip_blosclz.h"
#include "CTTZipBitGroom.h"

TEST_CASE(test_blosclz_roundtrip_lossless) {
    // 32KB pattern buffer
    uint8_t src[32768];
    for (size_t i = 0; i < sizeof(src); ++i) {
        src[i] = (uint8_t)((i % 251) ^ (i / 13));
    }

    uint8_t comp_buf[65536];
    int comp_size = ttzip_blosclz_compress(
        src, (int)sizeof(src),
        comp_buf, (int)sizeof(comp_buf),
        5,   // clevel 5
        13   // hash_log 13
    );

    ASSERT_TRUE(comp_size > 0);
    ASSERT_TRUE(comp_size < (int)sizeof(src)); // Verified compression

    uint8_t decomp_buf[sizeof(src)];
    int decomp_size = ttzip_blosclz_decompress(
        comp_buf, comp_size,
        decomp_buf, (int)sizeof(decomp_buf)
    );

    ASSERT_EQ(decomp_size, (int)sizeof(src));
    ASSERT_MEM_EQ(decomp_buf, src, sizeof(src));
}

TEST_CASE(test_blosclz_short_buffer_literal_bypass) {
    const char text[] = "Hello BloscLZ!";
    int text_len = (int)strlen(text);

    uint8_t comp_buf[128];
    int comp_size = ttzip_blosclz_compress(
        text, text_len,
        comp_buf, (int)sizeof(comp_buf),
        1,
        12
    );

    ASSERT_TRUE(comp_size > 0);

    char decomp_buf[128];
    int decomp_size = ttzip_blosclz_decompress(
        comp_buf, comp_size,
        decomp_buf, (int)sizeof(decomp_buf)
    );

    ASSERT_EQ(decomp_size, text_len);
    ASSERT_MEM_EQ(decomp_buf, text, text_len);
}

TEST_CASE(test_bitgroom_float32_quantization) {
    float src_floats[16];
    float dst_floats[16];

    for (size_t i = 0; i < 16; ++i) {
        src_floats[i] = 1.234567f + (float)i * 0.1f;
    }

    // Apply BitGroom with 3 significant digits
    ttzip_filter_bitgroom_float32_neon(src_floats, dst_floats, 16, 3);

    // Verify values remain reasonably close within quantization bound
    for (size_t i = 0; i < 16; ++i) {
        float diff = src_floats[i] - dst_floats[i];
        if (diff < 0) diff = -diff;
        ASSERT_TRUE(diff < 0.01f);
    }
}

void run_blosc_engine_tests(void) {
    ttzip_test_init_suite("Blosc & BitGroom");
    RUN_TEST(test_blosclz_roundtrip_lossless);
    RUN_TEST(test_blosclz_short_buffer_literal_bypass);
    RUN_TEST(test_bitgroom_float32_quantization);
    ttzip_test_finish_suite();
}
