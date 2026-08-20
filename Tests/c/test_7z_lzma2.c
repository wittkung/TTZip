/**
 * @file test_7z_lzma2.c
 * @brief Unit tests for 7-Zip container header serialization and Fast-LZMA2 block compression.
 * 
 * SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
 * Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>. All rights reserved.
 */

#include "ttzip_test_harness.h"
#include "ttzip_7z_container.h"
#include "ttzip_fl2_lzma2.h"

TEST_CASE(test_7z_signature_header_serialization) {
    uint8_t header[TTZIP_7Z_SIGNATURE_SIZE];
    memset(header, 0, sizeof(header));

    uint64_t next_header_offset = 0x1000ULL;
    uint64_t next_header_size = 0x80ULL;
    uint32_t next_header_crc = 0x12345678U;

    size_t written = ttzip_7z_write_signature_header(
        next_header_offset,
        next_header_size,
        next_header_crc,
        header
    );

    ASSERT_EQ(written, 32);
    // Verify 6-byte magic: '7', 'z', 0xBC, 0xAF, 0x27, 0x1C
    ASSERT_EQ(header[0], '7');
    ASSERT_EQ(header[1], 'z');
    ASSERT_EQ(header[2], 0xBC);
    ASSERT_EQ(header[3], 0xAF);
    ASSERT_EQ(header[4], 0x27);
    ASSERT_EQ(header[5], 0x1C);
}

TEST_CASE(test_fast_lzma2_block_compression) {
    // 64KB repetitive buffer
    uint8_t src[65536];
    for (size_t i = 0; i < sizeof(src); ++i) {
        src[i] = (uint8_t)(i % 128);
    }

    uint8_t dst[65536];
    size_t compressed_len = 0;
    uint32_t dict_size = 0;

    int ret = ttzip_fl2_compress_block(
        src, sizeof(src),
        dst, sizeof(dst),
        &compressed_len,
        5,      // Level 5
        false,  // is_zero_block
        &dict_size,
        1       // thread_count
    );

    ASSERT_EQ(ret, 0);
    ASSERT_TRUE(compressed_len > 0);
    ASSERT_TRUE(compressed_len < sizeof(src) / 2); // > 2x ratio
}

TEST_CASE(test_fast_lzma2_zero_block_ultra_bypass) {
    // 1MB all-zeros buffer
    size_t zero_size = 1048576;
    uint8_t* zero_buf = (uint8_t*)calloc(1, zero_size);
    ASSERT_NOT_NULL(zero_buf);

    uint8_t dst[4096];
    size_t compressed_len = 0;
    uint32_t dict_size = 0;

    int ret = ttzip_fl2_compress_block(
        zero_buf, zero_size,
        dst, sizeof(dst),
        &compressed_len,
        3,
        true, // is_zero_block
        &dict_size,
        1
    );

    ASSERT_EQ(ret, 0);
    ASSERT_TRUE(compressed_len > 0);
    ASSERT_TRUE(compressed_len < 4096); // 1MB zero chunk compresses to < 4KB (250x ratio)

    free(zero_buf);
}

void run_7z_lzma2_tests(void) {
    ttzip_test_init_suite("7z & Fast-LZMA2");
    RUN_TEST(test_7z_signature_header_serialization);
    RUN_TEST(test_fast_lzma2_block_compression);
    RUN_TEST(test_fast_lzma2_zero_block_ultra_bypass);
    ttzip_test_finish_suite();
}
