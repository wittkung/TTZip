// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/CTTZipBridge_Zstd.h"
#include "include/CTTZipBridge.h"
#include "include/CTTZipCommon.h"
#include "include/CTTZipBridge_Archive.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <zstd.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

size_t ttzip_zstd_compress(const void* src, size_t src_size, void* dst, size_t dst_capacity, int compression_level) {
    if (!src || !dst || src_size == 0 || dst_capacity == 0) return 0;
    size_t ret = ZSTD_compress(dst, dst_capacity, src, src_size, compression_level);
    if (ZSTD_isError(ret)) {
        return 0;
    }
    return ret;
}

size_t ttzip_zstd_decompress(const void* src, size_t src_size, void* dst, size_t dst_capacity) {
    if (!src || !dst || src_size == 0 || dst_capacity == 0) return 0;
    size_t ret = ZSTD_decompress(dst, dst_capacity, src, src_size);
    if (ZSTD_isError(ret)) {
        return 0;
    }
    return ret;
}

size_t ttzip_zstd_compress_advanced(
    const void* src, size_t src_size,
    void* dst, size_t dst_capacity,
    int level, int nb_workers, int job_size_mb, int overlap_log, int window_log, bool enable_ldm
) {
    if (!src || !dst || src_size == 0 || dst_capacity == 0) return 0;
    
    ZSTD_CCtx* cctx = ZSTD_createCCtx();
    if (!cctx) return 0;
    
    int cores = (int)sysconf(_SC_NPROCESSORS_ONLN);
    if (cores <= 0) cores = 8;
    int actual_workers = nb_workers > 0 ? nb_workers : cores;
    int actual_job_size = job_size_mb > 0 ? job_size_mb * 1024 * 1024 : 4 * 1024 * 1024;

    ZSTD_CCtx_setParameter(cctx, ZSTD_c_compressionLevel, level != 0 ? level : 3);
    ZSTD_CCtx_setParameter(cctx, ZSTD_c_nbWorkers, actual_workers);
    ZSTD_CCtx_setParameter(cctx, ZSTD_c_jobSize, actual_job_size);

    if (overlap_log >= 0) {
        ZSTD_CCtx_setParameter(cctx, ZSTD_c_overlapLog, overlap_log);
    }
    if (window_log > 0) {
        ZSTD_CCtx_setParameter(cctx, ZSTD_c_windowLog, window_log);
    }
    if (enable_ldm) {
        ZSTD_CCtx_setParameter(cctx, ZSTD_c_enableLongDistanceMatching, 1);
    }
    
    ZSTD_inBuffer in = { src, src_size, 0 };
    ZSTD_outBuffer out = { dst, dst_capacity, 0 };
    
    size_t const ret = ZSTD_compressStream2(cctx, &out, &in, ZSTD_e_end);
    ZSTD_freeCCtx(cctx);
    
    if (ZSTD_isError(ret)) {
        return 0;
    }
    return out.pos;
}

int ttzip_zstd_compress_file_stream(
    const char* src_path,
    const char* dst_path,
    int level, int nb_workers, int job_size_mb, int overlap_log, int window_log, bool enable_ldm,
    const char* dict_path
) {
    if (!src_path || !dst_path) return TTZIP_ERR_INVALID_PARAM;
    
    int error = TTZIP_OK;
    int fd_in = -1;
    ZSTD_CCtx* cctx = NULL;
    ZSTD_CDict* cdict = NULL;
    void* mapped_in = MAP_FAILED;
    void* dict_mapped = MAP_FAILED;
    int dict_fd = -1;
    size_t dict_size = 0;
    size_t src_size = 0;
    void* outBuf = NULL;

    fd_in = open(src_path, O_RDONLY);
    if (fd_in < 0) { error = TTZIP_ERR_FILE_NOT_FOUND; goto cleanup; }
    
    struct stat st;
    if (fstat(fd_in, &st) < 0) { error = TTZIP_ERR_FILE_NOT_FOUND; goto cleanup; }
    src_size = st.st_size;
    
    if (src_size > 0) {
        mapped_in = mmap(NULL, src_size, PROT_READ, MAP_SHARED, fd_in, 0);
        if (mapped_in == MAP_FAILED) { error = TTZIP_ERR_MMAP_FAILED; goto cleanup; }
    }
    
    char parent_dir_comp[4096];
    snprintf(parent_dir_comp, sizeof(parent_dir_comp), "%s", dst_path);
    char* last_slash_comp = strrchr(parent_dir_comp, '/');
    if (last_slash_comp && last_slash_comp > parent_dir_comp) {
        *last_slash_comp = '\0';
        ttzip_common_mkdir_p(parent_dir_comp);
    }

    int fd_out = open(dst_path, O_CREAT | O_WRONLY | O_TRUNC, 0644);
    if (fd_out < 0) { error = TTZIP_ERR_OPEN_FAILED; goto cleanup; }
    
    cctx = ZSTD_createCCtx();
    if (!cctx) { error = TTZIP_ERR_ARCHIVE_INIT_FAILED; goto cleanup; }
    
    if (dict_path && strlen(dict_path) > 0) {
        dict_fd = open(dict_path, O_RDONLY);
        if (dict_fd >= 0) {
            struct stat dst;
            if (fstat(dict_fd, &dst) == 0 && dst.st_size > 0) {
                dict_size = dst.st_size;
                dict_mapped = mmap(NULL, dict_size, PROT_READ, MAP_SHARED, dict_fd, 0);
                if (dict_mapped != MAP_FAILED) {
                    cdict = ZSTD_createCDict(dict_mapped, dict_size, level != 0 ? level : 3);
                    if (cdict) {
                        ZSTD_CCtx_refCDict(cctx, cdict);
                    }
                }
            }
        }
    }
    
    int cores = (int)sysconf(_SC_NPROCESSORS_ONLN);
    if (cores <= 0) cores = 8;
    int actual_workers = nb_workers > 0 ? nb_workers : cores;
    int actual_job_size = job_size_mb > 0 ? job_size_mb * 1024 * 1024 : 4 * 1024 * 1024;

    ZSTD_CCtx_setParameter(cctx, ZSTD_c_compressionLevel, level != 0 ? level : 3);
    ZSTD_CCtx_setParameter(cctx, ZSTD_c_nbWorkers, actual_workers);
    ZSTD_CCtx_setParameter(cctx, ZSTD_c_jobSize, actual_job_size);

    if (overlap_log >= 0) {
        ZSTD_CCtx_setParameter(cctx, ZSTD_c_overlapLog, overlap_log);
    }
    if (window_log > 0) {
        ZSTD_CCtx_setParameter(cctx, ZSTD_c_windowLog, window_log);
    }
    if (enable_ldm) {
        ZSTD_CCtx_setParameter(cctx, ZSTD_c_enableLongDistanceMatching, 1);
    }
    
    size_t const outBufSize = 128 * 1024 * 1024; // 128MB for extreme throughput
    outBuf = ttzip_aligned_alloc_16k(outBufSize);
    if (!outBuf) {
        error = TTZIP_ERR_MMAP_FAILED;
        goto cleanup;
    }
    
    ZSTD_inBuffer input = { mapped_in, src_size, 0 };
    int finished = 0;
    
    do {
        ZSTD_outBuffer output = { outBuf, outBufSize, 0 };
        size_t const remaining = ZSTD_compressStream2(cctx, &output, &input, ZSTD_e_end);
        if (ZSTD_isError(remaining)) {
            error = TTZIP_ERR_CORRUPT_HEADER;
            break;
        }
        if (output.pos > 0) {
            size_t total_written = 0;
            while (total_written < output.pos) {
                ssize_t w = write(fd_out, (char*)outBuf + total_written, output.pos - total_written);
                if (w < 0) {
                    if (errno == EINTR) continue;
                    error = TTZIP_ERR_OPEN_FAILED;
                    break;
                }
                total_written += w;
            }
            if (error != TTZIP_OK) break;
        }
        finished = (remaining == 0);
    } while (!finished);
    
cleanup:
    if (outBuf) free(outBuf);
    if (cctx) ZSTD_freeCCtx(cctx);
    if (cdict) ZSTD_freeCDict(cdict);
    if (mapped_in != MAP_FAILED) munmap(mapped_in, src_size);
    if (fd_in >= 0) close(fd_in);
    if (dict_mapped != MAP_FAILED) munmap(dict_mapped, dict_size);
    if (dict_fd >= 0) close(dict_fd);
    if (fd_out >= 0) close(fd_out);
    return error;
}

int ttzip_zstd_decompress_file_stream(
    const char* src_path,
    const char* dst_path,
    const char* dict_path
) {
    if (!src_path || !dst_path) return TTZIP_ERR_INVALID_PARAM;
    
    int error = TTZIP_OK;
    int fd_in = -1;
    int fd_out = -1;
    ZSTD_DCtx* dctx = NULL;
    ZSTD_DDict* ddict = NULL;
    void* mapped_in = MAP_FAILED;
    void* dict_mapped = MAP_FAILED;
    int dict_fd = -1;
    size_t dict_size = 0;
    size_t src_size = 0;
    void* outBuf = NULL;

    fd_in = open(src_path, O_RDONLY);
    if (fd_in < 0) { error = TTZIP_ERR_FILE_NOT_FOUND; goto cleanup; }
    
    struct stat st;
    if (fstat(fd_in, &st) < 0) { error = TTZIP_ERR_FILE_NOT_FOUND; goto cleanup; }
    src_size = st.st_size;
    
    if (src_size > 0) {
        mapped_in = mmap(NULL, src_size, PROT_READ, MAP_SHARED, fd_in, 0);
        if (mapped_in == MAP_FAILED) { error = TTZIP_ERR_MMAP_FAILED; goto cleanup; }
    }
    
    char parent_dir_decomp[4096];
    snprintf(parent_dir_decomp, sizeof(parent_dir_decomp), "%s", dst_path);
    char* last_slash_decomp = strrchr(parent_dir_decomp, '/');
    if (last_slash_decomp && last_slash_decomp > parent_dir_decomp) {
        *last_slash_decomp = '\0';
        ttzip_common_mkdir_p(parent_dir_decomp);
    }

    fd_out = open(dst_path, O_CREAT | O_WRONLY | O_TRUNC, 0644);
    if (fd_out < 0) { error = TTZIP_ERR_OPEN_FAILED; goto cleanup; }
    
    dctx = ZSTD_createDCtx();
    if (!dctx) { error = TTZIP_ERR_ARCHIVE_INIT_FAILED; goto cleanup; }
    ZSTD_DCtx_setParameter(dctx, ZSTD_d_windowLogMax, 31);
    
    if (dict_path && strlen(dict_path) > 0) {
        dict_fd = open(dict_path, O_RDONLY);
        if (dict_fd >= 0) {
            struct stat dst;
            if (fstat(dict_fd, &dst) == 0 && dst.st_size > 0) {
                dict_size = dst.st_size;
                dict_mapped = mmap(NULL, dict_size, PROT_READ, MAP_SHARED, dict_fd, 0);
                if (dict_mapped != MAP_FAILED) {
                    ddict = ZSTD_createDDict(dict_mapped, dict_size);
                    if (ddict) {
                        ZSTD_DCtx_refDDict(dctx, ddict);
                    }
                }
            }
        }
    }
    
    size_t const outBufSize = 128 * 1024 * 1024; // 128MB for extreme throughput
    outBuf = ttzip_aligned_alloc_16k(outBufSize);
    if (!outBuf) {
        error = TTZIP_ERR_MMAP_FAILED;
        goto cleanup;
    }
    
    int has_more_output = 1;
    ZSTD_inBuffer input = { mapped_in, src_size, 0 };
    while ((input.pos < input.size) || has_more_output) {
        ZSTD_outBuffer output = { outBuf, outBufSize, 0 };
        size_t const ret = ZSTD_decompressStream(dctx, &output, &input);
        if (ZSTD_isError(ret)) {
            error = TTZIP_ERR_CORRUPT_HEADER;
            break;
        }
        if (output.pos > 0) {
            size_t total_written = 0;
            while (total_written < output.pos) {
                ssize_t w = write(fd_out, (char*)outBuf + total_written, output.pos - total_written);
                if (w < 0) {
                    if (errno == EINTR) continue;
                    error = TTZIP_ERR_OPEN_FAILED;
                    break;
                }
                total_written += w;
            }
            if (error != TTZIP_OK) break;
        }
        has_more_output = (ret != 0);
    }

cleanup:
    if (outBuf) free(outBuf);
    if (dctx) ZSTD_freeDCtx(dctx);
    if (ddict) ZSTD_freeDDict(ddict);
    if (mapped_in != MAP_FAILED) munmap(mapped_in, src_size);
    if (fd_in >= 0) close(fd_in);
    if (dict_mapped != MAP_FAILED) munmap(dict_mapped, dict_size);
    if (dict_fd >= 0) close(dict_fd);
    if (fd_out >= 0) close(fd_out);
    return error;
}
