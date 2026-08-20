/**
 * @file bench_codecs.c
 * @brief Full-coverage benchmark suite for all single-core compression codecs in TTZip.
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
#include "CTTZipStreamCoder.h"
#include "ttzip_blosclz.h"
#include "lz4.h"
#include "lz4hc.h"

#define BENCH_CORPUS_SIZE (1024 * 1024) // 1MB standard sample

void run_codec_benchmarks_for_corpus(ttzip_corpus_type_t corpus_type) {
    printf("--------------------------------------------------------------------------------\n");
    printf(" 🚀 Benchmark Suite: SOTA Codec Throughput (1MB Corpus: %s)\n", ttzip_corpus_type_name(corpus_type));
    printf("--------------------------------------------------------------------------------\n");
    printf(" %-24s | %-10s | %-12s | %-10s | %-12s | %-10s\n", "Codec (Level)", "Ratio (%)", "Comp (MB/s)", "Comp CPB", "Decomp (MB/s)", "Decomp CPB");
    printf("--------------------------------------------------------------------------------------------------------\n");

    uint8_t* raw = (uint8_t*)malloc(BENCH_CORPUS_SIZE);
    uint8_t* comp = (uint8_t*)malloc(BENCH_CORPUS_SIZE * 2);
    uint8_t* decomp = (uint8_t*)malloc(BENCH_CORPUS_SIZE);

    if (!raw || !comp || !decomp) {
        fprintf(stderr, "Memory allocation failure in bench_codecs\n");
        free(raw); free(comp); free(decomp);
        return;
    }

    ttzip_generate_corpus(corpus_type, raw, BENCH_CORPUS_SIZE);

    // 1. Deflate (libdeflate) L1, L6, L9
    int levels[] = {1, 6, 9};
    struct libdeflate_decompressor* decompressor = libdeflate_alloc_decompressor();

    for (size_t i = 0; i < 3; ++i) {
        int lvl = levels[i];
        struct libdeflate_compressor* compressor = libdeflate_alloc_compressor(lvl);

        uint64_t t0 = ttzip_bench_nanos();
        size_t csize = libdeflate_deflate_compress(compressor, raw, BENCH_CORPUS_SIZE, comp, BENCH_CORPUS_SIZE * 2);
        uint64_t t1 = ttzip_bench_nanos();
        uint64_t comp_elapsed = t1 - t0;
        double comp_speed = ttzip_calc_throughput_mbs(BENCH_CORPUS_SIZE, comp_elapsed);
        double comp_cpb = ttzip_calc_cpb(BENCH_CORPUS_SIZE, comp_elapsed);
        double ratio = ttzip_calc_ratio_pct(csize, BENCH_CORPUS_SIZE);

        uint64_t t2 = ttzip_bench_nanos();
        size_t dsize = 0;
        libdeflate_deflate_decompress(decompressor, comp, csize, decomp, BENCH_CORPUS_SIZE, &dsize);
        uint64_t t3 = ttzip_bench_nanos();
        uint64_t decomp_elapsed = t3 - t2;
        double decomp_speed = ttzip_calc_throughput_mbs(BENCH_CORPUS_SIZE, decomp_elapsed);
        double decomp_cpb = ttzip_calc_cpb(BENCH_CORPUS_SIZE, decomp_elapsed);

        char name[32];
        snprintf(name, sizeof(name), "Deflate (libdeflate L%d)", lvl);
        printf(" %-24s | %8.2f %% | %10.1f   | %8.3f   | %10.1f   | %8.3f\n", name, ratio, comp_speed, comp_cpb, decomp_speed, decomp_cpb);

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
        uint64_t comp_elapsed = t1 - t0;
        double comp_speed = ttzip_calc_throughput_mbs(BENCH_CORPUS_SIZE, comp_elapsed);
        double comp_cpb = ttzip_calc_cpb(BENCH_CORPUS_SIZE, comp_elapsed);
        double ratio = ttzip_calc_ratio_pct(csize, BENCH_CORPUS_SIZE);

        uint64_t t2 = ttzip_bench_nanos();
        ZSTD_decompress(decomp, BENCH_CORPUS_SIZE, comp, csize);
        uint64_t t3 = ttzip_bench_nanos();
        uint64_t decomp_elapsed = t3 - t2;
        double decomp_speed = ttzip_calc_throughput_mbs(BENCH_CORPUS_SIZE, decomp_elapsed);
        double decomp_cpb = ttzip_calc_cpb(BENCH_CORPUS_SIZE, decomp_elapsed);

        char name[32];
        snprintf(name, sizeof(name), "Zstandard (Zstd L%d)", lvl);
        printf(" %-24s | %8.2f %% | %10.1f   | %8.3f   | %10.1f   | %8.3f\n", name, ratio, comp_speed, comp_cpb, decomp_speed, decomp_cpb);
    }

    // 3. Fast-LZMA2 (FL2) L3
    {
        uint64_t t0 = ttzip_bench_nanos();
        size_t csize = FL2_compress(comp, BENCH_CORPUS_SIZE * 2, raw, BENCH_CORPUS_SIZE, 3);
        uint64_t t1 = ttzip_bench_nanos();
        uint64_t comp_elapsed = t1 - t0;
        double comp_speed = ttzip_calc_throughput_mbs(BENCH_CORPUS_SIZE, comp_elapsed);
        double comp_cpb = ttzip_calc_cpb(BENCH_CORPUS_SIZE, comp_elapsed);
        double ratio = ttzip_calc_ratio_pct(csize, BENCH_CORPUS_SIZE);

        uint64_t t2 = ttzip_bench_nanos();
        FL2_decompress(decomp, BENCH_CORPUS_SIZE, comp, csize);
        uint64_t t3 = ttzip_bench_nanos();
        uint64_t decomp_elapsed = t3 - t2;
        double decomp_speed = ttzip_calc_throughput_mbs(BENCH_CORPUS_SIZE, decomp_elapsed);
        double decomp_cpb = ttzip_calc_cpb(BENCH_CORPUS_SIZE, decomp_elapsed);

        printf(" %-24s | %8.2f %% | %10.1f   | %8.3f   | %10.1f   | %8.3f\n", "Fast-LZMA2 (FL2 L3)", ratio, comp_speed, comp_cpb, decomp_speed, decomp_cpb);
    }

    // 4. LZ4 (Fast L1 & HC L9)
    {
        uint64_t t0 = ttzip_bench_nanos();
        int csize = LZ4_compress_fast((const char*)raw, (char*)comp, BENCH_CORPUS_SIZE, BENCH_CORPUS_SIZE * 2, 1);
        uint64_t t1 = ttzip_bench_nanos();
        uint64_t comp_elapsed = t1 - t0;
        double comp_speed = ttzip_calc_throughput_mbs(BENCH_CORPUS_SIZE, comp_elapsed);
        double comp_cpb = ttzip_calc_cpb(BENCH_CORPUS_SIZE, comp_elapsed);
        double ratio = ttzip_calc_ratio_pct(csize, BENCH_CORPUS_SIZE);

        uint64_t t2 = ttzip_bench_nanos();
        LZ4_decompress_safe((const char*)comp, (char*)decomp, csize, BENCH_CORPUS_SIZE);
        uint64_t t3 = ttzip_bench_nanos();
        uint64_t decomp_elapsed = t3 - t2;
        double decomp_speed = ttzip_calc_throughput_mbs(BENCH_CORPUS_SIZE, decomp_elapsed);
        double decomp_cpb = ttzip_calc_cpb(BENCH_CORPUS_SIZE, decomp_elapsed);

        printf(" %-24s | %8.2f %% | %10.1f   | %8.3f   | %10.1f   | %8.3f\n", "LZ4 (Fast L1)", ratio, comp_speed, comp_cpb, decomp_speed, decomp_cpb);
    }
    {
        uint64_t t0 = ttzip_bench_nanos();
        int csize = LZ4_compress_HC((const char*)raw, (char*)comp, BENCH_CORPUS_SIZE, BENCH_CORPUS_SIZE * 2, 9);
        uint64_t t1 = ttzip_bench_nanos();
        uint64_t comp_elapsed = t1 - t0;
        double comp_speed = ttzip_calc_throughput_mbs(BENCH_CORPUS_SIZE, comp_elapsed);
        double comp_cpb = ttzip_calc_cpb(BENCH_CORPUS_SIZE, comp_elapsed);
        double ratio = ttzip_calc_ratio_pct(csize, BENCH_CORPUS_SIZE);

        uint64_t t2 = ttzip_bench_nanos();
        LZ4_decompress_safe((const char*)comp, (char*)decomp, csize, BENCH_CORPUS_SIZE);
        uint64_t t3 = ttzip_bench_nanos();
        uint64_t decomp_elapsed = t3 - t2;
        double decomp_speed = ttzip_calc_throughput_mbs(BENCH_CORPUS_SIZE, decomp_elapsed);
        double decomp_cpb = ttzip_calc_cpb(BENCH_CORPUS_SIZE, decomp_elapsed);

        printf(" %-24s | %8.2f %% | %10.1f   | %8.3f   | %10.1f   | %8.3f\n", "LZ4 (HC L9)", ratio, comp_speed, comp_cpb, decomp_speed, decomp_cpb);
    }

    // 5. Apple LZFSE
    {
        uint64_t t0 = ttzip_bench_nanos();
        size_t csize = lzfse_encode_buffer(comp, BENCH_CORPUS_SIZE * 2, raw, BENCH_CORPUS_SIZE, NULL);
        uint64_t t1 = ttzip_bench_nanos();
        uint64_t comp_elapsed = t1 - t0;
        double comp_speed = ttzip_calc_throughput_mbs(BENCH_CORPUS_SIZE, comp_elapsed);
        double comp_cpb = ttzip_calc_cpb(BENCH_CORPUS_SIZE, comp_elapsed);
        double ratio = ttzip_calc_ratio_pct(csize, BENCH_CORPUS_SIZE);

        uint64_t t2 = ttzip_bench_nanos();
        lzfse_decode_buffer(decomp, BENCH_CORPUS_SIZE, comp, csize, NULL);
        uint64_t t3 = ttzip_bench_nanos();
        uint64_t decomp_elapsed = t3 - t2;
        double decomp_speed = ttzip_calc_throughput_mbs(BENCH_CORPUS_SIZE, decomp_elapsed);
        double decomp_cpb = ttzip_calc_cpb(BENCH_CORPUS_SIZE, decomp_elapsed);

        printf(" %-24s | %8.2f %% | %10.1f   | %8.3f   | %10.1f   | %8.3f\n", "Apple LZFSE", ratio, comp_speed, comp_cpb, decomp_speed, decomp_cpb);
    }

    // 6. Google Snappy
    {
        size_t max_comp = ttzip_snappy_max_compressed_length(BENCH_CORPUS_SIZE);
        size_t csize = max_comp;

        uint64_t t0 = ttzip_bench_nanos();
        ttzip_snappy_compress((const char*)raw, BENCH_CORPUS_SIZE, (char*)comp, &csize);
        uint64_t t1 = ttzip_bench_nanos();
        uint64_t comp_elapsed = t1 - t0;
        double comp_speed = ttzip_calc_throughput_mbs(BENCH_CORPUS_SIZE, comp_elapsed);
        double comp_cpb = ttzip_calc_cpb(BENCH_CORPUS_SIZE, comp_elapsed);
        double ratio = ttzip_calc_ratio_pct(csize, BENCH_CORPUS_SIZE);

        size_t dsize = BENCH_CORPUS_SIZE;
        uint64_t t2 = ttzip_bench_nanos();
        ttzip_snappy_decompress((const char*)comp, csize, (char*)decomp, &dsize);
        uint64_t t3 = ttzip_bench_nanos();
        uint64_t decomp_elapsed = t3 - t2;
        double decomp_speed = ttzip_calc_throughput_mbs(BENCH_CORPUS_SIZE, decomp_elapsed);
        double decomp_cpb = ttzip_calc_cpb(BENCH_CORPUS_SIZE, decomp_elapsed);

        printf(" %-24s | %8.2f %% | %10.1f   | %8.3f   | %10.1f   | %8.3f\n", "Google Snappy", ratio, comp_speed, comp_cpb, decomp_speed, decomp_cpb);
    }

    // 7. Google Brotli
    {
        uint64_t t0 = ttzip_bench_nanos();
        size_t csize = ttzip_brotli_compress(raw, BENCH_CORPUS_SIZE, comp, BENCH_CORPUS_SIZE * 2);
        uint64_t t1 = ttzip_bench_nanos();
        uint64_t comp_elapsed = t1 - t0;
        double comp_speed = ttzip_calc_throughput_mbs(BENCH_CORPUS_SIZE, comp_elapsed);
        double comp_cpb = ttzip_calc_cpb(BENCH_CORPUS_SIZE, comp_elapsed);
        double ratio = ttzip_calc_ratio_pct(csize, BENCH_CORPUS_SIZE);

        uint64_t t2 = ttzip_bench_nanos();
        ttzip_brotli_decompress(comp, csize, decomp, BENCH_CORPUS_SIZE);
        uint64_t t3 = ttzip_bench_nanos();
        uint64_t decomp_elapsed = t3 - t2;
        double decomp_speed = ttzip_calc_throughput_mbs(BENCH_CORPUS_SIZE, decomp_elapsed);
        double decomp_cpb = ttzip_calc_cpb(BENCH_CORPUS_SIZE, decomp_elapsed);

        printf(" %-24s | %8.2f %% | %10.1f   | %8.3f   | %10.1f   | %8.3f\n", "Google Brotli", ratio, comp_speed, comp_cpb, decomp_speed, decomp_cpb);
    }

    // 8. Bzip2 (L1, L9)
    int bz_levels[] = {1, 9};
    for (size_t i = 0; i < 2; ++i) {
        int lvl = bz_levels[i];
        uint64_t t0 = ttzip_bench_nanos();
        size_t csize = ttzip_bzip2_compress(raw, BENCH_CORPUS_SIZE, comp, BENCH_CORPUS_SIZE * 2, lvl);
        uint64_t t1 = ttzip_bench_nanos();
        uint64_t comp_elapsed = t1 - t0;
        double comp_speed = ttzip_calc_throughput_mbs(BENCH_CORPUS_SIZE, comp_elapsed);
        double comp_cpb = ttzip_calc_cpb(BENCH_CORPUS_SIZE, comp_elapsed);
        double ratio = ttzip_calc_ratio_pct(csize, BENCH_CORPUS_SIZE);

        uint64_t t2 = ttzip_bench_nanos();
        ttzip_bzip2_decompress(comp, csize, decomp, BENCH_CORPUS_SIZE);
        uint64_t t3 = ttzip_bench_nanos();
        uint64_t decomp_elapsed = t3 - t2;
        double decomp_speed = ttzip_calc_throughput_mbs(BENCH_CORPUS_SIZE, decomp_elapsed);
        double decomp_cpb = ttzip_calc_cpb(BENCH_CORPUS_SIZE, decomp_elapsed);

        char name[32];
        snprintf(name, sizeof(name), "Bzip2 (libbzip2 L%d)", lvl);
        printf(" %-24s | %8.2f %% | %10.1f   | %8.3f   | %10.1f   | %8.3f\n", name, ratio, comp_speed, comp_cpb, decomp_speed, decomp_cpb);
    }

    // 9. Blosc2 / BloscLZ (L1, L9)
    int blosc_levels[] = {1, 9};
    for (size_t i = 0; i < 2; ++i) {
        int lvl = blosc_levels[i];
        uint64_t t0 = ttzip_bench_nanos();
        int csize = ttzip_blosclz_compress(raw, BENCH_CORPUS_SIZE, comp, BENCH_CORPUS_SIZE * 2, lvl, lvl >= 5 ? 14 : 13);
        uint64_t t1 = ttzip_bench_nanos();
        uint64_t comp_elapsed = t1 - t0;
        double comp_speed = ttzip_calc_throughput_mbs(BENCH_CORPUS_SIZE, comp_elapsed);
        double comp_cpb = ttzip_calc_cpb(BENCH_CORPUS_SIZE, comp_elapsed);
        double ratio = ttzip_calc_ratio_pct(csize > 0 ? (size_t)csize : 0, BENCH_CORPUS_SIZE);

        uint64_t t2 = ttzip_bench_nanos();
        if (csize > 0) {
            ttzip_blosclz_decompress(comp, csize, decomp, BENCH_CORPUS_SIZE);
        }
        uint64_t t3 = ttzip_bench_nanos();
        uint64_t decomp_elapsed = t3 - t2;
        double decomp_speed = ttzip_calc_throughput_mbs(BENCH_CORPUS_SIZE, decomp_elapsed);
        double decomp_cpb = ttzip_calc_cpb(BENCH_CORPUS_SIZE, decomp_elapsed);

        char name[32];
        snprintf(name, sizeof(name), "BloscLZ (Level %d)", lvl);
        printf(" %-24s | %8.2f %% | %10.1f   | %8.3f   | %10.1f   | %8.3f\n", name, ratio, comp_speed, comp_cpb, decomp_speed, decomp_cpb);
    }

    printf("--------------------------------------------------------------------------------\n\n");

    free(raw);
    free(comp);
    free(decomp);
}

void run_codec_benchmarks(void) {
    run_codec_benchmarks_for_corpus(TTZIP_CORPUS_TEXT);
}
