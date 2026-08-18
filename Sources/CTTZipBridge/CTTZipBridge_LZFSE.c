// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/CTTZipBridge_LZFSE.h"
#include "include/CTTZipCommon.h"
#include "include/CTTZipBridge_APFS.h"
#include "lzfse.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <pthread.h>
#include <sys/mman.h>
#include <sys/stat.h>

// MARK: - Thread-Local Scratch Arena Management

static pthread_key_t s_decode_scratch_key;
static pthread_key_t s_encode_scratch_key;
static pthread_once_t s_key_once = PTHREAD_ONCE_INIT;

static void free_thread_scratch(void* ptr) {
    if (ptr) {
        free(ptr);
    }
}

static void init_scratch_keys(void) {
    pthread_key_create(&s_decode_scratch_key, free_thread_scratch);
    pthread_key_create(&s_encode_scratch_key, free_thread_scratch);
}

static void* get_thread_decode_scratch(void) {
    pthread_once(&s_key_once, init_scratch_keys);
    void* scratch = pthread_getspecific(s_decode_scratch_key);
    if (!scratch) {
        size_t size = lzfse_decode_scratch_size();
        if (size == 0) size = 2129920; // fallback to 2.03MB
        scratch = malloc(size);
        if (scratch) {
            pthread_setspecific(s_decode_scratch_key, scratch);
        }
    }
    return scratch;
}

static void* get_thread_encode_scratch(void) {
    pthread_once(&s_key_once, init_scratch_keys);
    void* scratch = pthread_getspecific(s_encode_scratch_key);
    if (!scratch) {
        size_t size = lzfse_encode_scratch_size();
        if (size == 0) size = 2129920; // fallback to 2.03MB
        scratch = malloc(size);
        if (scratch) {
            pthread_setspecific(s_encode_scratch_key, scratch);
        }
    }
    return scratch;
}

// MARK: - Public Core APIs

bool ttzip_lzfse_is_available(void) {
    return true; // 100% In-Process C Static Compilation
}

size_t ttzip_lzfse_compress(const void* src, size_t src_size, void* dst, size_t dst_capacity) {
    if (!src || !dst || src_size == 0 || dst_capacity == 0) return 0;
    
    void* scratch = get_thread_encode_scratch();
    return lzfse_encode_buffer((uint8_t*)dst, dst_capacity, (const uint8_t*)src, src_size, scratch);
}

size_t ttzip_lzfse_decompress(const void* src, size_t src_size, void* dst, size_t dst_capacity) {
    if (!src || !dst || src_size == 0 || dst_capacity == 0) return 0;
    
    void* scratch = get_thread_decode_scratch();
    return lzfse_decode_buffer((uint8_t*)dst, dst_capacity, (const uint8_t*)src, src_size, scratch);
}

size_t ttzip_lzfse_decompress_block(const void* src, size_t src_size, void* dst, size_t dst_capacity) {
    return ttzip_lzfse_decompress(src, src_size, dst, dst_capacity);
}

// MARK: - File Streaming Workflows

int ttzip_lzfse_compress_file_stream(const char* src_path, const char* dst_path) {
    if (!src_path || !dst_path) return TTZIP_ERR_INVALID_PARAM;
    
    int fd_in = open(src_path, O_RDONLY);
    if (fd_in < 0) return TTZIP_ERR_FILE_NOT_FOUND;
    
    struct stat st;
    if (fstat(fd_in, &st) != 0 || st.st_size == 0) {
        close(fd_in);
        return TTZIP_ERR_FILE_NOT_FOUND;
    }
    
    void *mapped = mmap(NULL, (size_t)st.st_size, PROT_READ, MAP_SHARED, fd_in, 0);
    close(fd_in);
    if (mapped == MAP_FAILED) return TTZIP_ERR_MMAP_FAILED;
    
    size_t out_cap = (size_t)st.st_size + 65536;
    uint8_t *out_buf = (uint8_t*)malloc(out_cap);
    if (!out_buf) {
        munmap(mapped, (size_t)st.st_size);
        return TTZIP_ERR_MMAP_FAILED;
    }
    
    void* scratch = get_thread_encode_scratch();
    size_t comp_size = lzfse_encode_buffer(out_buf, out_cap, (const uint8_t*)mapped, (size_t)st.st_size, scratch);
    munmap(mapped, (size_t)st.st_size);
    
    if (comp_size == 0) {
        free(out_buf);
        return TTZIP_ERR_CORRUPT_HEADER;
    }
    
    int fd_out = open(dst_path, O_CREAT | O_WRONLY | O_TRUNC, 0644);
    if (fd_out < 0) {
        free(out_buf);
        return TTZIP_ERR_OPEN_FAILED;
    }
    
    ttzip_apfs_preallocate(fd_out, (int64_t)comp_size);
    ssize_t written = write(fd_out, out_buf, comp_size);
    close(fd_out);
    free(out_buf);
    
    return (written == (ssize_t)comp_size) ? TTZIP_OK : TTZIP_ERR_OPEN_FAILED;
}

int ttzip_lzfse_decompress_file_stream(const char* src_path, const char* dst_path) {
    if (!src_path || !dst_path) return TTZIP_ERR_INVALID_PARAM;
    
    int fd_in = open(src_path, O_RDONLY);
    if (fd_in < 0) return TTZIP_ERR_FILE_NOT_FOUND;
    
    struct stat st;
    if (fstat(fd_in, &st) != 0 || st.st_size == 0) {
        close(fd_in);
        return TTZIP_ERR_FILE_NOT_FOUND;
    }
    
    void *mapped = mmap(NULL, (size_t)st.st_size, PROT_READ, MAP_SHARED, fd_in, 0);
    close(fd_in);
    if (mapped == MAP_FAILED) return TTZIP_ERR_MMAP_FAILED;
    
    void* scratch = get_thread_decode_scratch();
    
    size_t out_cap = (size_t)st.st_size * 4;
    if (out_cap < 256 * 1024) out_cap = 256 * 1024; // at least 256KB
    uint8_t *out_buf = (uint8_t*)malloc(out_cap);
    if (!out_buf) {
        munmap(mapped, (size_t)st.st_size);
        return TTZIP_ERR_MMAP_FAILED;
    }
    
    size_t decomp_size = 0;
    while (out_cap <= 1024 * 1024 * 1024) { // max 1GB
        decomp_size = lzfse_decode_buffer(out_buf, out_cap, (const uint8_t*)mapped, (size_t)st.st_size, scratch);
        if (decomp_size > 0 && decomp_size < out_cap) {
            break; // Successfully decoded complete stream!
        }
        size_t next_cap = out_cap * 2;
        if (next_cap > 1024 * 1024 * 1024) break;
        uint8_t *new_buf = (uint8_t*)realloc(out_buf, next_cap);
        if (!new_buf) break;
        out_buf = new_buf;
        out_cap = next_cap;
    }
    
    munmap(mapped, (size_t)st.st_size);
    
    if (decomp_size == 0) {
        free(out_buf);
        return TTZIP_ERR_CORRUPT_HEADER;
    }
    
    int fd_out = open(dst_path, O_CREAT | O_WRONLY | O_TRUNC, 0644);
    if (fd_out < 0) {
        free(out_buf);
        return TTZIP_ERR_OPEN_FAILED;
    }
    
    ttzip_apfs_preallocate(fd_out, (int64_t)decomp_size);
    ssize_t written = write(fd_out, out_buf, decomp_size);
    close(fd_out);
    free(out_buf);
    
    return (written == (ssize_t)decomp_size) ? TTZIP_OK : TTZIP_ERR_OPEN_FAILED;
}
