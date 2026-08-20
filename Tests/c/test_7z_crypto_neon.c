// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "ttzip_test_harness.h"
#include "include/ttzip_7z_crypto_neon.h"
#include "include/ttzip_7z_kdf_arm64.h"
#include <string.h>
#include <CommonCrypto/CommonCrypto.h>

// NIST AES-256-CBC Differential Oracle vs Apple CommonCrypto
TEST_CASE(test_aes256_cbc_neon_differential_oracle) {
    const uint8_t key[32] = {
        0x60, 0x3d, 0xeb, 0x10, 0x15, 0xca, 0x71, 0xbe,
        0x2b, 0x73, 0xae, 0xf0, 0x85, 0x7d, 0x77, 0x81,
        0x1f, 0x35, 0x2c, 0x07, 0x3b, 0x61, 0x08, 0xd7,
        0x2d, 0x98, 0x10, 0xa3, 0x09, 0x14, 0xdf, 0xf4
    };

    const uint8_t iv[16] = {
        0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
        0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f
    };

    const uint8_t ciphertext[64] = {
        0xf5, 0x8c, 0x4c, 0x04, 0xd6, 0xe5, 0xf1, 0xba,
        0x77, 0x9e, 0xab, 0xfb, 0x5f, 0x7c, 0x5d, 0xc6,
        0x72, 0x6e, 0x12, 0xd6, 0x47, 0x0c, 0xe2, 0xa3,
        0x7b, 0x6c, 0x70, 0x43, 0xda, 0x9b, 0xa0, 0x60,
        0x35, 0xa4, 0x57, 0x48, 0x72, 0x97, 0x8d, 0x9b,
        0x1e, 0xa0, 0x88, 0x38, 0x49, 0x6a, 0xfe, 0xbc,
        0x75, 0x96, 0x37, 0x7b, 0xb8, 0x03, 0x4b, 0x44,
        0xce, 0x62, 0x60, 0x79, 0x1e, 0x5a, 0xeb, 0x1b
    };

    uint8_t cc_decrypted[64] = {0};
    size_t moved = 0;
    CCCryptorStatus st = CCCrypt(
        kCCDecrypt,
        kCCAlgorithmAES,
        0, // Raw CBC
        key,
        32,
        iv,
        ciphertext,
        sizeof(ciphertext),
        cc_decrypted,
        sizeof(cc_decrypted),
        &moved
    );
    ASSERT_EQ(st, kCCSuccess);

    uint8_t neon_decrypted[64] = {0};
    int res = ttzip_7z_aes256_cbc_decrypt_neon(key, iv, ciphertext, sizeof(ciphertext), neon_decrypted);
    ASSERT_EQ(res, 0);

    // Bit-for-bit differential oracle assert
    ASSERT_EQ(memcmp(neon_decrypted, cc_decrypted, sizeof(cc_decrypted)), 0);
}

// Multi-Block 8-Way Unrolled AES-256-CBC Decryption (128KB buffer)
TEST_CASE(test_aes256_cbc_neon_large_buffer) {
    const uint8_t key[32] = { 0xAA, 0xBB, 0xCC, 0xDD };
    const uint8_t iv[16] = { 0x55, 0x66, 0x77, 0x88 };
    size_t size = 128 * 1024; // 128KB (8192 blocks)

    uint8_t* cipher = (uint8_t*)malloc(size);
    uint8_t* plain1 = (uint8_t*)malloc(size);
    uint8_t* plain2 = (uint8_t*)malloc(size);

    for (size_t i = 0; i < size; i++) {
        cipher[i] = (uint8_t)(i * 37 + 13);
    }

    int res1 = ttzip_7z_aes256_cbc_decrypt_neon(key, iv, cipher, size, plain1);
    ASSERT_EQ(res1, 0);

    int res2 = ttzip_7z_aes256_cbc_decrypt_neon(key, iv, cipher, size, plain2);
    ASSERT_EQ(res2, 0);

    // Consistency assert across runs
    ASSERT_EQ(memcmp(plain1, plain2, size), 0);

    free(cipher);
    free(plain1);
    free(plain2);
}

// 7z SHA-256 KDF Key Derivation Validation
TEST_CASE(test_7z_kdf_sha256_derivation) {
    const char* password = "TestPassword2026!";
    const uint8_t salt[8] = { 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08 };
    uint8_t key1[32] = {0};
    uint8_t key2[32] = {0};

    int res1 = ttzip_7z_kdf_sha256_neon(password, salt, 8, 10, key1); // 2^10 = 1024 cycles
    ASSERT_EQ(res1, 0);

    int res2 = ttzip_7z_kdf_sha256_neon(password, salt, 8, 10, key2);
    ASSERT_EQ(res2, 0);

    ASSERT_EQ(memcmp(key1, key2, 32), 0);
}

void run_7z_crypto_neon_tests(void) {
    ttzip_test_init_suite("7z Crypto & ARM64 AES-256");
    RUN_TEST(test_aes256_cbc_neon_differential_oracle);
    RUN_TEST(test_aes256_cbc_neon_large_buffer);
    RUN_TEST(test_7z_kdf_sha256_derivation);
    ttzip_test_finish_suite();
}
