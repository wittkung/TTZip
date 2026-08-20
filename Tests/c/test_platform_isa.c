/**
 * @file test_platform_isa.c
 * @brief Unit tests for Platform ISA Detection, High-Precision Timers, and Acceleration Infrastructure.
 * 
 * SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
 * Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>. All rights reserved.
 */

#include "ttzip_test_harness.h"
#include "ttzip_platform.h"
#include "CTTZipPlatformTimer.h"
#include "CTTZipBridge_LZFSE.h"
#include "CTTZipBridge_UnRAR.h"

TEST_CASE(test_platform_monotonic_clock_ticks) {
    uint64_t t0 = ttzip_platform_monotonic_nanos();
    uint64_t ticks0 = ttzip_platform_raw_ticks();

    // Busy wait for ~1000 loop cycles
    volatile int dummy = 0;
    for (int i = 0; i < 1000; ++i) {
        dummy += i;
    }

    uint64_t t1 = ttzip_platform_monotonic_nanos();
    uint64_t ticks1 = ttzip_platform_raw_ticks();

    ASSERT_TRUE(t1 >= t0);
    ASSERT_TRUE(ticks1 >= ticks0);
    ASSERT_TRUE(dummy > 0);
}

TEST_CASE(test_lzfse_availability_macOS) {
#if defined(__APPLE__)
    ASSERT_TRUE(ttzip_lzfse_is_available());
#endif
}

TEST_CASE(test_unrar_nonexistent_file_rejection) {
    int count = ttzip_unrar_inspect_entry_count("/non_existent_file_2026.rar");
    ASSERT_EQ(count, -1);
}

void run_platform_isa_tests(void) {
    ttzip_test_init_suite("Platform ISA & Timers");
    RUN_TEST(test_platform_monotonic_clock_ticks);
    RUN_TEST(test_lzfse_availability_macOS);
    RUN_TEST(test_unrar_nonexistent_file_rejection);
    ttzip_test_finish_suite();
}
