/**
 * @file bench_main.c
 * @brief Master CLI Runner for TTZip Native C11 Performance & Benchmark Engine.
 * 
 * SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
 * Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>. All rights reserved.
 */

#include "ttzip_benchmark_harness.h"

// Forward declarations of benchmark suite runners
void run_codec_benchmarks(void);
void run_checksum_benchmarks(void);
void run_pareto_benchmarks(void);
void run_stress_vfs_benchmarks(void);

int main(int argc, char** argv) {
    bool run_all = true;
    bool run_codecs = false;
    bool run_checksums = false;
    bool run_pareto = false;
    bool run_stress = false;

    if (argc > 1) {
        run_all = false;
        for (int i = 1; i < argc; ++i) {
            if (strcmp(argv[i], "--all") == 0 || strcmp(argv[i], "all") == 0) {
                run_all = true;
            } else if (strcmp(argv[i], "--codecs") == 0 || strcmp(argv[i], "codecs") == 0) {
                run_codecs = true;
            } else if (strcmp(argv[i], "--checksums") == 0 || strcmp(argv[i], "checksums") == 0) {
                run_checksums = true;
            } else if (strcmp(argv[i], "--pareto") == 0 || strcmp(argv[i], "pareto") == 0) {
                run_pareto = true;
            } else if (strcmp(argv[i], "--stress") == 0 || strcmp(argv[i], "stress") == 0) {
                run_stress = true;
            }
        }
    }

    printf("\n================================================================================\n");
    printf(" ⚡️ TTZip Native C11 High-Resolution Benchmark Suite (Zero Cloud Quota)\n");
    printf("================================================================================\n\n");

    uint64_t total_t0 = ttzip_bench_nanos();

    if (run_all || run_codecs) {
        run_codec_benchmarks();
    }
    if (run_all || run_checksums) {
        run_checksum_benchmarks();
    }
    if (run_all || run_pareto) {
        run_pareto_benchmarks();
    }
    if (run_all || run_stress) {
        run_stress_vfs_benchmarks();
    }

    uint64_t total_t1 = ttzip_bench_nanos();
    double total_ms = (double)(total_t1 - total_t0) / 1000000.0;

    printf("================================================================================\n");
    printf(" 🎉 ALL BENCHMARKS COMPLETED IN %.2f ms\n", total_ms);
    printf("================================================================================\n\n");

    return 0;
}
