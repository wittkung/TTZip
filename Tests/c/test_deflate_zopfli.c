/**
 * @file test_deflate_zopfli.c
 * @brief Unit tests for native Deflate, Zopfli iterative compression, and history dictionaries.
 * 
 * SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
 * Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>. All rights reserved.
 */

#include "ttzip_test_harness.h"
#include "ttzip_deflate_engine.h"
#include "ttzip_zopfli_engine.h"
#include "libdeflate.h"

TEST_CASE(test_deflate_fast_compress_and_decompress_roundtrip) {
    // Highly compressible repetitive buffer
    uint8_t src[16384];
    for (size_t i = 0; i < sizeof(src); ++i) {
        src[i] = (uint8_t)((i % 32) + 'A');
    }

    uint8_t comp_buf[32768];
    ttzip_native_deflate_options_t options;
    memset(&options, 0, sizeof(options));
    options.tier_level = 1;
    options.dynamic_huffman = true;

    size_t comp_size = ttzip_native_deflate_compress_block_with_history(
        src, sizeof(src),
        NULL, 0,
        comp_buf, sizeof(comp_buf),
        &options,
        true
    );

    ASSERT_TRUE(comp_size > 0);
    ASSERT_TRUE(comp_size < sizeof(src) / 2); // > 2x compression ratio

    // Decompress with libdeflate oracle decompressor to verify bitstream compliance
    struct libdeflate_decompressor* dec = libdeflate_alloc_decompressor();
    ASSERT_NOT_NULL(dec);

    uint8_t decomp_buf[sizeof(src)];
    size_t actual_out = 0;
    enum libdeflate_result res = libdeflate_deflate_decompress(
        dec,
        comp_buf, comp_size,
        decomp_buf, sizeof(decomp_buf),
        &actual_out
    );

    ASSERT_EQ(res, LIBDEFLATE_SUCCESS);
    ASSERT_EQ(actual_out, sizeof(src));
    ASSERT_MEM_EQ(decomp_buf, src, sizeof(src));

    libdeflate_free_decompressor(dec);
}

TEST_CASE(test_zopfli_compression_ratio_and_roundtrip) {
    uint8_t src[8192];
    for (size_t i = 0; i < sizeof(src); ++i) {
        src[i] = (uint8_t)("The quick brown fox jumps over the lazy dog."[i % 44]);
    }

    uint8_t comp_buf[16384];
    TTZipZopfliOptions options;
    ttzip_zopfli_init_options(&options, 6);

    size_t comp_size = ttzip_zopfli_compress_block_with_history(
        src, sizeof(src),
        NULL, 0,
        comp_buf, sizeof(comp_buf),
        &options,
        1
    );

    ASSERT_TRUE(comp_size > 0);
    ASSERT_TRUE(comp_size < sizeof(src) / 4); // > 4x compression ratio

    // Decompress & verify lossless equality
    struct libdeflate_decompressor* dec = libdeflate_alloc_decompressor();
    ASSERT_NOT_NULL(dec);

    uint8_t decomp_buf[sizeof(src)];
    size_t actual_out = 0;
    enum libdeflate_result res = libdeflate_deflate_decompress(
        dec,
        comp_buf, comp_size,
        decomp_buf, sizeof(decomp_buf),
        &actual_out
    );

    ASSERT_EQ(res, LIBDEFLATE_SUCCESS);
    ASSERT_EQ(actual_out, sizeof(src));
    ASSERT_MEM_EQ(decomp_buf, src, sizeof(src));

    libdeflate_free_decompressor(dec);
}

TEST_CASE(test_deflate_with_history_dictionary) {
    uint8_t history[1024];
    memset(history, 'X', sizeof(history));

    uint8_t src[512];
    memset(src, 'X', sizeof(src)); // Matches preceding history 100%

    uint8_t comp_buf[1024];
    ttzip_native_deflate_options_t options;
    memset(&options, 0, sizeof(options));
    options.tier_level = 2;
    options.dynamic_huffman = true;

    size_t comp_size = ttzip_native_deflate_compress_block_with_history(
        src, sizeof(src),
        history, sizeof(history),
        comp_buf, sizeof(comp_buf),
        &options,
        true
    );

    ASSERT_TRUE(comp_size > 0);
    ASSERT_TRUE(comp_size < 50); // Should compress down to tiny match reference
}

void run_deflate_zopfli_tests(void) {
    ttzip_test_init_suite("Deflate & Zopfli");
    RUN_TEST(test_deflate_fast_compress_and_decompress_roundtrip);
    RUN_TEST(test_zopfli_compression_ratio_and_roundtrip);
    RUN_TEST(test_deflate_with_history_dictionary);
    ttzip_test_finish_suite();
}
