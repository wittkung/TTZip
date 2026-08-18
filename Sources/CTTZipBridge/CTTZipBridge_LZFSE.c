// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/CTTZipBridge_LZFSE.h"
#include "include/CTTZipCommon.h"
#include "include/CTTZipBridge_APFS.h"
#include <lzfse.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <dlfcn.h>
#include <sys/mman.h>
#include <sys/stat.h>

typedef size_t (*lzfse_encode_fn)(uint8_t *dst_buffer, size_t dst_size,
                                   const uint8_t *src_buffer, size_t src_size,
                                   void *scratch_buffer);
typedef size_t (*lzfse_decode_fn)(uint8_t *dst_buffer, size_t dst_size,
                                   const uint8_t *src_buffer, size_t src_size,
                                   void *scratch_buffer);

static void* s_lzfse_handle = NULL;
static lzfse_encode_fn s_encode_fn = NULL;
static lzfse_decode_fn s_decode_fn = NULL;

static bool init_lzfse_symbols(void) {
    if (s_encode_fn && s_decode_fn) return true;
    
    if (!s_lzfse_handle) {
        s_lzfse_handle = dlopen("liblzfse.dylib", RTLD_LAZY);
        if (!s_lzfse_handle) {
            s_lzfse_handle = dlopen("/usr/lib/liblzfse.dylib", RTLD_LAZY);
        }
        if (!s_lzfse_handle) {
            s_lzfse_handle = dlopen("/opt/homebrew/lib/liblzfse.dylib", RTLD_LAZY);
        }
    }
    
    if (s_lzfse_handle) {
        s_encode_fn = (lzfse_encode_fn)dlsym(s_lzfse_handle, "lzfse_encode_buffer");
        s_decode_fn = (lzfse_decode_fn)dlsym(s_lzfse_handle, "lzfse_decode_buffer");
    }
    
    return (s_encode_fn != NULL && s_decode_fn != NULL);
}

bool ttzip_lzfse_is_available(void) {
    return init_lzfse_symbols();
}

size_t ttzip_lzfse_compress(const void* src, size_t src_size, void* dst, size_t dst_capacity) {
    if (!src || !dst || src_size == 0 || dst_capacity == 0) return 0;
    if (!init_lzfse_symbols()) return 0;
    
    return s_encode_fn((uint8_t*)dst, dst_capacity, (const uint8_t*)src, src_size, NULL);
}

size_t ttzip_lzfse_decompress(const void* src, size_t src_size, void* dst, size_t dst_capacity) {
    if (!src || !dst || src_size == 0 || dst_capacity == 0) return 0;
    if (!init_lzfse_symbols()) return 0;
    
    return s_decode_fn((uint8_t*)dst, dst_capacity, (const uint8_t*)src, src_size, NULL);
}

int ttzip_lzfse_compress_file_stream(const char* src_path, const char* dst_path) {
    if (!src_path || !dst_path) return TTZIP_ERR_INVALID_PARAM;
    if (!init_lzfse_symbols()) return TTZIP_ERR_ARCHIVE_INIT_FAILED;
    
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
    uint8_t *out_buf = malloc(out_cap);
    if (!out_buf) {
        munmap(mapped, (size_t)st.st_size);
        return TTZIP_ERR_MMAP_FAILED;
    }
    
    size_t comp_size = s_encode_fn(out_buf, out_cap, (const uint8_t*)mapped, (size_t)st.st_size, NULL);
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
    write(fd_out, out_buf, comp_size);
    close(fd_out);
    free(out_buf);
    
    return TTZIP_OK;
}

int ttzip_lzfse_decompress_file_stream(const char* src_path, const char* dst_path) {
    if (!src_path || !dst_path) return TTZIP_ERR_INVALID_PARAM;
    if (!init_lzfse_symbols()) return TTZIP_ERR_ARCHIVE_INIT_FAILED;
    
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
    
    size_t out_cap = (size_t)st.st_size * 8 + 65536;
    uint8_t *out_buf = malloc(out_cap);
    if (!out_buf) {
        munmap(mapped, (size_t)st.st_size);
        return TTZIP_ERR_MMAP_FAILED;
    }
    
    size_t decomp_size = s_decode_fn(out_buf, out_cap, (const uint8_t*)mapped, (size_t)st.st_size, NULL);
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
    write(fd_out, out_buf, decomp_size);
    close(fd_out);
    free(out_buf);
    
    return TTZIP_OK;
}
