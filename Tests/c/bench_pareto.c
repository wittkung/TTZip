/**
 * @file bench_pareto.c
 * @brief Benchmark suite for non-dominated Pareto Frontier curve modeling and regression gates.
 * 
 * SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
 * Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>. All rights reserved.
 */

#include "ttzip_benchmark_harness.h"

void run_pareto_benchmarks(void) {
    printf("--------------------------------------------------------------------------------\n");
    printf(" 📈 Benchmark Suite: Mathematical Pareto Frontier & Efficiency Envelope\n");
    printf("--------------------------------------------------------------------------------\n");
    printf(" %-24s | %-10s | %-12s | %-14s\n", "Codec Configuration", "Ratio (%)", "Speed (MB/s)", "Pareto Optimal");
    printf("--------------------------------------------------------------------------------\n");

    ttzip_bench_point_t points[] = {
        {"Snappy",             6.40,  11000.0, false},
        {"Zstd (Level 1)",     0.50,   7500.0, false},
        {"Zstd (Level 3)",     0.10,   7400.0, false},
        {"Deflate (Level 1)",  1.80,   6200.0, false},
        {"Deflate (Level 6)",  1.30,   1400.0, false},
        {"Deflate (Level 9)",  1.30,    450.0, false},
        {"LZFSE",              1.50,    500.0, false},
        {"Fast-LZMA2 (L3)",    0.10,     30.0, false},
        {"Fast-LZMA2 (L6)",    0.10,      7.0, false}
    };
    size_t count = sizeof(points) / sizeof(points[0]);

    ttzip_compute_pareto_frontier(points, count);

    size_t optimal_count = 0;
    for (size_t i = 0; i < count; ++i) {
        if (points[i].is_optimal) optimal_count++;
        printf(" %-24s | %8.2f %% | %10.1f   | %-14s\n",
            points[i].name,
            points[i].ratio_pct,
            points[i].speed_mbs,
            points[i].is_optimal ? "⭐ YES (Frontier)" : "  NO (Dominated)"
        );
    }

    printf("--------------------------------------------------------------------------------\n");
    printf(" Pareto Envelope Summary: %zu non-dominated frontier configurations found.\n", optimal_count);
    printf("--------------------------------------------------------------------------------\n\n");
}
