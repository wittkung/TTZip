/**
 * @file test_cve_regressions.c
 * @brief Industrial CVE & Malformed Bitstream Defense Test Suite for TTZip.
 * 
 * SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
 * Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>. All rights reserved.
 */

#include "ttzip_test_harness.h"
#include "libdeflate.h"
#include "zstd.h"
#include "CTTZipStreamCoder.h"
#include "CTTZipBridge_Archive.h"
#include "ttzip_tar_native.h"

TEST_CASE(test_cve_synthetic_huffman_overflow) {
    const uint8_t bad_huffman[] = {
        0x78, 0x9c, 0xed, 0xc0, 0x01, 0x01, 0x00, 0x00, 
        0x00, 0x40, 0x20, 0xff, 0x7f, 0x00, 0x00, 0x00
    };
    uint8_t out[1024];
    size_t actual_out = 0;

    struct libdeflate_decompressor* d = libdeflate_alloc_decompressor();
    enum libdeflate_result res = libdeflate_deflate_decompress(
        d, bad_huffman, sizeof(bad_huffman), out, sizeof(out), &actual_out
    );
    libdeflate_free_decompressor(d);

    ASSERT_NEQ(res, LIBDEFLATE_SUCCESS);
}

TEST_CASE(test_cve_negative_distance_underflow) {
    const uint8_t bad_dist[] = {
        0x05, 0xc1, 0x81, 0x01, 0x00, 0x00, 0x00, 0x04, 
        0x00, 0x20, 0xbf, 0xf6, 0x3f, 0x80, 0x00, 0x00
    };
    uint8_t out[2048];
    size_t actual_out = 0;

    struct libdeflate_decompressor* d = libdeflate_alloc_decompressor();
    enum libdeflate_result res = libdeflate_deflate_decompress(
        d, bad_dist, sizeof(bad_dist), out, sizeof(out), &actual_out
    );
    libdeflate_free_decompressor(d);

    ASSERT_NEQ(res, LIBDEFLATE_SUCCESS);
}

TEST_CASE(test_cve_truncated_stream_defense) {
    const uint8_t truncated_zstd[] = { 0x28, 0xb5, 0x2f, 0xfd, 0x00, 0x00 };
    uint8_t out[512];

    size_t zres = ZSTD_decompress(out, sizeof(out), truncated_zstd, sizeof(truncated_zstd));
    ASSERT_TRUE(ZSTD_isError(zres));
}

TEST_CASE(test_cve_fixtures_graceful_rejection) {
    const char* cve_files[] = {
        "tests/fixtures/cve/cve_2002_0059.dat",
        "tests/fixtures/cve/cve_2005_1849.dat",
        "tests/fixtures/cve/gh_382_defneg.dat"
    };
    size_t num_files = sizeof(cve_files) / sizeof(cve_files[0]);

    for (size_t i = 0; i < num_files; ++i) {
        FILE* f = fopen(cve_files[i], "rb");
        if (!f) continue;

        uint8_t buf[1024];
        size_t n = fread(buf, 1, sizeof(buf), f);
        fclose(f);

        if (n > 0) {
            uint8_t out[4096];
            size_t actual_out = 0;
            struct libdeflate_decompressor* d = libdeflate_alloc_decompressor();
            enum libdeflate_result res = libdeflate_deflate_decompress(
                d, buf, n, out, sizeof(out), &actual_out
            );
            libdeflate_free_decompressor(d);

            ASSERT_NEQ(res, LIBDEFLATE_SUCCESS);
        }
    }
}

void run_cve_regressions_tests(void) {
    ttzip_test_init_suite("CVE & Malformed Bitstream Defense");
    RUN_TEST(test_cve_synthetic_huffman_overflow);
    RUN_TEST(test_cve_negative_distance_underflow);
    RUN_TEST(test_cve_truncated_stream_defense);
    RUN_TEST(test_cve_fixtures_graceful_rejection);
    ttzip_test_finish_suite();
}
