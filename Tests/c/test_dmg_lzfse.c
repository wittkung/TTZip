/**
 * @file test_dmg_lzfse.c
 * @brief Unit tests for Apple DMG UDIF demuxing and LZFSE decompression.
 * 
 * SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
 * Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>. All rights reserved.
 */

#include "ttzip_test_harness.h"
#include "CTTZipBridge_LZFSE.h"
#include "ttzip_dmg_demux.h"

TEST_CASE(test_lzfse_compress_and_decompress_roundtrip) {
    ASSERT_TRUE(ttzip_lzfse_is_available());

    uint8_t src[16384];
    for (size_t i = 0; i < sizeof(src); ++i) {
        src[i] = (uint8_t)("Apple Silicon LZFSE High-Performance Compression."[i % 49]);
    }

    uint8_t comp_buf[32768];
    size_t comp_size = ttzip_lzfse_compress(src, sizeof(src), comp_buf, sizeof(comp_buf));
    ASSERT_TRUE(comp_size > 0);
    ASSERT_TRUE(comp_size < sizeof(src) / 2); // > 2x ratio

    uint8_t decomp_buf[sizeof(src)];
    size_t decomp_size = ttzip_lzfse_decompress(comp_buf, comp_size, decomp_buf, sizeof(decomp_buf));
    ASSERT_EQ(decomp_size, sizeof(src));
    ASSERT_MEM_EQ(decomp_buf, src, sizeof(src));
}

TEST_CASE(test_lzfse_small_buffer_roundtrip) {
    const char text[] = "Short LZFSE String";
    size_t len = strlen(text);

    uint8_t comp_buf[128];
    size_t comp_size = ttzip_lzfse_compress(text, len, comp_buf, sizeof(comp_buf));
    ASSERT_TRUE(comp_size > 0);

    char decomp_buf[128];
    size_t decomp_size = ttzip_lzfse_decompress(comp_buf, comp_size, decomp_buf, sizeof(decomp_buf));
    ASSERT_EQ(decomp_size, len);
    ASSERT_MEM_EQ(decomp_buf, text, len);
}

void run_dmg_lzfse_tests(void) {
    ttzip_test_init_suite("DMG & LZFSE");
    RUN_TEST(test_lzfse_compress_and_decompress_roundtrip);
    RUN_TEST(test_lzfse_small_buffer_roundtrip);
    ttzip_test_finish_suite();
}
