/**
 * @file test_security_zipslip.c
 * @brief Unit tests for defensive path canonicalization, Zip-Slip prevention, and secure memory erasure.
 * 
 * SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
 * Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>. All rights reserved.
 */

#include "ttzip_test_harness.h"
#include "CTTZipCommon.h"
#include "ttzip_security.h"

TEST_CASE(test_normal_relative_path_allowed) {
    char dst[PATH_MAX];
    const char* base = "/tmp/extract_target";
    
    // Normal single-level child
    int ret1 = ttzip_common_join_path(dst, sizeof(dst), base, "file.txt");
    ASSERT_EQ(ret1, 0);
    ASSERT_STR_EQ(dst, "/tmp/extract_target/file.txt");

    // Normal multi-level subfolder
    int ret2 = ttzip_common_join_path(dst, sizeof(dst), base, "nested/subfolder/file.png");
    ASSERT_EQ(ret2, 0);
    ASSERT_STR_EQ(dst, "/tmp/extract_target/nested/subfolder/file.png");
}

TEST_CASE(test_zip_slip_traversal_blocked) {
    char dst[PATH_MAX];
    const char* base = "/tmp/extract_target";

    // Classic directory traversal: ../../etc/passwd
    int ret1 = ttzip_common_join_path(dst, sizeof(dst), base, "../../etc/passwd");
    ASSERT_NEQ(ret1, 0); // Must be strictly rejected

    // Embedded sneaky traversal: foo/bar/../../../etc/shadow
    int ret2 = ttzip_common_join_path(dst, sizeof(dst), base, "foo/bar/../../../etc/shadow");
    ASSERT_NEQ(ret2, 0);

    // Immediate parent escape: ../sibling
    int ret3 = ttzip_common_join_path(dst, sizeof(dst), base, "../sibling.txt");
    ASSERT_NEQ(ret3, 0);
}

TEST_CASE(test_absolute_path_escape_blocked) {
    char dst[PATH_MAX];
    const char* base = "/tmp/extract_target";

    // Leading slash absolute path escape
    int ret = ttzip_common_join_path(dst, sizeof(dst), base, "/etc/passwd");
    // Depending on implementation, leading slashes are stripped or rejected
    if (ret == 0) {
        // If sanitized, the resulting path MUST start with base
        ASSERT_TRUE(strncmp(dst, base, strlen(base)) == 0);
    }
}

TEST_CASE(test_secure_memory_zeroing) {
    uint8_t secret_buf[256];
    for (size_t i = 0; i < sizeof(secret_buf); ++i) {
        secret_buf[i] = (uint8_t)(i ^ 0xAA);
    }

    ttzip_secure_zero_memory(secret_buf, sizeof(secret_buf));

    // Verify all bytes are 0
    for (size_t i = 0; i < sizeof(secret_buf); ++i) {
        ASSERT_EQ(secret_buf[i], 0);
    }
}

TEST_CASE(test_recovery_record_fec_parity) {
    const uint8_t data[] = "TTZip Ultra-Secure Enterprise Archiving Parity Test Vector 2026";
    size_t data_len = strlen((const char*)data);
    uint8_t parity[32];
    memset(parity, 0, sizeof(parity));

    int gen_ret = ttzip_generate_recovery_parity(data, data_len, parity, sizeof(parity));
    ASSERT_EQ(gen_ret, 0);

    // Verify correct parity matches
    bool verify_ok = ttzip_verify_recovery_parity(data, data_len, parity, sizeof(parity));
    ASSERT_TRUE(verify_ok);

    // Corrupt one byte of data and verify rejection
    uint8_t corrupted_data[sizeof(data)];
    memcpy(corrupted_data, data, sizeof(data));
    corrupted_data[5] ^= 0xFF;

    bool verify_fail = ttzip_verify_recovery_parity(corrupted_data, data_len, parity, sizeof(parity));
    ASSERT_FALSE(verify_fail);
}

void run_security_zipslip_tests(void) {
    ttzip_test_init_suite("Security & ZipSlip");
    RUN_TEST(test_normal_relative_path_allowed);
    RUN_TEST(test_zip_slip_traversal_blocked);
    RUN_TEST(test_absolute_path_escape_blocked);
    RUN_TEST(test_secure_memory_zeroing);
    RUN_TEST(test_recovery_record_fec_parity);
    ttzip_test_finish_suite();
}
