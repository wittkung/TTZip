/**
 * @file test_archive_tree.c
 * @brief Unit tests for Radix Tree and Archive Virtual Filesystem.
 * 
 * SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
 * Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>. All rights reserved.
 */

#include "ttzip_test_harness.h"
#include "ttzip_archive_tree.h"

TEST_CASE(test_radix_tree_insertion_and_aggregation) {
    ttzip_tree_t* tree = ttzip_tree_create();
    ASSERT_NOT_NULL(tree);

    // Insert files
    int ret1 = ttzip_tree_insert(tree, "usr/local/bin/ttzip", 500, 200, 0x12345678, false);
    ASSERT_EQ(ret1, 0);

    int ret2 = ttzip_tree_insert(tree, "usr/local/share/doc.txt", 1000, 400, 0x87654321, false);
    ASSERT_EQ(ret2, 0);

    // Insert explicit directory
    int ret3 = ttzip_tree_insert(tree, "usr/local/include", 0, 0, 0, true);
    ASSERT_EQ(ret3, 0);

    ASSERT_EQ(tree->total_files, 2);
    ASSERT_EQ(tree->total_folders, 1);
    ASSERT_EQ(tree->total_uncompressed_bytes, 1500);
    ASSERT_EQ(tree->total_compressed_bytes, 600);

    ttzip_tree_destroy(tree);
}

TEST_CASE(test_radix_tree_search) {
    ttzip_tree_t* tree = ttzip_tree_create();
    ASSERT_NOT_NULL(tree);

    ttzip_tree_insert(tree, "Photos/2026/Summer/img01.jpg", 2048, 1024, 0, false);
    ttzip_tree_insert(tree, "Photos/2026/Winter/img02.jpg", 4096, 2048, 0, false);
    ttzip_tree_insert(tree, "Documents/Report.pdf", 8192, 4096, 0, false);

    const char* results[10];
    size_t matched = ttzip_tree_search(tree, "Summer", results, 10);
    ASSERT_EQ(matched, 1);
    ASSERT_STR_EQ(results[0], "Photos/2026/Summer");

    // Case-insensitive search
    size_t matched_case = ttzip_tree_search(tree, "REPORT", results, 10);
    ASSERT_EQ(matched_case, 1);
    ASSERT_STR_EQ(results[0], "Documents/Report.pdf");

    ttzip_tree_destroy(tree);
}

void run_archive_tree_tests(void) {
    ttzip_test_init_suite("Radix Archive Tree");
    RUN_TEST(test_radix_tree_insertion_and_aggregation);
    RUN_TEST(test_radix_tree_search);
    ttzip_test_finish_suite();
}
