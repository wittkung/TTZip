/**
 * @file test_matchfinder_neon.c
 * @brief Unit tests for ARM64 NEON & SWAR Hybrid Match Finder (LZMA HC4 / Deflate).
 * 
 * SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
 * Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>. All rights reserved.
 */

#include "ttzip_test_harness.h"
#include "ttzip_lzma_hc4_neon.h"

TEST_CASE(test_hybrid_match_len_exhaustive_sweep) {
    uint8_t base[300];
    uint8_t candidate[300];

    for (size_t i = 0; i < sizeof(base); ++i) {
        base[i] = (uint8_t)(i % 251);
        candidate[i] = (uint8_t)(i % 251);
    }

    // Sweep exact match lengths from 0 to 273 (LZMA max match)
    for (uint32_t target_len = 0; target_len <= 273; ++target_len) {
        memcpy(candidate, base, sizeof(base));
        if (target_len < (uint32_t)sizeof(candidate)) {
            candidate[target_len] ^= 0xFF; // Introduce mismatch at exact target
        }

        // Test with max_len = 273
        uint32_t found_273 = ttzip_hybrid_match_len_neon(base, candidate, 273);
        uint32_t expected_273 = target_len < 273 ? target_len : 273;
        ASSERT_EQ(found_273, expected_273);

        // Test with max_len = 258 (Deflate max)
        uint32_t found_258 = ttzip_hybrid_match_len_neon(base, candidate, 258);
        uint32_t expected_258 = target_len < 258 ? target_len : 258;
        ASSERT_EQ(found_258, expected_258);
    }
}

TEST_CASE(test_hybrid_match_len_misalignment_matrix) {
    uint8_t raw_buf1[512];
    uint8_t raw_buf2[512];

    for (size_t i = 0; i < sizeof(raw_buf1); ++i) {
        raw_buf1[i] = (uint8_t)((i * 31 + 7) & 0xFF);
        raw_buf2[i] = (uint8_t)((i * 31 + 7) & 0xFF);
    }

    // Test across byte alignment offsets (0..15)
    for (size_t off1 = 0; off1 < 16; ++off1) {
        for (size_t off2 = 0; off2 < 16; ++off2) {
            uint32_t match = ttzip_hybrid_match_len_neon(raw_buf1 + off1, raw_buf1 + off1, 258);
            ASSERT_EQ(match, 258U);
        }
    }
}

void run_matchfinder_neon_tests(void) {
    ttzip_test_init_suite("NEON Match Finder");
    RUN_TEST(test_hybrid_match_len_exhaustive_sweep);
    RUN_TEST(test_hybrid_match_len_misalignment_matrix);
    ttzip_test_finish_suite();
}
