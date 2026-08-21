// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/CTTZipBridge.h"
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/param.h>
#include <spawn.h>
#include <errno.h>
#include <sys/wait.h>

#if defined(__APPLE__)
#include <TargetConditionals.h>
#include <sys/qos.h>
#include <pthread/qos.h>
#include <pthread/spawn.h>
#include <crt_externs.h>
static char** get_process_environ(void) { return *_NSGetEnviron(); }
#else
extern char** environ;
static char** get_process_environ(void) { return environ; }
#endif

#include "zopfli/deflate.h"
#include "zopfli/zopfli.h"

// MARK: - 1. Version
const char* cttzip_bridge_version(void) {
    return "1.7.2-converged";
}

// MARK: - 2. Fast POSIX Spawn
static int get_cached_dev_null_fd(void) {
    static int s_fd = -1;
    if (s_fd < 0) {
        int fd = open("/dev/null", O_RDWR);
        if (fd >= 0) s_fd = fd;
    }
    return s_fd;
}

int ttzip_core_posix_spawn_fast(
    const char* bin_path,
    const char* const* argv,
    const char* working_dir
) {
    if (!bin_path || !argv) return -1;
    posix_spawn_file_actions_t actions;
    posix_spawn_file_actions_init(&actions);
    
    int null_fd = get_cached_dev_null_fd();
    if (null_fd >= 0) {
        posix_spawn_file_actions_adddup2(&actions, null_fd, STDIN_FILENO);
        posix_spawn_file_actions_adddup2(&actions, null_fd, STDOUT_FILENO);
        posix_spawn_file_actions_adddup2(&actions, null_fd, STDERR_FILENO);
    }
    if (working_dir && working_dir[0] != '\0') {
#if defined(__APPLE__)
        posix_spawn_file_actions_addchdir_np(&actions, working_dir);
#endif
    }
    
    posix_spawnattr_t attr;
    posix_spawnattr_init(&attr);
#if defined(__APPLE__)
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    posix_spawnattr_set_qos_class_np(&attr, QOS_CLASS_USER_INTERACTIVE);
    posix_spawnattr_setflags(&attr, POSIX_SPAWN_CLOEXEC_DEFAULT);
#endif

    pid_t pid;
    int status = posix_spawn(&pid, bin_path, &actions, &attr, (char* const*)argv, get_process_environ());
    posix_spawnattr_destroy(&attr);
    posix_spawn_file_actions_destroy(&actions);
    if (status != 0) return status;
    
    int wstatus;
    while (waitpid(pid, &wstatus, 0) < 0) {
        if (errno != EINTR) return -1;
    }
    if (WIFEXITED(wstatus)) return WEXITSTATUS(wstatus);
    if (WIFSIGNALED(wstatus)) return 128 + WTERMSIG(wstatus);
    return -1;
}

// MARK: - 3. Reed-Solomon Erasure Coding
static uint8_t g_rs_exp[512];
static uint8_t g_rs_log[256];
static bool g_rs_initialized = false;

static void ttzip_rs_init_tables(void) {
    if (g_rs_initialized) return;
    uint16_t x = 1;
    for (int i = 0; i < 255; i++) {
        g_rs_exp[i] = g_rs_exp[i + 255] = (uint8_t)x;
        x = (x << 1) ^ (x >= 128 ? 0x11D : 0);
    }
    g_rs_exp[510] = g_rs_exp[0];
    g_rs_exp[511] = g_rs_exp[1];
    for (int i = 0; i < 255; i++) g_rs_log[g_rs_exp[i]] = (uint8_t)i;
    g_rs_log[0] = 0;
    g_rs_initialized = true;
}

uint8_t ttzip_rs_gf_mul(uint8_t a, uint8_t b) {
    if (!g_rs_initialized) ttzip_rs_init_tables();
    if (a == 0 || b == 0) return 0;
    return g_rs_exp[(size_t)g_rs_log[a] + (size_t)g_rs_log[b]];
}

uint8_t ttzip_rs_gf_inv(uint8_t a) {
    if (!g_rs_initialized) ttzip_rs_init_tables();
    if (a == 0) return 0;
    return g_rs_exp[255 - (size_t)g_rs_log[a]];
}

int ttzip_rs_create_cauchy_matrix(size_t rows_m, size_t cols_k, uint8_t* out_matrix) {
    if (!out_matrix || rows_m == 0 || cols_k == 0) return -1;
    if (!g_rs_initialized) ttzip_rs_init_tables();
    for (size_t i = 0; i < rows_m; i++) {
        for (size_t j = 0; j < cols_k; j++) {
            out_matrix[i * cols_k + j] = ttzip_rs_gf_inv((uint8_t)i ^ (uint8_t)(rows_m + j));
        }
    }
    return 0;
}

static int ttzip_rs_invert_matrix(const uint8_t* in_matrix, size_t n, uint8_t* out_matrix) {
    if (!in_matrix || !out_matrix || n == 0) return -1;
    if (!g_rs_initialized) ttzip_rs_init_tables();
    size_t width = n * 2;
    uint8_t* aug = (uint8_t*)malloc(n * width);
    if (!aug) return -1;

    for (size_t i = 0; i < n; i++) {
        for (size_t j = 0; j < n; j++) aug[i * width + j] = in_matrix[i * n + j];
        for (size_t j = n; j < width; j++) aug[i * width + j] = (j - n == i) ? 1 : 0;
    }

    for (size_t col = 0; col < n; col++) {
        size_t pivot_row = col;
        while (pivot_row < n && aug[pivot_row * width + col] == 0) pivot_row++;
        if (pivot_row == n) { free(aug); return -1; }
        if (pivot_row != col) {
            for (size_t k = 0; k < width; k++) {
                uint8_t tmp = aug[col * width + k];
                aug[col * width + k] = aug[pivot_row * width + k];
                aug[pivot_row * width + k] = tmp;
            }
        }
        uint8_t pivot_inv = ttzip_rs_gf_inv(aug[col * width + col]);
        for (size_t k = 0; k < width; k++) aug[col * width + k] = ttzip_rs_gf_mul(aug[col * width + k], pivot_inv);
        for (size_t r = 0; r < n; r++) {
            if (r == col) continue;
            uint8_t factor = aug[r * width + col];
            if (factor == 0) continue;
            for (size_t k = 0; k < width; k++) aug[r * width + k] ^= ttzip_rs_gf_mul(aug[col * width + k], factor);
        }
    }

    for (size_t i = 0; i < n; i++) {
        for (size_t j = 0; j < n; j++) out_matrix[i * n + j] = aug[i * width + n + j];
    }
    free(aug);
    return 0;
}

int ttzip_rs_encode_neon(
    const uint8_t* const* data_ptrs,
    size_t k_data,
    uint8_t* const* parity_ptrs,
    size_t m_parity,
    size_t block_size
) {
    if (!data_ptrs || !parity_ptrs || k_data == 0 || m_parity == 0 || block_size == 0) return -1;
    if (!g_rs_initialized) ttzip_rs_init_tables();
    uint8_t* matrix = (uint8_t*)malloc(m_parity * k_data);
    if (!matrix) return -1;
    if (ttzip_rs_create_cauchy_matrix(m_parity, k_data, matrix) != 0) { free(matrix); return -1; }

    for (size_t p = 0; p < m_parity; p++) {
        uint8_t* dst = parity_ptrs[p];
        if (!dst) continue;
        memset(dst, 0, block_size);
        for (size_t d = 0; d < k_data; d++) {
            const uint8_t* src = data_ptrs[d];
            uint8_t coeff = matrix[p * k_data + d];
            if (!src || coeff == 0) continue;
            for (size_t b = 0; b < block_size; b++) dst[b] ^= ttzip_rs_gf_mul(src[b], coeff);
        }
    }
    free(matrix);
    return 0;
}

int ttzip_rs_decode_neon(
    const uint8_t* const* available_ptrs,
    const int32_t* available_indices,
    size_t num_available,
    size_t k_data,
    size_t m_parity,
    const int32_t* missing_indices,
    size_t num_missing,
    uint8_t* const* reconstructed_ptrs,
    size_t block_size
) {
    if (!available_ptrs || !available_indices || !missing_indices || !reconstructed_ptrs) return -1;
    if (num_available < k_data || num_missing == 0 || block_size == 0) return -1;
    if (!g_rs_initialized) ttzip_rs_init_tables();

    uint8_t* cauchy = (uint8_t*)malloc(m_parity * k_data);
    if (!cauchy) return -1;
    ttzip_rs_create_cauchy_matrix(m_parity, k_data, cauchy);

    uint8_t* submatrix = (uint8_t*)malloc(k_data * k_data);
    if (!submatrix) { free(cauchy); return -1; }

    for (size_t r = 0; r < k_data; r++) {
        int32_t idx = available_indices[r];
        if (idx < (int32_t)k_data) {
            for (size_t c = 0; c < k_data; c++) submatrix[r * k_data + c] = (c == (size_t)idx) ? 1 : 0;
        } else {
            size_t parity_row = (size_t)(idx - (int32_t)k_data);
            for (size_t c = 0; c < k_data; c++) submatrix[r * k_data + c] = cauchy[parity_row * k_data + c];
        }
    }

    uint8_t* inv_matrix = (uint8_t*)malloc(k_data * k_data);
    if (!inv_matrix) { free(cauchy); free(submatrix); return -1; }

    if (ttzip_rs_invert_matrix(submatrix, k_data, inv_matrix) != 0) {
        free(cauchy); free(submatrix); free(inv_matrix);
        return -1;
    }

    for (size_t m = 0; m < num_missing; m++) {
        int32_t missing_idx = missing_indices[m];
        uint8_t* dst = reconstructed_ptrs[m];
        if (!dst || missing_idx >= (int32_t)k_data) continue;
        memset(dst, 0, block_size);
        for (size_t a = 0; a < k_data; a++) {
            const uint8_t* src = available_ptrs[a];
            uint8_t coeff = inv_matrix[(size_t)missing_idx * k_data + a];
            if (!src || coeff == 0) continue;
            for (size_t b = 0; b < block_size; b++) dst[b] ^= ttzip_rs_gf_mul(src[b], coeff);
        }
    }

    free(cauchy);
    free(submatrix);
    free(inv_matrix);
    return 0;
}

// MARK: - 4. Zopfli Deflate Block
size_t ttzip_zopfli_compress_block_with_history(
    const uint8_t *in,
    size_t in_size,
    const uint8_t *history,
    size_t history_size,
    uint8_t *out,
    size_t out_capacity,
    const ttzip_zopfli_options_t *options,
    bool is_final
) {
    if (!in || in_size == 0 || !out || out_capacity == 0) return 0;

    ZopfliOptions zopt;
    ZopfliInitOptions(&zopt);
    zopt.numiterations = (options && options->num_iterations > 0) ? options->num_iterations : 15;
    zopt.blocksplittingmax = (options && options->max_block_splits > 0) ? options->max_block_splits : 15;
    zopt.verbose = 0;
    zopt.verbose_more = 0;

    size_t hist_len = (history && history_size > 0) ? (history_size > 32768 ? 32768 : history_size) : 0;
    const uint8_t *hist_ptr = hist_len > 0 ? (history + history_size - hist_len) : NULL;

    unsigned char *zout = NULL;
    size_t zoutsize = 0;
    unsigned char bp = 0;

    if (hist_len > 0) {
        if (hist_ptr + hist_len == in) {
            ZopfliDeflatePart(&zopt, 2, is_final, hist_ptr, hist_len, hist_len + in_size, &bp, &zout, &zoutsize);
        } else {
            size_t total_buf_size = hist_len + in_size;
            uint8_t *combined = (uint8_t *)malloc(total_buf_size);
            if (!combined) return 0;
            memcpy(combined, hist_ptr, hist_len);
            memcpy(combined + hist_len, in, in_size);
            ZopfliDeflatePart(&zopt, 2, is_final, combined, hist_len, total_buf_size, &bp, &zout, &zoutsize);
            free(combined);
        }
    } else {
        ZopfliDeflatePart(&zopt, 2, is_final, in, 0, in_size, &bp, &zout, &zoutsize);
    }

    if (!is_final && zout && zoutsize > 0) {
        ZopfliAddSyncFlushBlock(&bp, &zout, &zoutsize);
    }

    if (!zout || zoutsize == 0 || zoutsize > out_capacity) {
        if (zout) free(zout);
        return 0;
    }

    memcpy(out, zout, zoutsize);
    free(zout);
    return zoutsize;
}

// MARK: - 5. CRC-64 (ECMA-182)
static uint64_t s_crc64_table[256];
static bool s_crc64_initialized = false;

static void ttzip_crc64_init_table(void) {
    if (s_crc64_initialized) return;
    uint64_t poly = 0x42F0E1EBA9EA3693ULL;
    for (int i = 0; i < 256; i++) {
        uint64_t crc = (uint64_t)i;
        for (int j = 0; j < 8; j++) {
            crc = (crc & 1) ? ((crc >> 1) ^ poly) : (crc >> 1);
        }
        s_crc64_table[i] = crc;
    }
    s_crc64_initialized = true;
}

uint64_t ttzip_crc64(const uint8_t *buf, size_t size, uint64_t crc) {
    if (!buf || size == 0) return crc;
    if (!s_crc64_initialized) ttzip_crc64_init_table();
    crc = ~crc;
    for (size_t i = 0; i < size; i++) {
        crc = s_crc64_table[(uint8_t)(crc ^ buf[i])] ^ (crc >> 8);
    }
    return ~crc;
}
