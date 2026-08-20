/**
 * @file test_concurrency_threadpool.c
 * @brief Unit tests for C11 threadpool, counting semaphores, parallel_for, and memory budget queries.
 * 
 * SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
 * Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>. All rights reserved.
 */

#include "ttzip_test_harness.h"
#include "ttzip_threadpool.h"
#include "ttzip_thread_budget.h"
#include "ttzip_mem_budget.h"

static void parallel_accumulate_worker(size_t index, void* user_data) {
    uint32_t* array = (uint32_t*)user_data;
    array[index] = (uint32_t)(index * 10 + 1);
}

TEST_CASE(test_parallel_for_zero_and_single_iteration) {
    uint32_t single_val = 0;
    
    // Zero count boundary check (must not crash or invoke callback)
    ttzip_parallel_for(NULL, 0, parallel_accumulate_worker, &single_val);
    ASSERT_EQ(single_val, 0);

    // Single iteration
    ttzip_parallel_for(NULL, 1, parallel_accumulate_worker, &single_val);
    ASSERT_EQ(single_val, 1);
}

TEST_CASE(test_parallel_for_multi_iteration_correctness) {
    #define NUM_ITEMS 100
    uint32_t items[NUM_ITEMS];
    memset(items, 0, sizeof(items));

    ttzip_parallel_for(NULL, NUM_ITEMS, parallel_accumulate_worker, items);

    for (size_t i = 0; i < NUM_ITEMS; ++i) {
        ASSERT_EQ(items[i], (uint32_t)(i * 10 + 1));
    }
    #undef NUM_ITEMS
}

TEST_CASE(test_counting_semaphore_lifecycle) {
    ttzip_semaphore_t* sem = ttzip_semaphore_create(0);
    ASSERT_NOT_NULL(sem);

    // Signal semaphore to increment permit
    ttzip_semaphore_signal(sem);

    // Wait should decrement and return immediately without blocking
    ttzip_semaphore_wait(sem);

    ttzip_semaphore_destroy(sem);
}

TEST_CASE(test_thread_and_memory_budget_queries) {
    ttzip_cpu_topology_t topo = ttzip_cpu_topology_detect();
    ASSERT_TRUE(topo.total_logical_cores >= 1);

    uint32_t optimal_threads = ttzip_thread_budget_get(0);
    ASSERT_TRUE(optimal_threads >= 1);

    ttzip_mem_budget_t mem = ttzip_mem_budget_query();
    ASSERT_TRUE(mem.total_physical_ram > 0);
    ASSERT_TRUE(mem.safe_budget_bytes > 0);
    ASSERT_TRUE(mem.safe_budget_bytes <= mem.total_physical_ram);

    uint64_t clamped = ttzip_mem_budget_clamp(1024 * 1024, 64 * 1024, 1024 * 1024 * 1024);
    ASSERT_EQ(clamped, 1024 * 1024);
}

void run_concurrency_threadpool_tests(void) {
    ttzip_test_init_suite("Concurrency & ThreadPool");
    RUN_TEST(test_parallel_for_zero_and_single_iteration);
    RUN_TEST(test_parallel_for_multi_iteration_correctness);
    RUN_TEST(test_counting_semaphore_lifecycle);
    RUN_TEST(test_thread_and_memory_budget_queries);
    ttzip_test_finish_suite();
}
