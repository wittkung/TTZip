// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/time.h>

#if defined(__APPLE__)
#include <sys/disk.h>
#endif

/*
 * Micro-benchmark comparing:
 * Mode A: Standard write() streaming without preallocation (on-demand allocation)
 * Mode B: Native F_PREALLOCATE / fallocate followed by write() streaming
 */

static double get_time_sec(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec * 1e-9;
}

static void run_test(const char *test_dir, size_t file_size, size_t block_size, int iterations) {
    char path[512];
    char *buf = malloc(block_size);
    if (!buf) return;
    memset(buf, 0xAA, block_size);

    double total_std_time = 0.0;
    double total_pre_time = 0.0;

    printf("=================================================================\n");
    printf("Benchmark: File Size = %.1f MB, Block Size = %zu KB, Iterations = %d\n",
           file_size / (1024.0 * 1024.0), block_size / 1024, iterations);
    printf("Target Directory: %s\n", test_dir);
    printf("-----------------------------------------------------------------\n");

    for (int it = 0; it < iterations; it++) {
        /* --- Mode A: Standard write without preallocation --- */
        snprintf(path, sizeof(path), "%s/test_std_%d.dat", test_dir, it);
        unlink(path);
        int fd_std = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
        if (fd_std < 0) { perror("open std"); continue; }

        double t0 = get_time_sec();
        size_t written = 0;
        while (written < file_size) {
            size_t to_write = (file_size - written < block_size) ? (file_size - written) : block_size;
            ssize_t w = write(fd_std, buf, to_write);
            if (w <= 0) break;
            written += w;
        }
        fsync(fd_std);
        double t1 = get_time_sec();
        close(fd_std);
        unlink(path);
        total_std_time += (t1 - t0);

        /* --- Mode B: With F_PREALLOCATE upfront --- */
        snprintf(path, sizeof(path), "%s/test_pre_%d.dat", test_dir, it);
        unlink(path);
        int fd_pre = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
        if (fd_pre < 0) { perror("open pre"); continue; }

        double t2 = get_time_sec();
#if defined(__APPLE__) && defined(F_PREALLOCATE)
        fstore_t fst;
        memset(&fst, 0, sizeof(fst));
        fst.fst_flags = F_ALLOCATECONTIG | F_ALLOCATEALL;
        fst.fst_posmode = F_PEOFPOSMODE;
        fst.fst_offset = 0;
        fst.fst_length = (off_t)file_size;
        fst.fst_bytesalloc = 0;
        if (fcntl(fd_pre, F_PREALLOCATE, &fst) == -1) {
            fst.fst_flags = F_ALLOCATEALL;
            fcntl(fd_pre, F_PREALLOCATE, &fst);
        }
#endif
        written = 0;
        while (written < file_size) {
            size_t to_write = (file_size - written < block_size) ? (file_size - written) : block_size;
            ssize_t w = write(fd_pre, buf, to_write);
            if (w <= 0) break;
            written += w;
        }
        fsync(fd_pre);
        double t3 = get_time_sec();
        close(fd_pre);
        unlink(path);
        total_pre_time += (t3 - t2);
    }

    double avg_std_time = total_std_time / iterations;
    double avg_pre_time = total_pre_time / iterations;
    double std_mb_s = (file_size / (1024.0 * 1024.0)) / avg_std_time;
    double pre_mb_s = (file_size / (1024.0 * 1024.0)) / avg_pre_time;
    double diff_pct = ((pre_mb_s - std_mb_s) / std_mb_s) * 100.0;

    printf("Standard Write:     Avg Time: %.4f s | Throughput: %8.1f MB/s\n", avg_std_time, std_mb_s);
    printf("Preallocated Write: Avg Time: %.4f s | Throughput: %8.1f MB/s\n", avg_pre_time, pre_mb_s);
    printf("Throughput Gain:    %+.2f %%\n", diff_pct);
    printf("=================================================================\n\n");

    free(buf);
}

int main(int argc, char **argv) {
    const char *test_dir = (argc > 1) ? argv[1] : "/tmp";
    printf("Running physical preallocation benchmarks on %s (PID: %d)...\n", test_dir, getpid());

    /* Test matrix: 10MB, 100MB, 500MB with 64KB and 1MB streaming blocks */
    run_test(test_dir, 10 * 1024 * 1024, 64 * 1024, 5);
    run_test(test_dir, 100 * 1024 * 1024, 64 * 1024, 5);
    run_test(test_dir, 500 * 1024 * 1024, 128 * 1024, 3);
    run_test(test_dir, 1024 * 1024 * 1024ULL, 256 * 1024, 2);

    return 0;
}
