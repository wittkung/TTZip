/**
 * @file test_entropy_evaluator.c
 * @brief Unit tests for SWAR/NEON Shannon entropy calculation and dynamic block routing.
 * 
 * SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
 * Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>. All rights reserved.
 */

#include "ttzip_test_harness.h"
#include "CTTZipBridge.h"
#include "CTTZipStreamCoder.h"

TEST_CASE(test_shannon_entropy_scale_invariants) {
    // 1. Zero-fill buffer: entropy must be 0.0
    uint8_t zero_buf[4096];
    memset(zero_buf, 0, sizeof(zero_buf));
    double zero_entropy = ttzip_estimate_buffer_entropy(zero_buf, sizeof(zero_buf));
    ASSERT_TRUE(zero_entropy >= 0.0 && zero_entropy <= 0.01);

    // 2. Structured ASCII text: entropy typically 3.5 to 5.0 bits/byte
    const char text[] = "The quick brown fox jumps over the lazy dog. Repetitive natural language entropy test 2026.";
    double text_entropy = ttzip_estimate_buffer_entropy(text, strlen(text));
    ASSERT_TRUE(text_entropy >= 3.0 && text_entropy <= 5.5);

    // 3. Uniform pseudo-random noise: entropy approaching 8.0 bits/byte
    uint8_t rand_buf[4096];
    for (size_t i = 0; i < sizeof(rand_buf); ++i) {
        rand_buf[i] = (uint8_t)((i * 101 + 37) & 0xFF);
    }
    double rand_entropy = ttzip_estimate_buffer_entropy(rand_buf, sizeof(rand_buf));
    ASSERT_TRUE(rand_entropy >= 7.5 && rand_entropy <= 8.0);
}

TEST_CASE(test_adaptive_block_size_calculation) {
    size_t file_size = 10 * 1024 * 1024; // 10MB

    // Low entropy (< 3.0) -> Larger block size (e.g. >= 512KB)
    size_t low_ent_block = ttzip_calculate_adaptive_block_size(2.0, file_size);
    ASSERT_TRUE(low_ent_block >= 256 * 1024);

    // High entropy (> 7.5) -> Smaller block size or bypass
    size_t high_ent_block = ttzip_calculate_adaptive_block_size(7.8, file_size);
    ASSERT_TRUE(high_ent_block <= low_ent_block);
}

void run_entropy_evaluator_tests(void) {
    ttzip_test_init_suite("Entropy & Routing");
    RUN_TEST(test_shannon_entropy_scale_invariants);
    RUN_TEST(test_adaptive_block_size_calculation);
    ttzip_test_finish_suite();
}
