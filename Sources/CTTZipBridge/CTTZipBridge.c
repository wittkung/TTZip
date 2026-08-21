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
#include <archive.h>
#include <archive_entry.h>

#if defined(__APPLE__)
#include <TargetConditionals.h>
#include <sys/qos.h>
#include <pthread/qos.h>
#include <pthread/spawn.h>
#include <crt_externs.h>
static char** get_process_environ(void) {
    return *_NSGetEnviron();
}
#else
extern char** environ;
static char** get_process_environ(void) {
    return environ;
}
#endif

#if defined(__ARM_NEON) || defined(__ARM_NEON__) || defined(__aarch64__)
#include <arm_neon.h>
#define TTZIP_HAS_NEON 1
#else
#define TTZIP_HAS_NEON 0
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
    
    if (working_dir && strlen(working_dir) > 0) {
#if defined(__APPLE__)
        posix_spawn_file_actions_addchdir_np(&actions, working_dir);
#endif
    }
    
    posix_spawnattr_t attr;
    posix_spawnattr_init(&attr);
#if defined(__APPLE__)
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    posix_spawnattr_set_qos_class_np(&attr, QOS_CLASS_USER_INTERACTIVE);
    short flags = POSIX_SPAWN_CLOEXEC_DEFAULT;
    posix_spawnattr_setflags(&attr, flags);
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
    
    if (WIFEXITED(wstatus)) {
        return WEXITSTATUS(wstatus);
    } else if (WIFSIGNALED(wstatus)) {
        return 128 + WTERMSIG(wstatus);
    }
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
        g_rs_exp[i] = (uint8_t)x;
        g_rs_exp[i + 255] = (uint8_t)x;
        x = (x << 1) ^ (x >= 128 ? 0x11D : 0);
    }
    g_rs_exp[510] = g_rs_exp[0];
    g_rs_exp[511] = g_rs_exp[1];

    for (int i = 0; i < 255; i++) {
        g_rs_log[g_rs_exp[i]] = (uint8_t)i;
    }
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
        uint8_t xi = (uint8_t)i;
        for (size_t j = 0; j < cols_k; j++) {
            uint8_t yj = (uint8_t)(rows_m + j);
            uint8_t diff = xi ^ yj;
            out_matrix[i * cols_k + j] = ttzip_rs_gf_inv(diff);
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
        for (size_t j = 0; j < n; j++) {
            aug[i * width + j] = in_matrix[i * n + j];
        }
        for (size_t j = n; j < width; j++) {
            aug[i * width + j] = (j - n == i) ? 1 : 0;
        }
    }

    for (size_t col = 0; col < n; col++) {
        size_t pivot_row = col;
        while (pivot_row < n && aug[pivot_row * width + col] == 0) {
            pivot_row++;
        }
        if (pivot_row == n) {
            free(aug);
            return -1;
        }
        if (pivot_row != col) {
            for (size_t k = 0; k < width; k++) {
                uint8_t tmp = aug[col * width + k];
                aug[col * width + k] = aug[pivot_row * width + k];
                aug[pivot_row * width + k] = tmp;
            }
        }
        uint8_t pivot = aug[col * width + col];
        uint8_t pivot_inv = ttzip_rs_gf_inv(pivot);
        for (size_t k = 0; k < width; k++) {
            aug[col * width + k] = ttzip_rs_gf_mul(aug[col * width + k], pivot_inv);
        }
        for (size_t r = 0; r < n; r++) {
            if (r == col) continue;
            uint8_t factor = aug[r * width + col];
            if (factor == 0) continue;
            for (size_t k = 0; k < width; k++) {
                aug[r * width + k] ^= ttzip_rs_gf_mul(aug[col * width + k], factor);
            }
        }
    }

    for (size_t i = 0; i < n; i++) {
        for (size_t j = 0; j < n; j++) {
            out_matrix[i * n + j] = aug[i * width + n + j];
        }
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
    if (ttzip_rs_create_cauchy_matrix(m_parity, k_data, matrix) != 0) {
        free(matrix);
        return -1;
    }

    for (size_t p = 0; p < m_parity; p++) {
        uint8_t* dst = parity_ptrs[p];
        if (!dst) continue;
        memset(dst, 0, block_size);
        for (size_t d = 0; d < k_data; d++) {
            const uint8_t* src = data_ptrs[d];
            if (!src) continue;
            uint8_t coeff = matrix[p * k_data + d];
            if (coeff == 0) continue;
            for (size_t b = 0; b < block_size; b++) {
                dst[b] ^= ttzip_rs_gf_mul(src[b], coeff);
            }
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
            for (size_t c = 0; c < k_data; c++) {
                submatrix[r * k_data + c] = (c == (size_t)idx) ? 1 : 0;
            }
        } else {
            size_t parity_row = (size_t)(idx - (int32_t)k_data);
            for (size_t c = 0; c < k_data; c++) {
                submatrix[r * k_data + c] = cauchy[parity_row * k_data + c];
            }
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
            if (!src) continue;
            uint8_t coeff = inv_matrix[(size_t)missing_idx * k_data + a];
            if (coeff == 0) continue;
            for (size_t b = 0; b < block_size; b++) {
                dst[b] ^= ttzip_rs_gf_mul(src[b], coeff);
            }
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

    if (!zout || zoutsize == 0) {
        if (zout) free(zout);
        return 0;
    }

    if (zoutsize > out_capacity) {
        free(zout);
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
            if (crc & 1) {
                crc = (crc >> 1) ^ poly;
            } else {
                crc >>= 1;
            }
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
        uint8_t table_index = (uint8_t)(crc ^ buf[i]);
        crc = s_crc64_table[table_index] ^ (crc >> 8);
    }
    return ~crc;
}

// MARK: - 6. Magic Number Sniffer
ttzip_magic_info_t ttzip_magic_sniff_buffer(const void *buf, size_t len) {
    ttzip_magic_info_t res;
    memset(&res, 0, sizeof(res));
    res.kind = TTZIP_KIND_UNKNOWN;
    res.format_name = "BINARY";
    res.mime_type = "application/octet-stream";
    res.is_archive = false;

    if (!buf || len < 4) return res;
    const uint8_t *b = (const uint8_t *)buf;

    if (len >= 4 && b[0] == 'P' && b[1] == 'K' && b[2] == 0x03 && b[3] == 0x04) {
        res.kind = TTZIP_KIND_ARCHIVE;
        res.format_name = "ZIP";
        res.mime_type = "application/zip";
        res.is_archive = true;
        return res;
    }
    if (len >= 6 && b[0] == '7' && b[1] == 'z' && b[2] == 0xBC && b[3] == 0xAF && b[4] == 0x27 && b[5] == 0x1C) {
        res.kind = TTZIP_KIND_ARCHIVE;
        res.format_name = "7Z";
        res.mime_type = "application/x-7z-compressed";
        res.is_archive = true;
        return res;
    }
    if (len >= 2 && b[0] == 0x1F && b[1] == 0x8B) {
        res.kind = TTZIP_KIND_ARCHIVE;
        res.format_name = "GZIP";
        res.mime_type = "application/gzip";
        res.is_archive = true;
        return res;
    }
    if (len >= 6 && b[0] == 0xFD && b[1] == '7' && b[2] == 'z' && b[3] == 'X' && b[4] == 'Z' && b[5] == 0x00) {
        res.kind = TTZIP_KIND_ARCHIVE;
        res.format_name = "XZ";
        res.mime_type = "application/x-xz";
        res.is_archive = true;
        return res;
    }
    if (len >= 4 && b[0] == 0x28 && b[1] == 0xB5 && b[2] == 0x2F && b[3] == 0xFD) {
        res.kind = TTZIP_KIND_ARCHIVE;
        res.format_name = "ZSTD";
        res.mime_type = "application/zstd";
        res.is_archive = true;
        return res;
    }
    if (len >= 3 && b[0] == 'B' && b[1] == 'Z' && b[2] == 'h') {
        res.kind = TTZIP_KIND_ARCHIVE;
        res.format_name = "BZIP2";
        res.mime_type = "application/x-bzip2";
        res.is_archive = true;
        return res;
    }
    if (len >= 7 && b[0] == 'R' && b[1] == 'a' && b[2] == 'r' && b[3] == '!' && b[4] == 0x1A && b[5] == 0x07) {
        res.kind = TTZIP_KIND_ARCHIVE;
        res.format_name = "RAR";
        res.mime_type = "application/x-rar-compressed";
        res.is_archive = true;
        return res;
    }
    return res;
}

// MARK: - 7. Libarchive Wrappers
int ttzip_extract_tar_native_c(const char* tar_path, const char* dest_dir, bool skip_mac_junk) {
    if (!tar_path || !dest_dir) return -1;
    return ttzip_extract_archive_advanced(tar_path, dest_dir, skip_mac_junk, NULL);
}

int ttzip_create_tar_native_c(
    const char* out_path,
    const char* format_name,
    const char* const* input_paths,
    size_t num_inputs,
    bool skip_mac_junk,
    int level
) {
    if (!out_path || !input_paths || num_inputs == 0) return -1;
    TTZipCreateOptions opt;
    memset(&opt, 0, sizeof(opt));
    opt.format = TTZIP_ARCHIVE_FORMAT_TAR;
    opt.level = TTZIP_COMPRESSION_LEVEL_STORE;
    opt.encryption = TTZIP_ENCRYPTION_NONE;
    return (int)ttzip_rust_create_archive(input_paths, num_inputs, out_path, &opt);
}

int ttzip_extract_archive_advanced(
    const char* archive_path,
    const char* destination_dir,
    bool skip_mac_junk,
    const char* password
) {
    if (!archive_path || !destination_dir) return -1;
    
    TTZipExtractOptions opt;
    memset(&opt, 0, sizeof(opt));
    opt.destination_path = destination_dir;
    opt.password = password;
    opt.thread_budget = 0;
    opt.overwrite_existing = true;
    opt.preserve_permissions = true;
    
    TTZipStatus status = ttzip_rust_extract_archive(archive_path, destination_dir, &opt);
    if (status == TTZIP_STATUS_OK) return 0;
    
    // Libarchive fallback
    struct archive* a = archive_read_new();
    if (!a) return -1;
    struct archive* ext = archive_write_disk_new();
    if (!ext) { archive_read_free(a); return -1; }

    archive_read_support_format_all(a);
    archive_read_support_filter_all(a);
    archive_write_disk_set_options(ext, ARCHIVE_EXTRACT_TIME | ARCHIVE_EXTRACT_PERM | ARCHIVE_EXTRACT_SECURE_NODOTDOT | ARCHIVE_EXTRACT_UNLINK);

    if (password && password[0] != '\0') {
        archive_read_add_passphrase(a, password);
    }

    if (archive_read_open_filename(a, archive_path, 65536) != ARCHIVE_OK) {
        archive_write_free(ext);
        archive_read_free(a);
        return -1;
    }

    struct archive_entry* entry;
    int r;
    int extracted_count = 0;
    while ((r = archive_read_next_header(a, &entry)) == ARCHIVE_OK) {
        const char* pathname = archive_entry_pathname(entry);
        if (!pathname || pathname[0] == '\0') continue;
        if (skip_mac_junk) {
            const char* base = strrchr(pathname, '/');
            const char* name = base ? (base + 1) : pathname;
            if (strncmp(name, "._", 2) == 0 || strcmp(name, ".DS_Store") == 0 || strstr(pathname, "__MACOSX") != NULL) {
                archive_read_data_skip(a);
                continue;
            }
        }
        char full_dest[4096];
        snprintf(full_dest, sizeof(full_dest), "%s/%s", destination_dir, pathname);
        archive_entry_set_pathname(entry, full_dest);
        if (archive_write_header(ext, entry) == ARCHIVE_OK) {
            const void* buff;
            size_t size;
            la_int64_t offset;
            int data_ok = 1;
            while ((r = archive_read_data_block(a, &buff, &size, &offset)) == ARCHIVE_OK) {
                if (archive_write_data_block(ext, buff, size, offset) != ARCHIVE_OK) {
                    data_ok = 0;
                    break;
                }
            }
            if (r != ARCHIVE_EOF && r != ARCHIVE_OK) {
                data_ok = 0;
            }
            archive_write_finish_entry(ext);
            if (data_ok) {
                extracted_count++;
            } else {
                unlink(full_dest);
            }
        }
    }

    archive_read_close(a);
    archive_read_free(a);
    archive_write_close(ext);
    archive_write_free(ext);
    return (extracted_count > 0) ? 0 : -1;
}
