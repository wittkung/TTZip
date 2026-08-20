/**
 * @file bench_stress_vfs.c
 * @brief Benchmark suite for Radix Virtual Filesystem traversal, DSE-immune memory scrubbing, and recovery parity.
 * 
 * SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
 * Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>. All rights reserved.
 */

#include "ttzip_benchmark_harness.h"
#include "ttzip_archive_tree.h"
#include "ttzip_security.h"

#define BENCH_STRESS_BUFFER_SIZE (64 * 1024 * 1024) // 64MB

void run_stress_vfs_benchmarks(void) {
    printf("--------------------------------------------------------------------------------\n");
    printf(" ⚡️ Benchmark Suite: Virtual Filesystem Traversal & In-Memory Stress\n");
    printf("--------------------------------------------------------------------------------\n");
    printf(" %-36s | %-16s | %-16s\n", "Operation / Kernel", "Throughput / Time", "Status / Count");
    printf("--------------------------------------------------------------------------------\n");

    // 1. Radix Archive Tree (5,000 Nodes insertion & search)
    {
        ttzip_tree_t* tree = ttzip_tree_create();
        uint64_t t0 = ttzip_bench_nanos();
        for (size_t i = 0; i < 5000; ++i) {
            char path[128];
            snprintf(path, sizeof(path), "Root/Folder%zu/subfolder/file_%04zu.dat", i % 20, i);
            ttzip_tree_insert(tree, path, 1024, 512, 0, false);
        }
        uint64_t t1 = ttzip_bench_nanos();
        double insert_time_ms = (double)(t1 - t0) / 1000000.0;

        uint64_t t2 = ttzip_bench_nanos();
        const char* results[10];
        size_t matched = ttzip_tree_search(tree, "file_0042", results, 10);
        uint64_t t3 = ttzip_bench_nanos();
        double search_time_us = (double)(t3 - t2) / 1000.0;

        printf(" %-36s | %13.2f ms | 5,000 nodes inserted\n", "Radix Tree Insertion (5k nodes)", insert_time_ms);
        printf(" %-36s | %13.2f µs | Found %zu match\n", "Radix Substring Query ('file_0042')", search_time_us, matched);

        ttzip_tree_destroy(tree);
    }

    // 2. DSE-Immune Secure Memory Zeroing (64MB)
    {
        uint8_t* buffer = (uint8_t*)malloc(BENCH_STRESS_BUFFER_SIZE);
        if (buffer) {
            memset(buffer, 0xAA, BENCH_STRESS_BUFFER_SIZE);
            uint64_t t0 = ttzip_bench_nanos();
            ttzip_secure_zero_memory(buffer, BENCH_STRESS_BUFFER_SIZE);
            uint64_t t1 = ttzip_bench_nanos();
            double speed_mbs = ttzip_calc_throughput_mbs(BENCH_STRESS_BUFFER_SIZE, t1 - t0);
            printf(" %-36s | %13.1f MB/s | %d MB wiped (DSE immune)\n", "Secure Memory Zeroing (DSE-Safe)", speed_mbs, (int)(BENCH_STRESS_BUFFER_SIZE / (1024 * 1024)));
            free(buffer);
        }
    }

    // 3. Reed-Solomon Recovery Record Parity Generation (8MB)
    {
        size_t src_len = 8 * 1024 * 1024;
        uint8_t* src = (uint8_t*)malloc(src_len);
        uint8_t parity[256];
        if (src) {
            memset(src, 0x55, src_len);
            uint64_t t0 = ttzip_bench_nanos();
            ttzip_generate_recovery_parity(src, src_len, parity, sizeof(parity));
            uint64_t t1 = ttzip_bench_nanos();
            double speed_mbs = ttzip_calc_throughput_mbs(src_len, t1 - t0);
            printf(" %-36s | %13.1f MB/s | %d MB FEC Parity\n", "Reed-Solomon Recovery Parity", speed_mbs, (int)(src_len / (1024 * 1024)));
            free(src);
        }
    }

    printf("--------------------------------------------------------------------------------\n\n");
}
