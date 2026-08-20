/**
 * @file test_huffman_inplace.c
 * @brief Unit tests for In-Place Canonical Huffman Code Generator and Adaptive Block Splitting.
 * 
 * SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
 * Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>. All rights reserved.
 */

#include "ttzip_test_harness.h"
#include "ttzip_huffman_inplace.h"
#include "ttzip_adaptive_block_split.h"

TEST_CASE(test_canonical_bit_reversal) {
    // 3-bit: binary 101 reversed is 101
    ASSERT_EQ(ttzip_canonical_bit_reverse(0b101, 3), 0b101U);

    // 4-bit: binary 0001 (1) reversed is 1000 (8)
    ASSERT_EQ(ttzip_canonical_bit_reverse(0b0001, 4), 0b1000U);

    // 8-bit: binary 11000000 (192) reversed is 00000011 (3)
    ASSERT_EQ(ttzip_canonical_bit_reverse(192, 8), 3U);
}

TEST_CASE(test_canonical_huffman_kraft_mcmillan_limits) {
    // Alphabet of 288 symbols with Fibonacci frequency distribution
    #define NUM_SYMBOLS 288
    uint32_t freqs[NUM_SYMBOLS];
    uint8_t lens[NUM_SYMBOLS];
    uint32_t codewords[NUM_SYMBOLS];

    freqs[0] = 1;
    freqs[1] = 1;
    for (size_t i = 2; i < NUM_SYMBOLS; ++i) {
        freqs[i] = (freqs[i - 1] + freqs[i - 2]) % 100000 + 1;
    }

    ttzip_make_canonical_huffman_code_inplace(
        NUM_SYMBOLS,
        15, // max_codeword_len <= 15 for RFC 1951 Deflate
        freqs,
        lens,
        codewords,
        true
    );

    // Verify all codeword lengths <= 15
    double kraft_sum = 0.0;
    for (size_t i = 0; i < NUM_SYMBOLS; ++i) {
        if (lens[i] > 0) {
            ASSERT_TRUE(lens[i] <= 15);
            kraft_sum += 1.0 / (double)(1U << lens[i]);
        }
    }

    // Kraft-McMillan inequality: sum(2^-L_i) <= 1.0
    ASSERT_TRUE(kraft_sum <= 1.00000001);
    #undef NUM_SYMBOLS
}

TEST_CASE(test_block_type_cost_arbitration) {
    uint32_t best_cost = 0;

    // Case 1: Static cost is cheaper than Dynamic and Uncompressed
    ttzip_block_type_t type1 = ttzip_eval_best_block_type(
        1500, // dynamic cost
        1100, // static cost
        200,  // block length (uncompressed = 200 * 8 + 40 = 1640 bits)
        10,
        &best_cost
    );
    ASSERT_EQ(type1, TTZIP_BLOCK_STATIC);
    ASSERT_EQ(best_cost, 1100U);

    // Case 2: Uncompressed is cheaper on incompressible data
    ttzip_block_type_t type2 = ttzip_eval_best_block_type(
        2000,
        1900,
        50, // uncompressed = 50 * 8 + 40 = 440 bits
        10,
        &best_cost
    );
    ASSERT_EQ(type2, TTZIP_BLOCK_STORED);
    ASSERT_TRUE(best_cost <= 440U);
}

void run_huffman_inplace_tests(void) {
    ttzip_test_init_suite("Huffman In-Place");
    RUN_TEST(test_canonical_bit_reversal);
    RUN_TEST(test_canonical_huffman_kraft_mcmillan_limits);
    RUN_TEST(test_block_type_cost_arbitration);
    ttzip_test_finish_suite();
}
