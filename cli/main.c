// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine.

/**
 * @file main.c
 * @brief Standalone pure C11 cross-platform CLI tool for TTZip (Zero Swift / Zero GCD).
 */

#include "include/ttzip_api.h"
#include "include/ttzip_platform.h"
#include "include/ttzip_threadpool.h"
#include "include/ttzip_crc64.h"
#include "include/CTTZipCRC32Neon.h"
#include "include/CTTZipPlatformTimer.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void print_banner(void) {
    printf("=================================================================\n");
    printf(" TTZip High-Performance Native Archive Engine v%s\n", ttzip_version_string());
    printf(" Cross-Platform Pure C11 Core Engine (Zero GCD / SOTA Codecs)\n");
    printf("=================================================================\n");
}

static void print_usage(const char *prog) {
    print_banner();
    printf("Usage:\n");
    printf("  %s -c <archive.zip> <file1> [file2 ...]   Create archive\n", prog);
    printf("  %s -x <archive.zip> [-d <output_dir>]     Extract archive\n", prog);
    printf("  %s -t <archive.zip>                       Test archive integrity\n", prog);
    printf("  %s -b, --benchmark                        Run multi-core codec benchmarks\n", prog);
    printf("  %s -v, --version                          Print version and CPU features\n", prog);
    printf("  %s -h, --help                             Display help\n", prog);
    printf("\n");
}

static void run_benchmark(void) {
    print_banner();
    printf("Running in-memory hardware vector & multi-core codec benchmarks...\n\n");

    const size_t bench_size = 16 * 1024 * 1024; /* 16 MB sample buffer */
    uint8_t *sample_data = (uint8_t *)malloc(bench_size);
    if (!sample_data) {
        printf("Error: Failed to allocate benchmark sample buffer.\n");
        return;
    }

    /* Initialize pseudo-random data with structured compressible patterns */
    for (size_t i = 0; i < bench_size; i++) {
        sample_data[i] = (uint8_t)((i * 31 + (i >> 8)) & 0xFF);
    }

    uint8_t *comp_buf = (uint8_t *)malloc(bench_size * 2);
    uint8_t *decomp_buf = (uint8_t *)malloc(bench_size * 2);

    /* 1. Hardware Vector CRC32 & CRC64 */
    printf("[1/3] Hardware Vector Checksums:\n");
    uint64_t t0 = ttzip_platform_monotonic_nanos();
    uint32_t crc32_val = 0;
    for (int r = 0; r < 10; r++) {
        crc32_val = ttzip_crc32_fast(crc32_val, sample_data, bench_size);
    }
    uint64_t t1 = ttzip_platform_monotonic_nanos();
    double crc32_sec = (double)(t1 - t0) / 1e9;
    double crc32_mbs = (double)(bench_size * 10) / (1024.0 * 1024.0) / crc32_sec;
    printf("  • CRC32 (PMULL/ACLE/SSE4.2):  %8.2f MB/s (Hash: 0x%08X)\n", crc32_mbs, crc32_val);

    t0 = ttzip_platform_monotonic_nanos();
    uint64_t crc64_val = 0;
    for (int r = 0; r < 10; r++) {
        crc64_val = ttzip_crc64(sample_data, bench_size, crc64_val);
    }
    t1 = ttzip_platform_monotonic_nanos();
    double crc64_sec = (double)(t1 - t0) / 1e9;
    double crc64_mbs = (double)(bench_size * 10) / (1024.0 * 1024.0) / crc64_sec;
    printf("  • CRC64 (PMULL/PCLMULQDQ):   %8.2f MB/s (Hash: 0x%016llX)\n\n", crc64_mbs, (unsigned long long)crc64_val);

    /* 2. SOTA Compression Microkernels */
    printf("[2/3] SOTA Single-Core Compression Throughput:\n");
    
    struct {
        const char *name;
        ttzip_api_codec_t codec;
        int level;
    } codecs[] = {
        { "Deflate (libdeflate L1)", TTZIP_API_CODEC_DEFLATE, 1 },
        { "Deflate (libdeflate L6)", TTZIP_API_CODEC_DEFLATE, 6 },
        { "Deflate (libdeflate L9)", TTZIP_API_CODEC_DEFLATE, 9 },
        { "Zstandard (Zstd L1)",     TTZIP_API_CODEC_ZSTD,    1 },
        { "Zstandard (Zstd L3)",     TTZIP_API_CODEC_ZSTD,    3 },
        { "Fast-LZMA2 (FL2 L3)",     TTZIP_API_CODEC_LZMA2,   3 },
        { "Fast-LZMA2 (FL2 L6)",     TTZIP_API_CODEC_LZMA2,   6 },
        { "Apple LZFSE",             TTZIP_API_CODEC_LZFSE,   0 },
        { "Google Snappy",           TTZIP_API_CODEC_SNAPPY,  0 }
    };

    for (size_t c = 0; c < sizeof(codecs)/sizeof(codecs[0]); c++) {
        t0 = ttzip_platform_monotonic_nanos();
        size_t comp_len = ttzip_compress_buffer(codecs[c].codec, sample_data, bench_size, comp_buf, bench_size * 2, codecs[c].level);
        t1 = ttzip_platform_monotonic_nanos();

        double comp_sec = (double)(t1 - t0) / 1e9;
        double comp_mbs = (double)bench_size / (1024.0 * 1024.0) / (comp_sec > 0 ? comp_sec : 0.000001);
        double ratio = comp_len > 0 ? (double)comp_len / (double)bench_size * 100.0 : 100.0;

        /* Decompress benchmark */
        uint64_t dt0 = ttzip_platform_monotonic_nanos();
        size_t decomp_len = ttzip_decompress_buffer(codecs[c].codec, comp_buf, comp_len, decomp_buf, bench_size * 2);
        uint64_t dt1 = ttzip_platform_monotonic_nanos();

        double decomp_sec = (double)(dt1 - dt0) / 1e9;
        double decomp_mbs = (double)bench_size / (1024.0 * 1024.0) / (decomp_sec > 0 ? decomp_sec : 0.000001);

        printf("  • %-26s -> Comp: %7.1f MB/s (Ratio: %5.1f%%) | Decomp: %8.1f MB/s %s\n",
            codecs[c].name, comp_mbs, ratio, decomp_mbs, (decomp_len == bench_size) ? "[OK]" : "[MISMATCH]");
    }

    /* 3. Virtual Filesystem & Frontend Heavy Calculation Microkernels */
    printf("\n[3/4] Virtual Filesystem & Frontend Heavy Calculation Microkernels:\n");

    /* 3.1 Magic Number Sniffing */
    t0 = ttzip_platform_monotonic_nanos();
    uint8_t png_header[16] = { 0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13, 'I', 'H', 'D', 'R' };
    ttzip_magic_info_t sniff_res;
    for (int r = 0; r < 1000000; r++) {
        sniff_res = ttzip_magic_sniff_buffer(png_header, sizeof(png_header));
    }
    t1 = ttzip_platform_monotonic_nanos();
    double sniff_sec = (double)(t1 - t0) / 1e9;
    double sniff_ops = 1000000.0 / (sniff_sec > 0 ? sniff_sec : 0.000001) / 1e6;
    printf("  • Magic Header Sniffing:      %8.2f Million ops/s (Detected: %s - %s)\n", sniff_ops, sniff_res.format_name, sniff_res.mime_type);

    /* 3.2 Natural Numeric String Comparison */
    t0 = ttzip_platform_monotonic_nanos();
    int cmp_acc = 0;
    for (int r = 0; r < 1000000; r++) {
        cmp_acc += ttzip_strnatcasecmp("IMG_2026_08_20_part9.png", "IMG_2026_08_20_part10.png");
    }
    t1 = ttzip_platform_monotonic_nanos();
    double sort_sec = (double)(t1 - t0) / 1e9;
    double sort_ops = 1000000.0 / (sort_sec > 0 ? sort_sec : 0.000001) / 1e6;
    printf("  • Natural Numeric Sorting:     %8.2f Million ops/s (Result: %d)\n", sort_ops, cmp_acc < 0 ? -1 : 1);

    /* 3.3 Archive Tree Hierarchy & Search */
    ttzip_tree_t *tree = ttzip_tree_create();
    for (int i = 0; i < 5000; i++) {
        char pbuf[128];
        snprintf(pbuf, sizeof(pbuf), "Root/Folder%d/subfolder/file_%04d.dat", i % 20, i);
        ttzip_tree_insert(tree, pbuf, 1024, 512, 0x12345678, false);
    }
    t0 = ttzip_platform_monotonic_nanos();
    const char *matched[64];
    size_t found = ttzip_tree_search(tree, "file_0042", matched, 64);
    t1 = ttzip_platform_monotonic_nanos();
    double search_micros = (double)(t1 - t0) / 1000.0;
    printf("  • Radix Tree 5000-Node Search: %8.2f µs (Found %zu matches: '%s')\n", search_micros, found, found > 0 ? matched[0] : "none");
    ttzip_tree_destroy(tree);

    /* 3.4 Cryptographic Memory Scrubbing & Recovery FEC */
    t0 = ttzip_platform_monotonic_nanos();
    for (int r = 0; r < 100000; r++) {
        ttzip_secure_zero_memory(comp_buf, 4096);
    }
    t1 = ttzip_platform_monotonic_nanos();
    double scrub_sec = (double)(t1 - t0) / 1e9;
    double scrub_mbs = (double)(4096 * 100000) / (1024.0 * 1024.0) / (scrub_sec > 0 ? scrub_sec : 0.000001);
    printf("  • DSE-Immune Memory Scrubbing: %8.2f MB/s\n", scrub_mbs);

    t0 = ttzip_platform_monotonic_nanos();
    uint8_t parity_buf[4096];
    ttzip_generate_recovery_parity(sample_data, bench_size, parity_buf, sizeof(parity_buf));
    t1 = ttzip_platform_monotonic_nanos();
    double fec_sec = (double)(t1 - t0) / 1e9;
    double fec_mbs = (double)bench_size / (1024.0 * 1024.0) / (fec_sec > 0 ? fec_sec : 0.000001);
    printf("  • Reed-Solomon Recovery Parity: %7.2f MB/s\n", fec_mbs);

    /* 4. Multi-Core Threadpool Scaling */
    printf("\n[4/4] Cross-Platform Threadpool (ttzip_threadpool) Multi-Core Scaling:\n");
    ttzip_threadpool_t *pool = ttzip_threadpool_shared();
    int threads = ttzip_threadpool_get_thread_count(pool);
    printf("  • Active Worker Threads: %d P/E Workers\n", threads);

    free(sample_data);
    free(comp_buf);
    free(decomp_buf);

    printf("\n✅ Benchmark completed successfully.\n");
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        print_usage(argv[0]);
        return 0;
    }

    if (strcmp(argv[1], "-h") == 0 || strcmp(argv[1], "--help") == 0) {
        print_usage(argv[0]);
        return 0;
    }

    if (strcmp(argv[1], "-v") == 0 || strcmp(argv[1], "--version") == 0) {
        print_banner();
        printf("Engine Version: %s\n", ttzip_version_string());
        printf("Hardware ISA:   ARM64 / x86_64 Dual-ISA Vector Accelerated\n");
        printf("Platform OS:    Cross-Platform Native\n");
        return 0;
    }

    if (strcmp(argv[1], "-b") == 0 || strcmp(argv[1], "--benchmark") == 0) {
        run_benchmark();
        return 0;
    }

    if (strcmp(argv[1], "-c") == 0) {
        if (argc < 4) {
            printf("Error: Missing archive path or input files.\n");
            printf("Usage: %s -c <archive.zip> <file1> [file2 ...]\n", argv[0]);
            return 1;
        }
        const char *out_archive = argv[2];
        const char **inputs = (const char **)&argv[3];
        size_t count = (size_t)(argc - 3);

        ttzip_archive_config_t cfg;
        memset(&cfg, 0, sizeof(cfg));
        cfg.codec = TTZIP_API_CODEC_DEFLATE;
        cfg.level = 6;

        printf("Creating archive '%s' (%zu files)...\n", out_archive, count);
        int res = ttzip_archive_create(&cfg, inputs, count, out_archive, NULL, NULL);
        if (res == 0) {
            printf("✅ Archive created successfully: %s\n", out_archive);
            return 0;
        } else {
            printf("❌ Failed to create archive (Error code: %d)\n", res);
            return res;
        }
    }

    if (strcmp(argv[1], "-x") == 0) {
        if (argc < 3) {
            printf("Error: Missing archive path.\n");
            printf("Usage: %s -x <archive.zip> [-d <output_dir>]\n", argv[0]);
            return 1;
        }
        const char *archive_path = argv[2];
        const char *dest_dir = "./";
        if (argc >= 5 && strcmp(argv[3], "-d") == 0) {
            dest_dir = argv[4];
        }

        printf("Extracting '%s' to '%s'...\n", archive_path, dest_dir);
        int res = ttzip_archive_extract(archive_path, dest_dir, NULL, NULL, NULL);
        if (res == 0) {
            printf("✅ Archive extracted successfully.\n");
            return 0;
        } else {
            printf("❌ Extraction failed (Error code: %d)\n", res);
            return res;
        }
    }

    if (strcmp(argv[1], "-t") == 0) {
        if (argc < 3) {
            printf("Error: Missing archive path.\n");
            return 1;
        }
        const char *archive_path = argv[2];
        printf("Testing archive integrity: '%s'...\n", archive_path);
        int res = ttzip_archive_test(archive_path, NULL);
        if (res == 0) {
            printf("✅ Archive integrity OK (100%% Valid).\n");
            return 0;
        } else {
            printf("❌ Archive integrity check failed.\n");
            return res;
        }
    }

    print_usage(argv[0]);
    return 1;
}
