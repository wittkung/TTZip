/**
 * @file bench_formats.c
 * @brief Benchmark suite for container packaging and extraction throughput and process Peak RSS in TTZip.
 * 
 * SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
 * Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>. All rights reserved.
 */

#include "ttzip_benchmark_harness.h"
#include "CTTZipBridge_Archive.h"
#include "CTTZipBridge_ZipWrite.h"
#include "ttzip_tar_native.h"
#include "ttzip_tar_zstd_direct.h"
#include "CTTZipCommon.h"
#include <sys/resource.h>
#include <sys/stat.h>
#include <unistd.h>
#include <dirent.h>

static double get_peak_rss_mb(void) {
    struct rusage usage;
    if (getrusage(RUSAGE_SELF, &usage) != 0) return 0.0;
#if defined(__APPLE__)
    return (double)usage.ru_maxrss / (1024.0 * 1024.0);
#else
    return (double)usage.ru_maxrss / 1024.0;
#endif
}

static void recursive_delete(const char* path) {
    DIR* d = opendir(path);
    if (!d) {
        unlink(path);
        return;
    }
    struct dirent* entry;
    while ((entry = readdir(d)) != NULL) {
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) continue;
        char subpath[4096];
        snprintf(subpath, sizeof(subpath), "%s/%s", path, entry->d_name);
        recursive_delete(subpath);
    }
    closedir(d);
    rmdir(path);
}

void run_format_benchmarks(void) {
    printf("--------------------------------------------------------------------------------\n");
    printf(" 📦 Benchmark Suite: Container Format Packaging & Extraction (Multi-File VFS)\n");
    printf("--------------------------------------------------------------------------------\n");
    printf(" %-26s | %-12s | %-14s | %-10s | %-10s\n", "Container Format", "Pack (MB/s)", "Extract (MB/s)", "Ratio (%)", "Peak RSS");
    printf("--------------------------------------------------------------------------------\n");

    const char* base_dir = "build/bench_vfs";
    recursive_delete(base_dir);
    mkdir(base_dir, 0755);

    // Populate 20 synthetic test files (100KB each = 2MB total)
    const size_t file_count = 20;
    const size_t file_size = 100 * 1024;
    size_t total_payload = file_count * file_size;

    uint8_t* sample = (uint8_t*)malloc(file_size);
    if (!sample) {
        recursive_delete(base_dir);
        return;
    }
    ttzip_generate_corpus(TTZIP_CORPUS_TEXT, sample, file_size);

    char file_paths[20][256];
    const char* input_files[20];

    for (size_t i = 0; i < file_count; ++i) {
        snprintf(file_paths[i], sizeof(file_paths[i]), "%s/doc_%03zu.txt", base_dir, i);
        FILE* f = fopen(file_paths[i], "wb");
        if (f) {
            fwrite(sample, 1, file_size, f);
            fflush(f);
            fclose(f);
        }
        input_files[i] = file_paths[i];
    }
    free(sample);

    // 1. ZIP (Parallel Deflate)
    {
        char arc[512], ext[512];
        snprintf(arc, sizeof(arc), "%s/archive.zip", base_dir);
        snprintf(ext, sizeof(ext), "%s/ext_zip", base_dir);

        uint64_t t0 = ttzip_bench_nanos();
        int rc_pack = ttzip_create_zip_parallel_c(arc, input_files, file_count, 6, false, NULL);
        uint64_t t1 = ttzip_bench_nanos();
        double pack_speed = (rc_pack == 0) ? ttzip_calc_throughput_mbs(total_payload, t1 - t0) : 0.0;

        struct stat st;
        size_t asize = (stat(arc, &st) == 0) ? (size_t)st.st_size : 0;
        double ratio = ttzip_calc_ratio_pct(asize, total_payload);

        uint64_t t2 = ttzip_bench_nanos();
        int rc_ext = ttzip_extract_archive(arc, ext);
        uint64_t t3 = ttzip_bench_nanos();
        double ext_speed = (rc_ext == 0) ? ttzip_calc_throughput_mbs(total_payload, t3 - t2) : 0.0;

        printf(" %-26s | %10.1f   | %12.1f   | %8.2f %% | %6.1f MB\n", "ZIP (Parallel Deflate L6)", pack_speed, ext_speed, ratio, get_peak_rss_mb());
        unlink(arc);
        recursive_delete(ext);
    }

    // 2. TAR (Uncompressed)
    {
        char arc[512], ext[512];
        snprintf(arc, sizeof(arc), "%s/archive.tar", base_dir);
        snprintf(ext, sizeof(ext), "%s/ext_tar", base_dir);

        uint64_t t0 = ttzip_bench_nanos();
        int rc_pack = ttzip_create_tar_native_c(arc, "tar", input_files, file_count, false, 0);
        uint64_t t1 = ttzip_bench_nanos();
        double pack_speed = (rc_pack == 0) ? ttzip_calc_throughput_mbs(total_payload, t1 - t0) : 0.0;

        struct stat st;
        size_t asize = (stat(arc, &st) == 0) ? (size_t)st.st_size : 0;
        double ratio = ttzip_calc_ratio_pct(asize, total_payload);

        uint64_t t2 = ttzip_bench_nanos();
        int rc_ext = ttzip_extract_tar_native_c(arc, ext, false);
        uint64_t t3 = ttzip_bench_nanos();
        double ext_speed = (rc_ext == 0) ? ttzip_calc_throughput_mbs(total_payload, t3 - t2) : 0.0;

        printf(" %-26s | %10.1f   | %12.1f   | %8.2f %% | %6.1f MB\n", "TAR (POSIX UStar)", pack_speed, ext_speed, ratio, get_peak_rss_mb());
        unlink(arc);
        recursive_delete(ext);
    }

    // 3. TAR.GZ (Parallel Gzip)
    {
        char arc[512], ext[512];
        snprintf(arc, sizeof(arc), "%s/archive.tar.gz", base_dir);
        snprintf(ext, sizeof(ext), "%s/ext_targz", base_dir);

        uint64_t t0 = ttzip_bench_nanos();
        int rc_pack = ttzip_create_tar_native_c(arc, "tar.gz", input_files, file_count, false, 6);
        uint64_t t1 = ttzip_bench_nanos();
        double pack_speed = (rc_pack == 0) ? ttzip_calc_throughput_mbs(total_payload, t1 - t0) : 0.0;

        struct stat st;
        size_t asize = (stat(arc, &st) == 0) ? (size_t)st.st_size : 0;
        double ratio = ttzip_calc_ratio_pct(asize, total_payload);

        uint64_t t2 = ttzip_bench_nanos();
        int rc_ext = ttzip_extract_tar_native_c(arc, ext, false);
        uint64_t t3 = ttzip_bench_nanos();
        double ext_speed = (rc_ext == 0) ? ttzip_calc_throughput_mbs(total_payload, t3 - t2) : 0.0;

        printf(" %-26s | %10.1f   | %12.1f   | %8.2f %% | %6.1f MB\n", "TAR.GZ (Parallel Gzip)", pack_speed, ext_speed, ratio, get_peak_rss_mb());
        unlink(arc);
        recursive_delete(ext);
    }

    // 4. TAR.ZST (Direct Zstandard)
    {
        char arc[512], ext[512];
        snprintf(arc, sizeof(arc), "%s/archive.tar.zst", base_dir);
        snprintf(ext, sizeof(ext), "%s/ext_tarzst", base_dir);

        uint64_t t0 = ttzip_bench_nanos();
        int rc_pack = ttzip_create_tar_zstd_direct_c(arc, input_files, file_count, 3, false);
        uint64_t t1 = ttzip_bench_nanos();
        double pack_speed = (rc_pack == 0) ? ttzip_calc_throughput_mbs(total_payload, t1 - t0) : 0.0;

        struct stat st;
        size_t asize = (stat(arc, &st) == 0) ? (size_t)st.st_size : 0;
        double ratio = ttzip_calc_ratio_pct(asize, total_payload);

        uint64_t t2 = ttzip_bench_nanos();
        int rc_ext = ttzip_extract_tar_native_c(arc, ext, false);
        uint64_t t3 = ttzip_bench_nanos();
        double ext_speed = (rc_ext == 0) ? ttzip_calc_throughput_mbs(total_payload, t3 - t2) : 0.0;

        printf(" %-26s | %10.1f   | %12.1f   | %8.2f %% | %6.1f MB\n", "TAR.ZST (Direct Zstd L3)", pack_speed, ext_speed, ratio, get_peak_rss_mb());
        unlink(arc);
        recursive_delete(ext);
    }

    printf("--------------------------------------------------------------------------------\n\n");
    recursive_delete(base_dir);
}
