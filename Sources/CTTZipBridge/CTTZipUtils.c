// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/CTTZipUtils.h"
#include "include/CTTZipSysAlloc.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>
#include <math.h>
#if defined(__aarch64__) || defined(__arm64__)
#include <arm_neon.h>
#if defined(__has_include)
#if __has_include(<arm_acle.h>)
#include <arm_acle.h>
#endif
#endif
#endif
#include <zlib.h>
#if !defined(TTZIP_OS_WINDOWS)
#include <readpassphrase.h>
#endif
#include "include/ttzip_threadpool.h"
#include <libdeflate.h>

#define AURA_IO_BUFFER_SIZE (4 * 1024 * 1024)

const char* ttzip_detect_encoding_fast(const uint8_t* bytes, size_t len) {
    if (!bytes || len == 0) return "UTF-8";
    
    // Quick UTF-8 validation
    bool is_utf8 = true;
    size_t i = 0;
    while (i < len) {
        if (bytes[i] <= 0x7F) {
            i++;
        } else if ((bytes[i] & 0xE0) == 0xC0) {
            if (i + 1 >= len || (bytes[i + 1] & 0xC0) != 0x80) { is_utf8 = false; break; }
            i += 2;
        } else if ((bytes[i] & 0xF0) == 0xE0) {
            if (i + 2 >= len || (bytes[i + 1] & 0xC0) != 0x80 || (bytes[i + 2] & 0xC0) != 0x80) { is_utf8 = false; break; }
            i += 3;
        } else if ((bytes[i] & 0xF8) == 0xF0) {
            if (i + 3 >= len || (bytes[i + 1] & 0xC0) != 0x80 || (bytes[i + 2] & 0xC0) != 0x80 || (bytes[i + 3] & 0xC0) != 0x80) { is_utf8 = false; break; }
            i += 4;
        } else {
            is_utf8 = false;
            break;
        }
    }
    if (is_utf8) return "UTF-8";
    
    // Check for Shift-JIS / CP932 patterns
    size_t sjis_matches = 0;
    for (size_t j = 0; j + 1 < len; j++) {
        uint8_t b1 = bytes[j];
        uint8_t b2 = bytes[j + 1];
        if (((b1 >= 0x81 && b1 <= 0x9F) || (b1 >= 0xE0 && b1 <= 0xFC)) &&
            ((b2 >= 0x40 && b2 <= 0x7E) || (b2 >= 0x80 && b2 <= 0xFC))) {
            sjis_matches++;
            j++;
        }
    }
    
    // Check for GBK / GB2312 / CP936 patterns
    size_t gbk_matches = 0;
    for (size_t j = 0; j + 1 < len; j++) {
        uint8_t b1 = bytes[j];
        uint8_t b2 = bytes[j + 1];
        if (b1 >= 0x81 && b1 <= 0xFE && b2 >= 0x40 && b2 <= 0xFE && b2 != 0x7F) {
            gbk_matches++;
            j++;
        }
    }
    
    if (sjis_matches > gbk_matches && sjis_matches > 0) return "Shift-JIS";
    if (gbk_matches > 0) return "GBK";
    
    return "CP437";
}

char* ttzip_detect_charset(const char* bytes, size_t length) {
    if (!bytes || length == 0) return strdup("UTF-8");
    const char* detected = ttzip_detect_encoding_fast((const uint8_t*)bytes, length);
    return strdup(detected);
}

uint32_t ttzip_compute_buffer_crc32(const void* buf, size_t len) {
    if (!buf || len == 0) return 0;
    return libdeflate_crc32(0, buf, len);
}

uint32_t ttzip_compute_buffer_crc32_neon(uint32_t initial_crc, const void* buf, size_t len) {
    if (!buf || len == 0) return initial_crc;
    return libdeflate_crc32(initial_crc, buf, len);
}

typedef struct {
    const uint8_t* byte_ptr;
    size_t chunk_size;
    size_t len;
    uint32_t* p_crcs;
    size_t* p_lens;
} crc_chunk_arg_t;

static void crc_chunk_worker(size_t i, void* arg) {
    crc_chunk_arg_t* ctx = (crc_chunk_arg_t*)arg;
    size_t offset = i * ctx->chunk_size;
    if (offset < ctx->len) {
        size_t this_len = (offset + ctx->chunk_size <= ctx->len) ? ctx->chunk_size : (ctx->len - offset);
        ctx->p_crcs[i] = libdeflate_crc32(0, ctx->byte_ptr + offset, this_len);
        ctx->p_lens[i] = this_len;
    }
}

uint32_t ttzip_compute_buffer_crc32_parallel(const void* buf, size_t len) {
    if (!buf || len == 0) return 0;
    if (len < 4 * 1024 * 1024) {
        return libdeflate_crc32(0, buf, len);
    }
    const size_t num_chunks = 8;
    const size_t chunk_size = (len + num_chunks - 1) / num_chunks;
    uint32_t chunk_crcs[8] = {0};
    size_t chunk_lens[8] = {0};

    crc_chunk_arg_t arg = {
        .byte_ptr = (const uint8_t*)buf,
        .chunk_size = chunk_size,
        .len = len,
        .p_crcs = chunk_crcs,
        .p_lens = chunk_lens
    };

    ttzip_parallel_for(ttzip_threadpool_shared(), num_chunks, crc_chunk_worker, &arg);

    uint32_t combined = chunk_crcs[0];
    for (size_t i = 1; i < num_chunks; i++) {
        if (chunk_lens[i] > 0) {
            combined = crc32_combine(combined, chunk_crcs[i], (off_t)chunk_lens[i]);
        }
    }
    return combined;
}

typedef struct {
    uint8_t* dst_ptr;
    const uint8_t* byte_ptr;
    size_t chunk_size;
    size_t len;
    uint32_t* p_crcs;
    size_t* p_lens;
} crc_copy_chunk_arg_t;

static void crc_copy_chunk_worker(size_t i, void* arg) {
    crc_copy_chunk_arg_t* ctx = (crc_copy_chunk_arg_t*)arg;
    size_t offset = i * ctx->chunk_size;
    if (offset < ctx->len) {
        size_t this_len = (offset + ctx->chunk_size <= ctx->len) ? ctx->chunk_size : (ctx->len - offset);
        if (ctx->dst_ptr) memcpy(ctx->dst_ptr + offset, ctx->byte_ptr + offset, this_len);
        ctx->p_crcs[i] = libdeflate_crc32(0, ctx->byte_ptr + offset, this_len);
        ctx->p_lens[i] = this_len;
    }
}

uint32_t ttzip_compute_crc32_and_memcpy_parallel(void* dst, const void* src, size_t len) {
    if (!src || len == 0) return 0;

    const uint64_t* u64 = (const uint64_t*)src;
    if (len >= 64 && u64[0] == 0 && u64[1] == 0 && u64[2] == 0 && u64[3] == 0 && u64[(len/8) - 1] == 0) {
        bool all_zero = true;
        size_t words = len / sizeof(uint64_t);
        for (size_t k = 0; k < words; k += 8) {
            if (u64[k] != 0 || (k+1 < words && u64[k+1] != 0) || (k+2 < words && u64[k+2] != 0) || (k+3 < words && u64[k+3] != 0)) {
                all_zero = false;
                break;
            }
        }
        if (all_zero) {
            if (dst) memset(dst, 0, len);
            return 0;
        }
    }

    if (len < 4 * 1024 * 1024) {
        if (dst) memcpy(dst, src, len);
        return libdeflate_crc32(0, src, len);
    }
    const size_t num_chunks = 12;
    const size_t chunk_size = (len + num_chunks - 1) / num_chunks;
    uint32_t chunk_crcs[12] = {0};
    size_t chunk_lens[12] = {0};

    crc_copy_chunk_arg_t arg = {
        .dst_ptr = (uint8_t*)dst,
        .byte_ptr = (const uint8_t*)src,
        .chunk_size = chunk_size,
        .len = len,
        .p_crcs = chunk_crcs,
        .p_lens = chunk_lens
    };

    ttzip_parallel_for(ttzip_threadpool_shared(), num_chunks, crc_copy_chunk_worker, &arg);

    uint32_t combined = chunk_crcs[0];
    for (size_t i = 1; i < num_chunks; i++) {
        if (chunk_lens[i] > 0) {
            combined = crc32_combine(combined, chunk_crcs[i], (off_t)chunk_lens[i]);
        }
    }
    return combined;
}

void ttzip_neon_memcpy_64b(void* dst, const void* src, size_t len) {
    uint8_t *d = (uint8_t*)dst;
    const uint8_t *s = (const uint8_t*)src;
    while (len >= 64) {
        uint8x16x4_t chunk = vld1q_u8_x4(s);
        vst1q_u8_x4(d, chunk);
        s += 64;
        d += 64;
        len -= 64;
    }
    if (len > 0) {
        memcpy(d, s, len);
    }
}

uint32_t ttzip_compute_file_crc32(const char* file_path) {
    if (!file_path) return 0;
    int fd = open(file_path, O_RDONLY);
    if (fd < 0) return 0;
    struct stat st;
    if (fstat(fd, &st) != 0 || st.st_size == 0) {
        close(fd);
        return 0;
    }
    size_t file_size = (size_t)st.st_size;
    if (file_size >= 128 * 1024) {
        void* mapped = mmap(NULL, file_size, PROT_READ, MAP_SHARED, fd, 0);
        if (mapped != MAP_FAILED) {
            close(fd);
            madvise(mapped, file_size, MADV_SEQUENTIAL);
            uint32_t crc = ttzip_compute_buffer_crc32_neon(0, mapped, file_size);
            munmap(mapped, file_size);
            return crc;
        }
    }
    char *buff = (char*)ttzip_core_aligned_alloc_16k(AURA_IO_BUFFER_SIZE);
    if (!buff) {
        close(fd);
        return 0;
    }
    uint32_t crc = 0;
    ssize_t bytes_read = read(fd, buff, AURA_IO_BUFFER_SIZE);
    while (bytes_read > 0) {
        crc = ttzip_compute_buffer_crc32_neon(crc, buff, (size_t)bytes_read);
        bytes_read = read(fd, buff, AURA_IO_BUFFER_SIZE);
    }
    close(fd);
    ttzip_core_aligned_free_16k(buff);
    return crc;
}

double ttzip_estimate_buffer_entropy(const void* buf, size_t len) {
    if (!buf || len == 0) return 0.0;
    const uint8_t *ptr = (const uint8_t*)buf;
    size_t counts[256] = {0};
    for (size_t i = 0; i < len; i++) {
        counts[ptr[i]]++;
    }
    double entropy = 0.0;
    double len_d = (double)len;
    for (int i = 0; i < 256; i++) {
        if (counts[i] > 0) {
            double p = (double)counts[i] / len_d;
            entropy -= p * log2(p);
        }
    }
    return entropy;
}

static void ttzip_calculate_dynamic_sampling_params(
    size_t total_size,
    int* out_num_points,
    size_t* out_chunk_size
) {
    if (total_size <= 1024 * 1024) {
        // <= 1MB: 1 point, full size (100% sampling)
        *out_num_points = 1;
        *out_chunk_size = total_size;
    } else if (total_size <= 16 * 1024 * 1024) {
        // 1MB ~ 16MB: 3 points, 32KB each (96KB)
        *out_num_points = 3;
        *out_chunk_size = 32 * 1024;
    } else if (total_size <= 128 * 1024 * 1024) {
        // 16MB ~ 128MB: 5 points, 64KB each (320KB)
        *out_num_points = 5;
        *out_chunk_size = 64 * 1024;
    } else if (total_size <= 1024 * 1024 * 1024ULL) {
        // 128MB ~ 1GB: 9 points, 128KB each (1.15MB)
        *out_num_points = 9;
        *out_chunk_size = 128 * 1024;
    } else {
        // > 1GB: 17~33 points, 256KB each (4MB ~ 8MB capped)
        size_t gb = total_size / (1024 * 1024 * 1024ULL);
        int points = 17 + (int)(gb * 2);
        if (points > 33) points = 33;
        *out_num_points = points;
        *out_chunk_size = 256 * 1024;
    }
}

double ttzip_estimate_buffer_entropy_dynamic(const void* buf, size_t len) {
    if (!buf || len == 0) return 0.0;
    int num_points = 1;
    size_t chunk_size = len;
    ttzip_calculate_dynamic_sampling_params(len, &num_points, &chunk_size);

    if (num_points <= 1 || chunk_size >= len) {
        return ttzip_estimate_buffer_entropy(buf, len);
    }

    const uint8_t *ptr = (const uint8_t*)buf;
    size_t counts[256] = {0};
    size_t total_sampled = 0;

    for (int p = 0; p < num_points; p++) {
        size_t offset = (len - chunk_size) * p / (num_points - 1);
        const uint8_t* p_ptr = ptr + offset;
        for (size_t i = 0; i < chunk_size; i++) {
            counts[p_ptr[i]]++;
        }
        total_sampled += chunk_size;
    }

    if (total_sampled == 0) return 0.0;
    double entropy = 0.0;
    double total_d = (double)total_sampled;
    for (int i = 0; i < 256; i++) {
        if (counts[i] > 0) {
            double prob = (double)counts[i] / total_d;
            entropy -= prob * log2(prob);
        }
    }
    return entropy;
}

double ttzip_estimate_file_entropy_dynamic(const char* file_path) {
    if (!file_path) return 0.0;
    int fd = open(file_path, O_RDONLY);
    if (fd < 0) return 0.0;
    struct stat st;
    if (fstat(fd, &st) != 0 || st.st_size <= 0) {
        close(fd);
        return 0.0;
    }
    size_t file_size = (size_t)st.st_size;

    int num_points = 1;
    size_t chunk_size = file_size;
    ttzip_calculate_dynamic_sampling_params(file_size, &num_points, &chunk_size);

    if (num_points <= 1 || chunk_size >= file_size) {
        uint8_t* buf = (uint8_t*)malloc(file_size);
        if (!buf) { close(fd); return 0.0; }
        ssize_t rd = read(fd, buf, file_size);
        close(fd);
        double ent = 0.0;
        if (rd > 0) ent = ttzip_estimate_buffer_entropy(buf, (size_t)rd);
        free(buf);
        return ent;
    }

    size_t counts[256] = {0};
    size_t total_sampled = 0;
    uint8_t* chunk_buf = (uint8_t*)malloc(chunk_size);
    if (!chunk_buf) { close(fd); return 0.0; }

    for (int p = 0; p < num_points; p++) {
        off_t offset = (off_t)((file_size - chunk_size) * p / (num_points - 1));
        ssize_t rd = pread(fd, chunk_buf, chunk_size, offset);
        if (rd > 0) {
            for (ssize_t i = 0; i < rd; i++) {
                counts[chunk_buf[i]]++;
            }
            total_sampled += (size_t)rd;
        }
    }
    close(fd);
    free(chunk_buf);

    if (total_sampled == 0) return 0.0;
    double entropy = 0.0;
    double total_d = (double)total_sampled;
    for (int i = 0; i < 256; i++) {
        if (counts[i] > 0) {
            double prob = (double)counts[i] / total_d;
            entropy -= prob * log2(prob);
        }
    }
    return entropy;
}

bool ttzip_is_ascii_fast(const void* buf, size_t len) {
    if (!buf || len == 0) return true;
    const uint8_t *ptr = (const uint8_t*)buf;
    while (len >= 16) {
        uint8x16_t data = vld1q_u8(ptr);
        uint8x16_t mask = vdupq_n_u8(0x80);
        uint8x16_t res = vandq_u8(data, mask);
        if (vmaxvq_u8(res) != 0) return false;
        ptr += 16;
        len -= 16;
    }
    while (len > 0) {
        if (*ptr++ & 0x80) return false;
        len--;
    }
    return true;
}

bool ttzip_is_buffer_binary(const void* buf, size_t len) {
    if (!buf || len == 0) return false;
    if (memchr(buf, 0, len) != NULL) return true;

    const uint8_t* bytes = (const uint8_t*)buf;
    size_t control_count = 0;
    for (size_t i = 0; i < len; i++) {
        uint8_t c = bytes[i];
        if (c < 0x09 || (c >= 0x0B && c <= 0x0C) || (c >= 0x0E && c <= 0x1F) || c == 0x7F) {
            control_count++;
        }
    }
    return (control_count * 100 > len * 2);
}

int ttzip_read_passphrase(const char* prompt, char* out_buf, size_t max_len) {
    if (!out_buf || max_len == 0) return -1;
    char* res = readpassphrase(prompt ? prompt : "Password: ", out_buf, max_len, RPP_ECHO_OFF | RPP_REQUIRE_TTY);
    if (!res) {
        return -1;
    }
    return 0;
}

bool ttzip_path_strip_components(const char* path, int strip_count, char* out_buf, size_t out_len) {
    if (!out_buf || out_len == 0) return false;
    out_buf[0] = '\0';
    if (!path || path[0] == '\0') return false;

    if (strip_count <= 0) {
        snprintf(out_buf, out_len, "%s", path);
        return out_buf[0] != '\0';
    }

    const char* p = path;
    for (int i = 0; i < strip_count; i++) {
        while (*p == '/') {
            p++;
        }
        if (*p == '\0') {
            return false;
        }
        while (*p != '/' && *p != '\0') {
            p++;
        }
        if (*p == '\0') {
            return false;
        }
        while (*p == '/') {
            p++;
        }
        if (*p == '\0') {
            return false;
        }
    }

    if (*p == '\0') {
        return false;
    }

    snprintf(out_buf, out_len, "%s", p);
    return out_buf[0] != '\0';
}

size_t ttzip_cache_get_optimal_block_size(void) {
#if defined(__APPLE__) && (defined(__ARM_NEON) || defined(__aarch64__))
    // Apple Silicon M1/M2/M3/M4: 128KB L1 Data Cache per Performance Core
    return 128 * 1024;
#else
    // Generic x86-64 / other: 64KB L1/L2 boundary
    return 64 * 1024;
#endif
}

