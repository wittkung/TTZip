/**
 * @file bench_codecs.c
 * @brief Benchmark suite for single-core and multi-core compression codecs in TTZip.
 * 
 * SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
 * Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>. All rights reserved.
 */

#include "ttzip_benchmark_harness.h"
#include "libdeflate.h"
#include "zstd.h"
#include "fast-lzma2.h"
#include "lzfse.h"
#include "CTTZipBridge_Snappy.h"

#define BENCH_CORPUS_SIZE (1024 * 1024) // 1MB standard sample

void run_codec_benchmarks(void) {
    printf("--------------------------------------------------------------------------------\n");
    printf(" 🚀 Benchmark Suite: SOTA Codec Throughput (1MB In-Memory Corpus)\n");
    printf("--------------------------------------------------------------------------------\n");
    printf(" %-24s | %-10s | %-12s | %-12s | %-10s\n", "Codec (Level)", "Ratio (%)", "Comp (MB/s)", "Decomp (MB/s)", "MIPS Score");
    printf("--------------------------------------------------------------------------------\n");

    uint8_t* raw = (uint8_t*)malloc(BENCH_CORPUS_SIZE);
    uint8_t* comp = (uint8_t*)malloc(BENCH_CORPUS_SIZE * 2);
    uint8_t* decomp = (uint8_t*)malloc(BENCH_CORPUS_SIZE);

    if (!raw || !comp || !decomp) {
        fprintf(stderr, "Memory allocation failure in bench_codecs\n");
        free(raw); free(comp); free(decomp);
        return;
    }

    ttzip_generate_corpus(TTZIP_CORPUS_TEXT, raw, BENCH_CORPUS_SIZE);

    // 1. Deflate (libdeflate) L1, L6, L9
    int levels[] = {1, 6, 9};
    struct libdeflate_decompressor* decompressor = libdeflate_alloc_decompressor();

    for (size_t i = 0; i < 3; ++i) {
        int lvl = levels[i];
        struct libdeflate_compressor* compressor = libdeflate_alloc_compressor(lvl);

        // Compress benchmark
        uint64_t t0 = ttzip_bench_nanos();
        size_t csize = libdeflate_deflate_compress(compressor, raw, BENCH_CORPUS_SIZE, comp, BENCH_CORPUS_SIZE * 2);
        uint64_t t1 = ttzip_bench_nanos();
        double comp_speed = ttzip_calc_throughput_mbs(BENCH_CORPUS_SIZE, t1 - t0);
        double ratio = ttzip_calc_ratio_pct(csize, BENCH_CORPUS_SIZE);

        // Decompress benchmark
        uint64_t t2 = ttzip_bench_nanos();
        size_t dsize = 0;
        libdeflate_deflate_decompress(decompressor, comp, csize, decomp, BENCH_CORPUS_SIZE, &dsize);
        uint64_t t3 = ttzip_bench_nanos();
        double decomp_speed = ttzip_calc_throughput_mbs(BENCH_CORPUS_SIZE, t3 - t2);
        double mips = ttzip_calc_mips_score(comp_speed, ratio);

        char name[32];
        snprintf(name, sizeof(name), "Deflate (libdeflate L%d)", lvl);
        printf(" %-24s | %8.2f %% | %10.1f   | %10.1f   | %10.1f\n", name, ratio, comp_speed, decomp_speed, mips);

        libdeflate_free_compressor(compressor);
    }
    libdeflate_free_decompressor(decompressor);

    // 2. Zstandard (Zstd) L1, L3
    int zlevels[] = {1, 3};
    for (size_t i = 0; i < 2; ++i) {
        int lvl = zlevels[i];
        uint64_t t0 = ttzip_bench_nanos();
        size_t csize = ZSTD_compress(comp, BENCH_CORPUS_SIZE * 2, raw, BENCH_CORPUS_SIZE, lvl);
        uint64_t t1 = ttzip_bench_nanos();
        double comp_speed = ttzip_calc_throughput_mbs(BENCH_CORPUS_SIZE, t1 - t0);
        double ratio = ttzip_calc_ratio_pct(csize, BENCH_CORPUS_SIZE);

        uint64_t t2 = ttzip_bench_nanos();
        ZSTD_decompress(decomp, BENCH_CORPUS_SIZE, comp, csize);
        uint64_t t3 = ttzip_bench_nanos();
        double decomp_speed = ttzip_calc_throughput_mbs(BENCH_CORPUS_SIZE, t3 - t2);
        double mips = ttzip_calc_mips_score(comp_speed, ratio);

        char name[32];
        snprintf(name, sizeof(name), "Zstandard (Zstd L%d)", lvl);
        printf(" %-24s | %8.2f %% | %10.1f   | %10.1f   | %10.1f\n", name, ratio, comp_speed, decomp_speed, mips);
    }

    // 3. Fast-LZMA2 (FL2) L3
    {
        uint64_t t0 = ttzip_bench_nanos();
        size_t csize = FL2_compress(comp, BENCH_CORPUS_SIZE * 2, raw, BENCH_CORPUS_SIZE, 3);
        uint64_t t1 = ttzip_bench_nanos();
        double comp_speed = ttzip_calc_throughput_mbs(BENCH_CORPUS_SIZE, t1 - t0);
        double ratio = ttzip_calc_ratio_pct(csize, BENCH_CORPUS_SIZE);

        uint64_t t2 = ttzip_bench_nanos();
        FL2_decompress(decomp, BENCH_CORPUS_SIZE, comp, csize);
        uint64_t t3 = ttzip_bench_nanos();
        double decomp_speed = ttzip_calc_throughput_mbs(BENCH_CORPUS_SIZE, t3 - t2);
        double mips = ttzip_calc_mips_score(comp_speed, ratio);

        printf(" %-24s | %8.2f %% | %10.1f   | %10.1f   | %10.1f\n", "Fast-LZMA2 (FL2 L3)", ratio, comp_speed, decomp_speed, mips);
    }

    // 4. Apple LZFSE
    {
        uint64_t t0 = ttzip_bench_nanos();
        size_t csize = lzfse_encode_buffer(comp, BENCH_CORPUS_SIZE * 2, raw, BENCH_CORPUS_SIZE, NULL);
        uint64_t t1 = ttzip_bench_nanos();
        double comp_speed = ttzip_calc_throughput_mbs(BENCH_CORPUS_SIZE, t1 - t0);
        double ratio = ttzip_calc_ratio_pct(csize, BENCH_CORPUS_SIZE);

        uint64_t t2 = ttzip_bench_nanos();
        lzfse_decode_buffer(decomp, BENCH_CORPUS_SIZE, comp, csize, NULL);
        uint64_t t3 = ttzip_bench_nanos();
        double decomp_speed = ttzip_calc_throughput_mbs(BENCH_CORPUS_SIZE, t3 - t2);
        double mips = ttzip_calc_mips_score(comp_speed, ratio);

        printf(" %-24s | %8.2f %% | %10.1f   | %10.1f   | %10.1f\n", "Apple LZFSE", ratio, comp_speed, decomp_speed, mips);
    }

    // 5. Google Snappy
    {
        size_t max_comp = ttzip_snappy_max_compressed_length(BENCH_CORPUS_SIZE);
        size_t csize = max_comp;

        uint64_t t0 = ttzip_bench_nanos();
        ttzip_snappy_compress((const char*)raw, BENCH_CORPUS_SIZE, (char*)comp, &csize);
        uint64_t t1 = ttzip_bench_nanos();
        double comp_speed = ttzip_calc_throughput_mbs(BENCH_CORPUS_SIZE, t1 - t0);
        double ratio = ttzip_calc_ratio_pct(csize, BENCH_CORPUS_SIZE);

        size_t dsize = BENCH_CORPUS_SIZE;
        uint64_t t2 = ttzip_bench_nanos();
        ttzip_snappy_decompress((const char*)comp, csize, (char*)decomp, &dsize);
        uint64_t t3 = ttzip_bench_nanos();
        double decomp_speed = ttzip_calc_throughput_mbs(BENCH_CORPUS_SIZE, t3 - t2);
        double mips = ttzip_calc_mips_score(comp_speed, ratio);

        printf(" %-24s | %8.2f %% | %10.1f   | %10.1f   | %10.1f\n", "Google Snappy", ratio, comp_speed, decomp_speed, mips);
    }

    printf("--------------------------------------------------------------------------------\n\n");

    free(raw);
    free(comp);
    free(decomp);
}
