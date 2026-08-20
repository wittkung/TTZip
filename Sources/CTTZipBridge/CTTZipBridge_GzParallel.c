// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine.

#include "include/CTTZipGzParallel.h"
#include "include/CTTZipBridge.h"
#include "include/CTTZipCommon.h"
#include "include/ttzip_threadpool.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <pthread.h>
#include <libdeflate.h>
#include <bzlib.h>
#include "lz4.h"
#include "lz4frame.h"
#include "lzma.h"

#if defined(TTZIP_OS_WINDOWS)
#include <io.h>
#else
#include <unistd.h>
#endif

#define GZ_CHUNK_SIZE (1024 * 1024)
#define GZ_MAX_IN_FLIGHT 128

enum parallel_codec_type {
    PARALLEL_CODEC_GZ = 0,
    PARALLEL_CODEC_BZ2 = 1,
    PARALLEL_CODEC_LZ4 = 2,
    PARALLEL_CODEC_XZ = 3
};

typedef struct {
    uint8_t *compressed_data;
    size_t compressed_size;
    bool is_ready;
} gz_chunk_result_t;

struct parallel_gz_ctx {
    int fd;
    int level;
    int codec_type;
    
    uint8_t *current_buffer;
    size_t current_len;
    
    uint64_t next_seq_to_submit;
    uint64_t next_seq_to_write;
    
    gz_chunk_result_t results[GZ_MAX_IN_FLIGHT];
    
    pthread_mutex_t mutex;
    pthread_cond_t cond;
    bool has_error;
};

parallel_gz_ctx* init_parallel_gz(const char* path, int level) {
    parallel_gz_ctx *ctx = (parallel_gz_ctx*)calloc(1, sizeof(parallel_gz_ctx));
    if (!ctx) return NULL;
    if (strcmp(path, "-") == 0) {
        ctx->fd = STDOUT_FILENO;
    } else {
        ctx->fd = open(path, O_CREAT | O_TRUNC | O_WRONLY, 0644);
        if (ctx->fd < 0) {
            free(ctx);
            return NULL;
        }
    }
    ctx->level = level;
    ctx->codec_type = PARALLEL_CODEC_GZ;
    ctx->current_buffer = (uint8_t*)malloc(GZ_CHUNK_SIZE);
    if (!ctx->current_buffer) {
        if (ctx->fd != STDOUT_FILENO) close(ctx->fd);
        free(ctx);
        return NULL;
    }
    pthread_mutex_init(&ctx->mutex, NULL);
    pthread_cond_init(&ctx->cond, NULL);
    return ctx;
}

parallel_gz_ctx* init_parallel_bz2(const char* path, int level) {
    parallel_gz_ctx *ctx = init_parallel_gz(path, level);
    if (ctx) {
        ctx->codec_type = PARALLEL_CODEC_BZ2;
    }
    return ctx;
}

parallel_gz_ctx* init_parallel_lz4(const char* path, int level) {
    parallel_gz_ctx *ctx = init_parallel_gz(path, level);
    if (ctx) {
        ctx->codec_type = PARALLEL_CODEC_LZ4;
    }
    return ctx;
}

parallel_gz_ctx* init_parallel_xz(const char* path, int level) {
    parallel_gz_ctx *ctx = init_parallel_gz(path, level);
    if (ctx) {
        ctx->codec_type = PARALLEL_CODEC_XZ;
    }
    return ctx;
}

typedef struct {
    parallel_gz_ctx* ctx;
    uint64_t         seq;
    uint8_t*         uncompressed_data;
    size_t           uncompressed_len;
} gz_worker_task_t;

static void compress_chunk_worker_routine(void* arg) {
    gz_worker_task_t* task = (gz_worker_task_t*)arg;
    if (!task) return;
    
    parallel_gz_ctx *ctx = task->ctx;
    uint64_t seq = task->seq;
    uint8_t *uncompressed_data = task->uncompressed_data;
    size_t uncompressed_len = task->uncompressed_len;
    free(task);

    uint8_t *out_buf = NULL;
    size_t final_size = 0;
    int z_level = ctx->level > 0 ? (ctx->level > 12 ? 12 : ctx->level) : 6;

    if (ctx->codec_type == PARALLEL_CODEC_GZ) {
        struct libdeflate_compressor *comp = libdeflate_alloc_compressor(z_level);
        if (comp) {
            size_t max_out = libdeflate_gzip_compress_bound(comp, uncompressed_len);
            out_buf = (uint8_t*)malloc(max_out > 0 ? max_out : 64);
            if (out_buf) {
                final_size = libdeflate_gzip_compress(comp, uncompressed_data, uncompressed_len, out_buf, max_out);
            }
            libdeflate_free_compressor(comp);
        }
    } else if (ctx->codec_type == PARALLEL_CODEC_BZ2) {
        unsigned int max_out = (unsigned int)(uncompressed_len + (uncompressed_len / 100) + 600);
        out_buf = (uint8_t*)malloc(max_out);
        if (out_buf) {
            int bz_level = z_level < 1 ? 1 : (z_level > 9 ? 9 : z_level);
            int ret = BZ2_bzBuffToBuffCompress((char*)out_buf, &max_out, (char*)uncompressed_data, (unsigned int)uncompressed_len, bz_level, 0, 30);
            if (ret == BZ_OK) {
                final_size = max_out;
            }
        }
    } else if (ctx->codec_type == PARALLEL_CODEC_LZ4) {
        LZ4F_preferences_t prefs;
        memset(&prefs, 0, sizeof(prefs));
        prefs.compressionLevel = z_level;
        prefs.frameInfo.blockSizeID = LZ4F_max1MB;
        prefs.frameInfo.blockMode = LZ4F_blockIndependent;
        
        size_t max_out = LZ4F_compressFrameBound(uncompressed_len, &prefs);
        out_buf = (uint8_t*)malloc(max_out > 0 ? max_out : 64);
        if (out_buf) {
            final_size = LZ4F_compressFrame(out_buf, max_out, uncompressed_data, uncompressed_len, &prefs);
        }
    } else if (ctx->codec_type == PARALLEL_CODEC_XZ) {
        size_t max_out = lzma_stream_buffer_bound(uncompressed_len);
        out_buf = (uint8_t*)malloc(max_out > 0 ? max_out : 64);
        if (out_buf) {
            uint32_t preset = (uint32_t)(z_level < 0 ? 0 : (z_level > 9 ? 9 : z_level));
            size_t out_pos = 0;
            lzma_ret ret = lzma_easy_buffer_encode(preset, LZMA_CHECK_CRC32, NULL, uncompressed_data, uncompressed_len, out_buf, &out_pos, max_out);
            if (ret == LZMA_OK) {
                final_size = out_pos;
            }
        }
    }
    
    if (!out_buf || final_size == 0) {
        free(uncompressed_data);
        if (out_buf) free(out_buf);
        
        pthread_mutex_lock(&ctx->mutex);
        ctx->has_error = true;
        int slot = (int)(seq % GZ_MAX_IN_FLIGHT);
        ctx->results[slot].compressed_data = NULL;
        ctx->results[slot].compressed_size = 0;
        ctx->results[slot].is_ready = true;
        
        while (1) {
            int w_slot = (int)(ctx->next_seq_to_write % GZ_MAX_IN_FLIGHT);
            if (ctx->next_seq_to_write < ctx->next_seq_to_submit && ctx->results[w_slot].is_ready) {
                if (ctx->results[w_slot].compressed_data && ctx->results[w_slot].compressed_size > 0) {
#if defined(TTZIP_OS_WINDOWS)
                    _write(ctx->fd, ctx->results[w_slot].compressed_data, (unsigned int)ctx->results[w_slot].compressed_size);
#else
                    write(ctx->fd, ctx->results[w_slot].compressed_data, ctx->results[w_slot].compressed_size);
#endif
                    free(ctx->results[w_slot].compressed_data);
                    ctx->results[w_slot].compressed_data = NULL;
                }
                ctx->results[w_slot].is_ready = false;
                ctx->next_seq_to_write++;
                pthread_cond_broadcast(&ctx->cond);
            } else {
                break;
            }
        }
        pthread_mutex_unlock(&ctx->mutex);
        return;
    }
    
    free(uncompressed_data);
    
    pthread_mutex_lock(&ctx->mutex);
    int slot = (int)(seq % GZ_MAX_IN_FLIGHT);
    ctx->results[slot].compressed_data = out_buf;
    ctx->results[slot].compressed_size = final_size;
    ctx->results[slot].is_ready = true;
    
    while (1) {
        int w_slot = (int)(ctx->next_seq_to_write % GZ_MAX_IN_FLIGHT);
        if (ctx->next_seq_to_write < ctx->next_seq_to_submit && ctx->results[w_slot].is_ready) {
            if (ctx->results[w_slot].compressed_data && ctx->results[w_slot].compressed_size > 0) {
#if defined(TTZIP_OS_WINDOWS)
                _write(ctx->fd, ctx->results[w_slot].compressed_data, (unsigned int)ctx->results[w_slot].compressed_size);
#else
                write(ctx->fd, ctx->results[w_slot].compressed_data, ctx->results[w_slot].compressed_size);
#endif
                free(ctx->results[w_slot].compressed_data);
                ctx->results[w_slot].compressed_data = NULL;
            }
            ctx->results[w_slot].is_ready = false;
            ctx->next_seq_to_write++;
            pthread_cond_broadcast(&ctx->cond);
        } else {
            break;
        }
    }
    pthread_mutex_unlock(&ctx->mutex);
}

static void compress_chunk_async(parallel_gz_ctx *ctx, uint64_t seq, uint8_t *uncompressed_data, size_t uncompressed_len) {
    gz_worker_task_t* task = (gz_worker_task_t*)malloc(sizeof(gz_worker_task_t));
    if (!task) {
        free(uncompressed_data);
        return;
    }
    task->ctx = ctx;
    task->seq = seq;
    task->uncompressed_data = uncompressed_data;
    task->uncompressed_len = uncompressed_len;
    
    if (ttzip_threadpool_submit(ttzip_threadpool_shared(), compress_chunk_worker_routine, task) != 0) {
        compress_chunk_worker_routine(task);
    }
}

static void flush_current_buffer(parallel_gz_ctx *ctx) {
    if (ctx->current_len == 0) return;
    
    pthread_mutex_lock(&ctx->mutex);
    while (ctx->next_seq_to_submit - ctx->next_seq_to_write >= GZ_MAX_IN_FLIGHT) {
        pthread_cond_wait(&ctx->cond, &ctx->mutex);
    }
    uint64_t seq = ctx->next_seq_to_submit++;
    pthread_mutex_unlock(&ctx->mutex);
    
    uint8_t *data_copy = (uint8_t*)malloc(ctx->current_len);
    if (!data_copy) return;
    memcpy(data_copy, ctx->current_buffer, ctx->current_len);
    
    compress_chunk_async(ctx, seq, data_copy, ctx->current_len);
    ctx->current_len = 0;
}

static void parallel_gz_write(parallel_gz_ctx *ctx, const void *buff, size_t length) {
    const uint8_t *ptr = (const uint8_t*)buff;
    while (length > 0) {
        size_t space = GZ_CHUNK_SIZE - ctx->current_len;
        size_t to_copy = length < space ? length : space;
        memcpy(ctx->current_buffer + ctx->current_len, ptr, to_copy);
        ctx->current_len += to_copy;
        ptr += to_copy;
        length -= to_copy;
        
        if (ctx->current_len == GZ_CHUNK_SIZE) {
            flush_current_buffer(ctx);
        }
    }
}

static void finish_parallel_gz(parallel_gz_ctx *ctx) {
    if (!ctx) return;
    flush_current_buffer(ctx);
    
    pthread_mutex_lock(&ctx->mutex);
    while (ctx->next_seq_to_write < ctx->next_seq_to_submit) {
        pthread_cond_wait(&ctx->cond, &ctx->mutex);
    }
    pthread_mutex_unlock(&ctx->mutex);
    
    if (ctx->fd >= 0 && ctx->fd != STDOUT_FILENO) {
        close(ctx->fd);
    }
    free(ctx->current_buffer);
    pthread_mutex_destroy(&ctx->mutex);
    pthread_cond_destroy(&ctx->cond);
    free(ctx);
}

ssize_t ttzip_archive_gz_write_cb(void *a, void *client_data, const void *buffer, size_t length) {
    (void)a;
    parallel_gz_ctx *ctx = (parallel_gz_ctx*)client_data;
    parallel_gz_write(ctx, buffer, length);
    return (ssize_t)length;
}

int ttzip_archive_gz_close_cb(void *a, void *client_data) {
    (void)a;
    parallel_gz_ctx *ctx = (parallel_gz_ctx*)client_data;
    finish_parallel_gz(ctx);
    return 0;
}
