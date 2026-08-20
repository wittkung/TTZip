/**
 * @file test_matchfinder_advanced.c
 * @brief Unit tests for Fast Match Finder, LZ77 Hash Chains, and Ring Dictionaries.
 * 
 * SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
 * Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>. All rights reserved.
 */

#include "ttzip_test_harness.h"
#include "ttzip_lzma_hc4_neon.h"
#include "ttzip_huffman_inplace.h"

TEST_CASE(test_hc4_match_finder_boundary) {
    uint8_t buffer[1024];
    for (size_t i = 0; i < sizeof(buffer); ++i) {
        buffer[i] = (uint8_t)(i % 37);
    }

    // Match search within bounded window
    uint32_t len = ttzip_hybrid_match_len_neon(buffer, buffer + 37, 258);
    ASSERT_TRUE(len >= 37);
}

TEST_CASE(test_huffman_bitstream_packing_invariants) {
    // Verify RBIT property: (RBIT(code, len) reversed again) == code
    for (uint8_t bit_len = 1; bit_len <= 16; ++bit_len) {
        uint32_t mask = (1U << bit_len) - 1;
        for (uint32_t val = 0; val <= mask; val += (mask / 7 + 1)) {
            uint32_t rev = ttzip_canonical_bit_reverse(val, bit_len);
            uint32_t double_rev = ttzip_canonical_bit_reverse(rev, bit_len);
            ASSERT_EQ(double_rev, val);
        }
    }
}

void run_matchfinder_advanced_tests(void) {
    ttzip_test_init_suite("Advanced Matcher");
    RUN_TEST(test_hc4_match_finder_boundary);
    RUN_TEST(test_huffman_bitstream_packing_invariants);
    ttzip_test_finish_suite();
}
