/**
 * @file test_strnatcmp.c
 * @brief Unit tests for C11 natural numeric string sorting algorithm.
 * 
 * SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
 * Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>. All rights reserved.
 */

#include "ttzip_test_harness.h"
#include "ttzip_strnatcmp.h"

TEST_CASE(test_numeric_natural_ordering) {
    // "file2.txt" < "file10.txt" (standard strcmp does "file10.txt" < "file2.txt")
    ASSERT_TRUE(ttzip_strnatcmp("file2.txt", "file10.txt") < 0);
    ASSERT_TRUE(ttzip_strnatcmp("file10.txt", "file2.txt") > 0);
    ASSERT_TRUE(ttzip_strnatcmp("file2.txt", "file2.txt") == 0);

    // Multi-number series: "a1b2" < "a1b10"
    ASSERT_TRUE(ttzip_strnatcmp("a1b2", "a1b10") < 0);
    ASSERT_TRUE(ttzip_strnatcmp("a20b1", "a100b1") < 0);
}

TEST_CASE(test_case_insensitive_natural_ordering) {
    // "File2.txt" and "file2.txt" equal under case-insensitive
    ASSERT_EQ(ttzip_strnatcasecmp("File2.txt", "file2.txt"), 0);

    // "File2.txt" < "file10.txt"
    ASSERT_TRUE(ttzip_strnatcasecmp("File2.txt", "file10.txt") < 0);
    ASSERT_TRUE(ttzip_strnatcasecmp("FILE10.TXT", "file2.txt") > 0);
}

TEST_CASE(test_leading_zero_handling) {
    // "file1.txt" and "file01.txt"
    // Leading zeros in natural sort should preserve distinction or order correctly
    int cmp = ttzip_strnatcmp("file01.txt", "file1.txt");
    int inv = ttzip_strnatcmp("file1.txt", "file01.txt");
    ASSERT_TRUE((cmp < 0 && inv > 0) || (cmp > 0 && inv < 0) || (cmp == 0 && inv == 0));
}

TEST_CASE(test_strict_weak_ordering_invariants) {
    const char* a = "item_1.png";
    const char* b = "item_2.png";
    const char* c = "item_10.png";

    // 1. Irreflexivity: !(a < a)
    ASSERT_EQ(ttzip_strnatcmp(a, a), 0);

    // 2. Asymmetry: a < b => !(b < a)
    int ab = ttzip_strnatcmp(a, b);
    int ba = ttzip_strnatcmp(b, a);
    ASSERT_TRUE((ab < 0 && ba > 0) || (ab > 0 && ba < 0) || (ab == 0 && ba == 0));

    // 3. Transitivity: a < b && b < c => a < c
    int bc = ttzip_strnatcmp(b, c);
    int ac = ttzip_strnatcmp(a, c);
    ASSERT_TRUE(ab < 0 && bc < 0 && ac < 0);
}

TEST_CASE(test_null_and_empty_string_safety) {
    ASSERT_EQ(ttzip_strnatcmp("", ""), 0);
    ASSERT_TRUE(ttzip_strnatcmp("", "a") < 0);
    ASSERT_TRUE(ttzip_strnatcmp("a", "") > 0);
}

void run_strnatcmp_tests(void) {
    ttzip_test_init_suite("Natural String Sort");
    RUN_TEST(test_numeric_natural_ordering);
    RUN_TEST(test_case_insensitive_natural_ordering);
    RUN_TEST(test_leading_zero_handling);
    RUN_TEST(test_strict_weak_ordering_invariants);
    RUN_TEST(test_null_and_empty_string_safety);
    ttzip_test_finish_suite();
}
