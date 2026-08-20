/**
 * @file test_deflate_stream_coder.c
 * @brief Unit tests for Unified Streaming Compression Codecs (Deflate, Bzip2, Raw Blocks with Dict).
 * 
 * SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
 * Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>. All rights reserved.
 */

#include "ttzip_test_harness.h"
#include "CTTZipStreamCoder.h"

TEST_CASE(test_unified_libdeflate_roundtrip) {
    uint8_t raw[65536];
    for (size_t i = 0; i < sizeof(raw); ++i) {
        raw[i] = (uint8_t)(i % 251);
    }

    uint8_t comp[65536 * 2];
    uint8_t decomp[65536];

    for (int lvl = 1; lvl <= 9; lvl += 4) {
        size_t csize = ttzip_libdeflate_compress(raw, sizeof(raw), comp, sizeof(comp), lvl);
        ASSERT_TRUE(csize > 0 && csize < sizeof(raw));

        size_t dsize = ttzip_libdeflate_decompress(comp, csize, decomp, sizeof(decomp));
        ASSERT_EQ(dsize, sizeof(raw));
        ASSERT_MEM_EQ(decomp, raw, sizeof(raw));
    }
}

TEST_CASE(test_unified_bzip2_roundtrip) {
    uint8_t raw[32768];
    for (size_t i = 0; i < sizeof(raw); ++i) {
        raw[i] = (uint8_t)(i % 127);
    }

    uint8_t comp[32768 * 2];
    uint8_t decomp[32768];

    size_t csize = ttzip_bzip2_compress(raw, sizeof(raw), comp, sizeof(comp), 9);
    ASSERT_TRUE(csize > 0);

    size_t dsize = ttzip_bzip2_decompress(comp, csize, decomp, sizeof(decomp));
    ASSERT_EQ(dsize, sizeof(raw));
    ASSERT_MEM_EQ(decomp, raw, sizeof(raw));
}

TEST_CASE(test_raw_deflate_block_with_dict) {
    uint8_t dict[32768];
    for (size_t i = 0; i < sizeof(dict); ++i) {
        dict[i] = (uint8_t)(i & 0xFF);
    }

    // Payload repeats pattern from dictionary
    uint8_t payload[16384];
    memcpy(payload, dict, sizeof(payload));

    uint8_t comp[32768];
    size_t csize = ttzip_raw_deflate_block_compress_with_dict(
        payload, sizeof(payload),
        dict, sizeof(dict),
        comp, sizeof(comp),
        6, true
    );
    ASSERT_TRUE(csize > 0);
}

void run_deflate_stream_coder_tests(void) {
    ttzip_test_init_suite("Deflate Stream Coder");
    RUN_TEST(test_unified_libdeflate_roundtrip);
    RUN_TEST(test_unified_bzip2_roundtrip);
    RUN_TEST(test_raw_deflate_block_with_dict);
    ttzip_test_finish_suite();
}
