// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "ttzip_test_harness.h"
#include "include/ttzip_thread_budget.h"
#include "include/ttzip_threadpool.h"
#include <stdatomic.h>

TEST_CASE(test_apple_silicon_topology_detection) {
    ttzip_cpu_topology_t topo = ttzip_cpu_topology_detect();
    
    ASSERT_TRUE(topo.total_logical_cores >= 1);
    ASSERT_TRUE(topo.p_cores >= 1);
    ASSERT_TRUE(topo.default_threads >= 1);
    ASSERT_TRUE(topo.cacheline_bytes == 64 || topo.cacheline_bytes == 128);
    ASSERT_TRUE(topo.nperflevels >= 1);
}

TEST_CASE(test_l2_cache_cluster_chunk_calculation) {
    size_t chunk_p = ttzip_compute_optimal_chunk_size(true, 100 * 1024 * 1024);
    size_t chunk_e = ttzip_compute_optimal_chunk_size(false, 100 * 1024 * 1024);
    
    // Performance core chunk boundary: 256KB ~ 4MB
    ASSERT_TRUE(chunk_p >= 256 * 1024);
    ASSERT_TRUE(chunk_p <= 4 * 1024 * 1024);
    ASSERT_EQ(chunk_p % 128, 0); // 128-byte cache line aligned
    
    // Efficiency core chunk boundary: 64KB ~ 1MB
    ASSERT_TRUE(chunk_e >= 64 * 1024);
    ASSERT_TRUE(chunk_e <= 1024 * 1024);
    ASSERT_EQ(chunk_e % 128, 0);
}

static void parallel_worker_p(size_t index, void* user_data) {
    _Atomic uint32_t* counter = (_Atomic uint32_t*)user_data;
    atomic_fetch_add_explicit(counter, (uint32_t)(index + 1), memory_order_relaxed);
}

TEST_CASE(test_threadpool_qos_tiers_parallel_for) {
    _Atomic uint32_t count_p = 0;
    _Atomic uint32_t count_e = 0;
    
    // Dispatch to P-core pool
    ttzip_parallel_for_qos(NULL, 100, parallel_worker_p, &count_p, TTZIP_QOS_PERFORMANCE);
    
    // Dispatch to E-core pool
    ttzip_parallel_for_qos(NULL, 100, parallel_worker_p, &count_e, TTZIP_QOS_EFFICIENCY);
    
    // Sum of 1..100 = 5050
    ASSERT_EQ(count_p, 5050);
    ASSERT_EQ(count_e, 5050);
}

void run_cpu_topology_tests(void) {
    ttzip_test_init_suite("CPU Topology & Heterogeneous QoS");
    RUN_TEST(test_apple_silicon_topology_detection);
    RUN_TEST(test_l2_cache_cluster_chunk_calculation);
    RUN_TEST(test_threadpool_qos_tiers_parallel_for);
    ttzip_test_finish_suite();
}
