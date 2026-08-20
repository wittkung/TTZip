/**
 * @file test_crypto_lz4_snappy.c
 * @brief Unit tests for 7z ARMv8 KDF key derivation and Snappy defensive fuzzing.
 * 
 * SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
 * Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>. All rights reserved.
 */

#include "ttzip_test_harness.h"
#include "ttzip_7z_kdf_arm64.h"
#include "CTTZipBridge_Snappy.h"

TEST_CASE(test_7z_kdf_sha256_session_init) {
    ttzip_7z_crypto_session_t session;
    const uint8_t salt[8] = {1, 2, 3, 4, 5, 6, 7, 8};

    // Initialize with test password and num_cycles_power = 6 (64 cycles for ultra-fast test)
    int ret = ttzip_7z_crypto_session_init(&session, "TTZipSec2026", salt, sizeof(salt), 6);
    ASSERT_EQ(ret, 0);
    ASSERT_TRUE(session.is_active);

    // Verify derived AES key is non-zero
    bool non_zero = false;
    for (size_t i = 0; i < 32; ++i) {
        if (session.aes_key[i] != 0) non_zero = true;
    }
    ASSERT_TRUE(non_zero);
}

TEST_CASE(test_snappy_defensive_fuzz_rejection) {
    // 1. Truncated input (< 1 byte)
    size_t out_len = 256;
    char out_buf[256];
    int ret1 = ttzip_snappy_decompress(NULL, 0, out_buf, &out_len);
    ASSERT_TRUE(ret1 != TTZIP_SNAPPY_OK);

    // 2. Corrupt varint length byte
    const uint8_t corrupt_varint[] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01, 0x20};
    int ret2 = ttzip_snappy_decompress(corrupt_varint, sizeof(corrupt_varint), out_buf, &out_len);
    ASSERT_TRUE(ret2 != TTZIP_SNAPPY_OK);
}

void run_crypto_lz4_snappy_tests(void) {
    ttzip_test_init_suite("Crypto & Snappy");
    RUN_TEST(test_7z_kdf_sha256_session_init);
    RUN_TEST(test_snappy_defensive_fuzz_rejection);
    ttzip_test_finish_suite();
}
