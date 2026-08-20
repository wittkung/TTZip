/**
 * @file test_main.c
 * @brief Unified C test runner and sub-command dispatcher for TTZip CTest suites.
 * 
 * SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
 * Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>. All rights reserved.
 */

#include "ttzip_test_harness.h"

// Forward declarations of all 21 test suite runners
void run_crc_neon_tests(void);
void run_magic_sniff_tests(void);
void run_strnatcmp_tests(void);
void run_deflate_zopfli_tests(void);
void run_7z_lzma2_tests(void);
void run_tar_container_tests(void);
void run_security_zipslip_tests(void);
void run_concurrency_threadpool_tests(void);
void run_blosc_engine_tests(void);
void run_huffman_inplace_tests(void);
void run_snappy_engine_tests(void);
void run_dmg_lzfse_tests(void);
void run_archive_tree_tests(void);
void run_matchfinder_neon_tests(void);
void run_adler_crc64_tests(void);
void run_entropy_evaluator_tests(void);
void run_matchfinder_advanced_tests(void);
void run_blosc_slicing_tests(void);
void run_crypto_lz4_snappy_tests(void);
void run_deflate_stream_coder_tests(void);
void run_platform_isa_tests(void);
void run_cve_regressions_tests(void);
void run_compat_archives_tests(void);
void run_fs_metadata_tests(void);

int main(int argc, char** argv) {
    const char* suite_filter = (argc > 1) ? argv[1] : "all";

    printf("\n================================================================================\n");
    printf(" ⚡️ TTZip Native Microkernel C11 Test Runner (Zero Cloud Quota)\n");
    printf("   Suite Selection: %s\n", suite_filter);
    printf("================================================================================\n\n");

    uint64_t total_t0 = ttzip_test_monotonic_nanos();
    int overall_failures = 0;

    if (strcmp(suite_filter, "all") == 0 || strcmp(suite_filter, "crc_neon") == 0) {
        run_crc_neon_tests();
        overall_failures += (ttzip_test_get_global_ctx()->failed_tests > 0 ? 1 : 0);
    }
    if (strcmp(suite_filter, "all") == 0 || strcmp(suite_filter, "magic_sniff") == 0) {
        run_magic_sniff_tests();
        overall_failures += (ttzip_test_get_global_ctx()->failed_tests > 0 ? 1 : 0);
    }
    if (strcmp(suite_filter, "all") == 0 || strcmp(suite_filter, "strnatcmp") == 0) {
        run_strnatcmp_tests();
        overall_failures += (ttzip_test_get_global_ctx()->failed_tests > 0 ? 1 : 0);
    }
    if (strcmp(suite_filter, "all") == 0 || strcmp(suite_filter, "deflate_zopfli") == 0) {
        run_deflate_zopfli_tests();
        overall_failures += (ttzip_test_get_global_ctx()->failed_tests > 0 ? 1 : 0);
    }
    if (strcmp(suite_filter, "all") == 0 || strcmp(suite_filter, "7z_lzma2") == 0) {
        run_7z_lzma2_tests();
        overall_failures += (ttzip_test_get_global_ctx()->failed_tests > 0 ? 1 : 0);
    }
    if (strcmp(suite_filter, "all") == 0 || strcmp(suite_filter, "tar_container") == 0) {
        run_tar_container_tests();
        overall_failures += (ttzip_test_get_global_ctx()->failed_tests > 0 ? 1 : 0);
    }
    if (strcmp(suite_filter, "all") == 0 || strcmp(suite_filter, "security_zipslip") == 0) {
        run_security_zipslip_tests();
        overall_failures += (ttzip_test_get_global_ctx()->failed_tests > 0 ? 1 : 0);
    }
    if (strcmp(suite_filter, "all") == 0 || strcmp(suite_filter, "concurrency_threadpool") == 0) {
        run_concurrency_threadpool_tests();
        overall_failures += (ttzip_test_get_global_ctx()->failed_tests > 0 ? 1 : 0);
    }
    if (strcmp(suite_filter, "all") == 0 || strcmp(suite_filter, "blosc_engine") == 0) {
        run_blosc_engine_tests();
        overall_failures += (ttzip_test_get_global_ctx()->failed_tests > 0 ? 1 : 0);
    }
    if (strcmp(suite_filter, "all") == 0 || strcmp(suite_filter, "huffman_inplace") == 0) {
        run_huffman_inplace_tests();
        overall_failures += (ttzip_test_get_global_ctx()->failed_tests > 0 ? 1 : 0);
    }
    if (strcmp(suite_filter, "all") == 0 || strcmp(suite_filter, "snappy_engine") == 0) {
        run_snappy_engine_tests();
        overall_failures += (ttzip_test_get_global_ctx()->failed_tests > 0 ? 1 : 0);
    }
    if (strcmp(suite_filter, "all") == 0 || strcmp(suite_filter, "dmg_lzfse") == 0) {
        run_dmg_lzfse_tests();
        overall_failures += (ttzip_test_get_global_ctx()->failed_tests > 0 ? 1 : 0);
    }
    if (strcmp(suite_filter, "all") == 0 || strcmp(suite_filter, "archive_tree") == 0) {
        run_archive_tree_tests();
        overall_failures += (ttzip_test_get_global_ctx()->failed_tests > 0 ? 1 : 0);
    }
    if (strcmp(suite_filter, "all") == 0 || strcmp(suite_filter, "matchfinder_neon") == 0) {
        run_matchfinder_neon_tests();
        overall_failures += (ttzip_test_get_global_ctx()->failed_tests > 0 ? 1 : 0);
    }
    if (strcmp(suite_filter, "all") == 0 || strcmp(suite_filter, "adler_crc64") == 0) {
        run_adler_crc64_tests();
        overall_failures += (ttzip_test_get_global_ctx()->failed_tests > 0 ? 1 : 0);
    }
    if (strcmp(suite_filter, "all") == 0 || strcmp(suite_filter, "entropy_evaluator") == 0) {
        run_entropy_evaluator_tests();
        overall_failures += (ttzip_test_get_global_ctx()->failed_tests > 0 ? 1 : 0);
    }
    if (strcmp(suite_filter, "all") == 0 || strcmp(suite_filter, "matchfinder_advanced") == 0) {
        run_matchfinder_advanced_tests();
        overall_failures += (ttzip_test_get_global_ctx()->failed_tests > 0 ? 1 : 0);
    }
    if (strcmp(suite_filter, "all") == 0 || strcmp(suite_filter, "blosc_slicing") == 0) {
        run_blosc_slicing_tests();
        overall_failures += (ttzip_test_get_global_ctx()->failed_tests > 0 ? 1 : 0);
    }
    if (strcmp(suite_filter, "all") == 0 || strcmp(suite_filter, "crypto_lz4_snappy") == 0) {
        run_crypto_lz4_snappy_tests();
        overall_failures += (ttzip_test_get_global_ctx()->failed_tests > 0 ? 1 : 0);
    }
    if (strcmp(suite_filter, "all") == 0 || strcmp(suite_filter, "deflate_stream_coder") == 0) {
        run_deflate_stream_coder_tests();
        overall_failures += (ttzip_test_get_global_ctx()->failed_tests > 0 ? 1 : 0);
    }
    if (strcmp(suite_filter, "all") == 0 || strcmp(suite_filter, "platform_isa") == 0) {
        run_platform_isa_tests();
        overall_failures += (ttzip_test_get_global_ctx()->failed_tests > 0 ? 1 : 0);
    }
    if (strcmp(suite_filter, "all") == 0 || strcmp(suite_filter, "cve_regressions") == 0) {
        run_cve_regressions_tests();
        overall_failures += (ttzip_test_get_global_ctx()->failed_tests > 0 ? 1 : 0);
    }
    if (strcmp(suite_filter, "all") == 0 || strcmp(suite_filter, "compat_archives") == 0) {
        run_compat_archives_tests();
        overall_failures += (ttzip_test_get_global_ctx()->failed_tests > 0 ? 1 : 0);
    }
    if (strcmp(suite_filter, "all") == 0 || strcmp(suite_filter, "fs_metadata") == 0) {
        run_fs_metadata_tests();
        overall_failures += (ttzip_test_get_global_ctx()->failed_tests > 0 ? 1 : 0);
    }

    uint64_t total_t1 = ttzip_test_monotonic_nanos();
    char total_dur[32];
    ttzip_test_format_duration(total_t1 - total_t0, total_dur, sizeof(total_dur));

    printf("================================================================================\n");
    if (overall_failures == 0) {
        printf(" 🎉 ALL C TEST SUITES PASSED SUCCESSFULLY (%s total)\n", total_dur);
    } else {
        printf(" ❌ TEST SUITES FAILED (%d failures detected, %s total)\n", overall_failures, total_dur);
    }
    printf("================================================================================\n\n");

    return (overall_failures == 0) ? 0 : 1;
}
