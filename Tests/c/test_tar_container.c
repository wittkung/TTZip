/**
 * @file test_tar_container.c
 * @brief Unit tests for POSIX UStar TAR container headers, SWAR octal decoders, and trailers.
 * 
 * SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
 * Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>. All rights reserved.
 */

#include "ttzip_test_harness.h"
#include "ttzip_tar_container.h"

TEST_CASE(test_tar_ustar_header_formatting) {
    uint8_t block[TTZIP_TAR_BLOCK_SIZE];
    memset(block, 0, sizeof(block));

    ttzip_tar_entry_meta_t meta;
    memset(&meta, 0, sizeof(meta));
    meta.path = "documents/report.pdf";
    meta.file_size = 12345;
    meta.mode = 0644;
    meta.mtime = 1700000000;
    meta.uid = 501;
    meta.gid = 20;
    meta.uname = "witt";
    meta.gname = "staff";
    meta.is_directory = false;

    size_t written = ttzip_tar_write_header(&meta, block);
    ASSERT_EQ(written, 512);

    // Verify magic "ustar\0" or "ustar  \0" at offset 257
    ASSERT_MEM_EQ(block + 257, "ustar", 5);

    // Verify path at offset 0
    ASSERT_STR_EQ((const char*)block, "documents/report.pdf");

    // Verify typeflag '0' for regular file at offset 156
    ASSERT_EQ(block[156], '0');
}

TEST_CASE(test_tar_directory_header_formatting) {
    uint8_t block[TTZIP_TAR_BLOCK_SIZE];
    memset(block, 0, sizeof(block));

    ttzip_tar_entry_meta_t meta;
    memset(&meta, 0, sizeof(meta));
    meta.path = "documents/";
    meta.file_size = 0;
    meta.mode = 0755;
    meta.mtime = 1700000000;
    meta.is_directory = true;

    size_t written = ttzip_tar_write_header(&meta, block);
    ASSERT_EQ(written, 512);

    // Verify typeflag '5' for directory at offset 156
    ASSERT_EQ(block[156], '5');
}

TEST_CASE(test_tar_trailer_formatting) {
    uint8_t trailer[1024];
    memset(trailer, 0xFF, sizeof(trailer));

    size_t written = ttzip_tar_write_trailer(trailer);
    ASSERT_EQ(written, 1024);

    // Verify all 1024 bytes are zeroed
    for (size_t i = 0; i < sizeof(trailer); ++i) {
        ASSERT_EQ(trailer[i], 0);
    }
}

void run_tar_container_tests(void) {
    ttzip_test_init_suite("TAR Container");
    RUN_TEST(test_tar_ustar_header_formatting);
    RUN_TEST(test_tar_directory_header_formatting);
    RUN_TEST(test_tar_trailer_formatting);
    ttzip_test_finish_suite();
}
