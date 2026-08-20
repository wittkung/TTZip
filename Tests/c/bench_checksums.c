/**
 * @file bench_checksums.c
 * @brief Benchmark suite for hardware vector accelerated checksums and Shannon entropy.
 * 
 * SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
 * Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>. All rights reserved.
 */

#include "ttzip_benchmark_harness.h"
#include "CTTZipChecksum.h"
#include "ttzip_crc64.h"
#include "CTTZipBridge.h"

#define BENCH_CHECKSUM_SIZE (16 * 1024 * 1024) // 16MB buffer

void run_checksum_benchmarks(void) {
    printf("--------------------------------------------------------------------------------\n");
    printf(" ⚡️ Benchmark Suite: Hardware SIMD Checksums & Entropy (16MB In-Memory)\n");
    printf("--------------------------------------------------------------------------------\n");
    printf(" %-32s | %-16s | %-16s\n", "Kernel / Algorithm", "Throughput (GB/s)", "Throughput (MB/s)");
    printf("--------------------------------------------------------------------------------\n");

    uint8_t* buffer = (uint8_t*)malloc(BENCH_CHECKSUM_SIZE);
    if (!buffer) {
        fprintf(stderr, "Memory allocation failure in bench_checksums\n");
        return;
    }
    ttzip_generate_corpus(TTZIP_CORPUS_TEXT, buffer, BENCH_CHECKSUM_SIZE);

    // 1. CRC32 (PMULL / ACLE)
    {
        uint64_t t0 = ttzip_bench_nanos();
        uint32_t hash = ttzip_crc32_fast(0, buffer, BENCH_CHECKSUM_SIZE);
        uint64_t t1 = ttzip_bench_nanos();
        double speed_mbs = ttzip_calc_throughput_mbs(BENCH_CHECKSUM_SIZE, t1 - t0);
        printf(" %-32s | %14.2f   | %14.1f (Hash: 0x%08X)\n", "CRC32 (ARM64 PMULL / ACLE)", speed_mbs / 1024.0, speed_mbs, hash);
    }

    // 2. CRC64 (PMULL / PCLMULQDQ)
    {
        uint64_t t0 = ttzip_bench_nanos();
        uint64_t hash = ttzip_crc64(buffer, BENCH_CHECKSUM_SIZE, 0);
        uint64_t t1 = ttzip_bench_nanos();
        double speed_mbs = ttzip_calc_throughput_mbs(BENCH_CHECKSUM_SIZE, t1 - t0);
        printf(" %-32s | %14.2f   | %14.1f (Hash: 0x%016llX)\n", "CRC64-XZ (ARM64 PMULL)", speed_mbs / 1024.0, speed_mbs, (unsigned long long)hash);
    }

    // 3. Adler-32 (ARM64 NEON DotProd / 5552B)
    {
        uint64_t t0 = ttzip_bench_nanos();
        uint32_t hash = ttzip_adler32_fast(1, buffer, BENCH_CHECKSUM_SIZE);
        uint64_t t1 = ttzip_bench_nanos();
        double speed_mbs = ttzip_calc_throughput_mbs(BENCH_CHECKSUM_SIZE, t1 - t0);
        printf(" %-32s | %14.2f   | %14.1f (Hash: 0x%08X)\n", "Adler-32 (ARM64 NEON Vector)", speed_mbs / 1024.0, speed_mbs, hash);
    }

    // 4. Shannon Entropy (SWAR 8.0 Scale)
    {
        uint64_t t0 = ttzip_bench_nanos();
        double entropy = ttzip_estimate_buffer_entropy(buffer, BENCH_CHECKSUM_SIZE);
        uint64_t t1 = ttzip_bench_nanos();
        double speed_mbs = ttzip_calc_throughput_mbs(BENCH_CHECKSUM_SIZE, t1 - t0);
        printf(" %-32s | %14.2f   | %14.1f (Entropy: %.2f)\n", "Shannon Entropy (SWAR/NEON)", speed_mbs / 1024.0, speed_mbs, entropy);
    }

    printf("--------------------------------------------------------------------------------\n\n");
    free(buffer);
}
