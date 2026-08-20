/**
 * @file test_blosc_slicing.c
 * @brief Unit tests for Blosc2 SuperChunk creation, special-value tagging, and micro-slicing.
 * 
 * SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
 * Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>. All rights reserved.
 */

#include "ttzip_test_harness.h"
#include "CTTZipSuperChunk.h"
#include "CTTZipBitGroom.h"

TEST_CASE(test_superchunk_lifecycle_and_append) {
    ttzip_schunk_config_t config = {
        .chunk_size = 65536,
        .block_size = 16384,
        .typesize = 4,
        .clevel = 3,
        .compcode = 0,
        .use_dict = false
    };

    ttzip_schunk_t* schunk = ttzip_schunk_create(&config);
    ASSERT_NOT_NULL(schunk);

    // Append 64KB chunk
    uint8_t payload[65536];
    for (size_t i = 0; i < sizeof(payload); ++i) {
        payload[i] = (uint8_t)(i & 0xFF);
    }

    int64_t csize = ttzip_schunk_append_chunk(schunk, payload, sizeof(payload));
    ASSERT_TRUE(csize > 0);
    ASSERT_EQ(schunk->nchunks, 1U);
    ASSERT_EQ(schunk->uncompressed_size, sizeof(payload));

    // Decompress chunk
    uint8_t decomp[65536];
    int64_t dsize = ttzip_schunk_decompress_chunk(schunk, 0, decomp, sizeof(decomp));
    ASSERT_EQ(dsize, (int64_t)sizeof(payload));
    ASSERT_MEM_EQ(decomp, payload, sizeof(payload));

    ttzip_schunk_free(schunk);
}

TEST_CASE(test_bitgroom_float64_neon) {
    double src[8];
    double dst[8];
    for (size_t i = 0; i < 8; ++i) {
        src[i] = 3.141592653589793 + (double)i * 0.01;
    }

    ttzip_filter_bitgroom_float64_neon(src, dst, 8, 4);

    for (size_t i = 0; i < 8; ++i) {
        double diff = src[i] - dst[i];
        if (diff < 0) diff = -diff;
        ASSERT_TRUE(diff < 0.001);
    }
}

void run_blosc_slicing_tests(void) {
    ttzip_test_init_suite("Blosc2 Slicing");
    RUN_TEST(test_superchunk_lifecycle_and_append);
    RUN_TEST(test_bitgroom_float64_neon);
    ttzip_test_finish_suite();
}
