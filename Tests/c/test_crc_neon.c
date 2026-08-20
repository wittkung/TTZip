/**
 * @file test_crc_neon.c
 * @brief Unit tests for hardware PMULL/NEON accelerated and software CRC32/CRC64.
 * 
 * SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
 * Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>. All rights reserved.
 */

#include "ttzip_test_harness.h"
#include "CTTZipCRC32Neon.h"
#include "ttzip_crc64.h"

TEST_CASE(test_crc32_ieee8023_standard_vector) {
    // Standard IEEE 802.3 ASCII "123456789" -> 0xCBF43926
    const uint8_t vec[] = "123456789";
    size_t len = 9;

    uint32_t crc_fast = ttzip_crc32_fast(0, vec, len);
    ASSERT_EQ(crc_fast, 0xCBF43926U);

    uint32_t crc_scalar = ttzip_crc32_scalar(0, vec, len);
    ASSERT_EQ(crc_scalar, 0xCBF43926U);

    uint32_t crc_neon = ttzip_core_crc32_neon_single(0, vec, len);
    ASSERT_EQ(crc_neon, 0xCBF43926U);
}

TEST_CASE(test_crc32_empty_and_single_byte) {
    const uint8_t byte_a = 'A';
    
    // Empty buffer CRC
    ASSERT_EQ(ttzip_crc32_fast(0, NULL, 0), 0U);
    ASSERT_EQ(ttzip_crc32_scalar(0, NULL, 0), 0U);

    // Single byte 'A' (0x41) -> 0xD3D99E8B (IEEE 802.3)
    uint32_t crc_1 = ttzip_crc32_fast(0, &byte_a, 1);
    uint32_t crc_2 = ttzip_crc32_scalar(0, &byte_a, 1);
    ASSERT_EQ(crc_1, crc_2);
}

TEST_CASE(test_crc32_alignment_and_length_matrix) {
    // Create 4KB buffer and test unaligned offsets (0..15) and variable lengths
    uint8_t buffer[4096];
    for (size_t i = 0; i < sizeof(buffer); ++i) {
        buffer[i] = (uint8_t)((i * 37 + 13) & 0xFF);
    }

    size_t test_lengths[] = { 0, 1, 7, 15, 16, 31, 32, 63, 64, 127, 255, 1024, 2048, 4000 };
    size_t num_lens = sizeof(test_lengths) / sizeof(test_lengths[0]);

    for (size_t offset = 0; offset < 16; ++offset) {
        for (size_t l = 0; l < num_lens; ++l) {
            size_t len = test_lengths[l];
            if (offset + len <= sizeof(buffer)) {
                uint32_t expected = ttzip_crc32_scalar(0, buffer + offset, len);
                uint32_t actual = ttzip_crc32_fast(0, buffer + offset, len);
                ASSERT_EQ(actual, expected);
            }
        }
    }
}

TEST_CASE(test_crc64_xz_standard_vector) {
    // Standard XZ/ECMA-182 vector for "123456789" -> 0x995DC9BBDF1939FAULL
    const uint8_t vec[] = "123456789";
    size_t len = 9;

    uint64_t crc_val = ttzip_crc64(vec, len, 0);
    ASSERT_EQ(crc_val, 0x995DC9BBDF1939FAULL);

    uint64_t crc_scalar = ttzip_crc64_scalar(vec, len, 0);
    ASSERT_EQ(crc_scalar, 0x995DC9BBDF1939FAULL);
}

TEST_CASE(test_crc64_alignment_matrix) {
    uint8_t buffer[2048];
    for (size_t i = 0; i < sizeof(buffer); ++i) {
        buffer[i] = (uint8_t)((i * 59 + 7) & 0xFF);
    }

    for (size_t offset = 0; offset < 8; ++offset) {
        for (size_t len = 0; len < 512; len += 31) {
            uint64_t expected = ttzip_crc64_scalar(buffer + offset, len, 0);
            uint64_t actual = ttzip_crc64(buffer + offset, len, 0);
            ASSERT_EQ(actual, expected);
        }
    }
}

void run_crc_neon_tests(void) {
    ttzip_test_init_suite("CRC & NEON PMULL");
    RUN_TEST(test_crc32_ieee8023_standard_vector);
    RUN_TEST(test_crc32_empty_and_single_byte);
    RUN_TEST(test_crc32_alignment_and_length_matrix);
    RUN_TEST(test_crc64_xz_standard_vector);
    RUN_TEST(test_crc64_alignment_matrix);
    ttzip_test_finish_suite();
}
