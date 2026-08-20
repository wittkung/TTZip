/**
 * @file test_snappy_engine.c
 * @brief Unit tests for Snappy raw block, framed streams, and hardware CRC32c.
 * 
 * SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
 * Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>. All rights reserved.
 */

#include "ttzip_test_harness.h"
#include "CTTZipBridge_Snappy.h"

TEST_CASE(test_snappy_raw_block_roundtrip) {
    const char text[] = "TTZip Snappy Ultra-Fast In-Memory Codec Test 2026";
    size_t src_len = strlen(text);

    size_t max_comp = ttzip_snappy_max_compressed_length(src_len);
    ASSERT_TRUE(max_comp > 0);

    uint8_t comp_buf[256];
    size_t comp_len = sizeof(comp_buf);

    int ret = ttzip_snappy_compress(text, src_len, comp_buf, &comp_len);
    ASSERT_EQ(ret, TTZIP_SNAPPY_OK);
    ASSERT_TRUE(comp_len > 0);

    size_t uncompressed_len = 0;
    int ulen_ret = ttzip_snappy_uncompressed_length(comp_buf, comp_len, &uncompressed_len);
    ASSERT_EQ(ulen_ret, TTZIP_SNAPPY_OK);
    ASSERT_EQ(uncompressed_len, src_len);

    char decomp_buf[256];
    size_t decomp_len = sizeof(decomp_buf);
    int dret = ttzip_snappy_decompress(comp_buf, comp_len, decomp_buf, &decomp_len);
    ASSERT_EQ(dret, TTZIP_SNAPPY_OK);
    ASSERT_EQ(decomp_len, src_len);
    ASSERT_MEM_EQ(decomp_buf, text, src_len);
}

TEST_CASE(test_snappy_crc32c_hardware_vector) {
    // Standard Castagnoli CRC32C vector for "123456789" -> 0xE3069283
    const uint8_t vec[] = "123456789";
    uint32_t crc = ttzip_snappy_crc32c(0, vec, 9);
    ASSERT_EQ(crc, 0xE3069283U);

    // Masking / Unmasking symmetry
    uint32_t masked = ttzip_snappy_mask_crc32c(crc);
    uint32_t unmasked = ttzip_snappy_unmask_crc32c(masked);
    ASSERT_EQ(unmasked, crc);
}

TEST_CASE(test_snappy_framed_stream_roundtrip) {
    uint8_t payload[8192];
    for (size_t i = 0; i < sizeof(payload); ++i) {
        payload[i] = (uint8_t)("Google Snappy Framed Stream Test."[i % 33]);
    }

    uint8_t framed_buf[16384];
    size_t framed_len = sizeof(framed_buf);

    int ret = ttzip_snappy_framed_compress(payload, sizeof(payload), framed_buf, &framed_len);
    ASSERT_EQ(ret, TTZIP_SNAPPY_OK);
    ASSERT_TRUE(framed_len > 10);

    // Verify 10-byte stream identifier header: \xFF\x06\x00\x00sNaPpY
    ASSERT_EQ(framed_buf[0], 0xFF);
    ASSERT_EQ(framed_buf[1], 0x06);
    ASSERT_MEM_EQ(framed_buf + 4, "sNaPpY", 6);

    uint8_t decomp_buf[sizeof(payload)];
    size_t decomp_len = sizeof(decomp_buf);

    int dret = ttzip_snappy_framed_decompress(framed_buf, framed_len, decomp_buf, &decomp_len);
    ASSERT_EQ(dret, TTZIP_SNAPPY_OK);
    ASSERT_EQ(decomp_len, sizeof(payload));
    ASSERT_MEM_EQ(decomp_buf, payload, sizeof(payload));
}

void run_snappy_engine_tests(void) {
    ttzip_test_init_suite("Snappy Engine");
    RUN_TEST(test_snappy_raw_block_roundtrip);
    RUN_TEST(test_snappy_crc32c_hardware_vector);
    RUN_TEST(test_snappy_framed_stream_roundtrip);
    ttzip_test_finish_suite();
}
