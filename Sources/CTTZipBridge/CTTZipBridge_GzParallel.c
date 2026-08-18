// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/CTTZipGzParallel.h"
#include "include/CTTZipBridge.h"
#include "include/CTTZipCommon.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <pthread.h>
#include <dispatch/dispatch.h>
#include <libdeflate.h>
#include <bzlib.h>
#include "lz4.h"
#include "lz4frame.h"
#include "lzma.h"

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
    
    uint64_t next_seq_to_dispatch;
    uint64_t next_seq_to_write;
    
    gz_chunk_result_t results[GZ_MAX_IN_FLIGHT];
    
    pthread_mutex_t mutex;
    pthread_cond_t cond;
    bool has_error;
    dispatch_queue_t compress_queue;
};

parallel_gz_ctx* init_parallel_gz(const char* path, int level) {
    parallel_gz_ctx *ctx = calloc(1, sizeof(parallel_gz_ctx));
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
    ctx->current_buffer = malloc(GZ_CHUNK_SIZE);
    if (!ctx->current_buffer) {
        if (ctx->fd != STDOUT_FILENO) close(ctx->fd);
        free(ctx);
        return NULL;
    }
    pthread_mutex_init(&ctx->mutex, NULL);
    pthread_cond_init(&ctx->cond, NULL);
    ctx->compress_queue = dispatch_queue_create("com.ttzip.parallel.compress", DISPATCH_QUEUE_CONCURRENT);
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

static void compress_chunk_async(parallel_gz_ctx *ctx, uint64_t seq, uint8_t *uncompressed_data, size_t uncompressed_len) {
    dispatch_async(ctx->compress_queue, ^{
        int z_level = ctx->level;
        if (z_level < 1) z_level = 1;
        if (z_level > 9) z_level = 9;
        
        uint8_t *out_buf = NULL;
        size_t final_size = 0;
        
        if (ctx->codec_type == PARALLEL_CODEC_GZ) {
            struct libdeflate_compressor *compressor = ttzip_get_tls_compressor(z_level);
            if (!compressor) {
                free(uncompressed_data);
                return;
            }
            size_t max_out = libdeflate_gzip_compress_bound(compressor, uncompressed_len);
            out_buf = malloc(max_out);
            if (!out_buf) {
                free(uncompressed_data);
                return;
            }
            final_size = libdeflate_gzip_compress(compressor, uncompressed_data, uncompressed_len, out_buf, max_out);
        } else if (ctx->codec_type == PARALLEL_CODEC_BZ2) {
            unsigned int max_out = (unsigned int)(uncompressed_len + (uncompressed_len / 100) + 600);
            out_buf = malloc(max_out);
            if (!out_buf) {
                free(uncompressed_data);
                return;
            }
            unsigned int dest_len = max_out;
            int bz_level = z_level <= 3 ? z_level : 1;
            int bz_res = BZ2_bzBuffToBuffCompress((char*)out_buf, &dest_len, (char*)uncompressed_data, (unsigned int)uncompressed_len, bz_level, 0, 30);
            if (bz_res == BZ_OK) {
                final_size = dest_len;
            }
        } else if (ctx->codec_type == PARALLEL_CODEC_LZ4) {
            size_t max_out = LZ4F_compressFrameBound(uncompressed_len, NULL);
            out_buf = malloc(max_out > 0 ? max_out : 64);
            if (!out_buf) {
                free(uncompressed_data);
                return;
            }
            LZ4F_preferences_t prefs;
            memset(&prefs, 0, sizeof(prefs));
            prefs.compressionLevel = z_level <= 3 ? z_level : 3;
            prefs.frameInfo.blockMode = LZ4F_blockIndependent;
            prefs.frameInfo.contentChecksumFlag = LZ4F_noContentChecksum;
            final_size = LZ4F_compressFrame(out_buf, max_out, uncompressed_data, uncompressed_len, &prefs);
        } else if (ctx->codec_type == PARALLEL_CODEC_XZ) {
            size_t max_out = lzma_stream_buffer_bound(uncompressed_len);
            out_buf = malloc(max_out > 0 ? max_out : 64);
            if (!out_buf) {
                free(uncompressed_data);
                return;
            }
            uint32_t preset = (uint32_t)(z_level <= 9 ? z_level : 1);
            size_t out_pos = 0;
            lzma_ret ret = lzma_easy_buffer_encode(preset, LZMA_CHECK_CRC32, NULL, uncompressed_data, uncompressed_len, out_buf, &out_pos, max_out);
            if (ret == LZMA_OK) {
                final_size = out_pos;
            }
        }
        
        if (!out_buf || final_size == 0) {
            free(uncompressed_data);
            if (out_buf) free(out_buf);
            
            pthread_mutex_lock(&ctx->mutex);
            ctx->has_error = true;
            int slot = seq % GZ_MAX_IN_FLIGHT;
            ctx->results[slot].compressed_data = NULL;
            ctx->results[slot].compressed_size = 0;
            ctx->results[slot].is_ready = true;
            
            while (1) {
                int w_slot = ctx->next_seq_to_write % GZ_MAX_IN_FLIGHT;
                if (ctx->next_seq_to_write < ctx->next_seq_to_dispatch && ctx->results[w_slot].is_ready) {
                    if (ctx->results[w_slot].compressed_data && ctx->results[w_slot].compressed_size > 0) {
                        write(ctx->fd, ctx->results[w_slot].compressed_data, ctx->results[w_slot].compressed_size);
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
        int slot = seq % GZ_MAX_IN_FLIGHT;
        ctx->results[slot].compressed_data = out_buf;
        ctx->results[slot].compressed_size = final_size;
        ctx->results[slot].is_ready = true;
        
        while (1) {
            int w_slot = ctx->next_seq_to_write % GZ_MAX_IN_FLIGHT;
            if (ctx->next_seq_to_write < ctx->next_seq_to_dispatch && ctx->results[w_slot].is_ready) {
                if (ctx->results[w_slot].compressed_data && ctx->results[w_slot].compressed_size > 0) {
                    write(ctx->fd, ctx->results[w_slot].compressed_data, ctx->results[w_slot].compressed_size);
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
    });
}

static void dispatch_current_buffer(parallel_gz_ctx *ctx) {
    if (ctx->current_len == 0) return;
    
    pthread_mutex_lock(&ctx->mutex);
    while (ctx->next_seq_to_dispatch - ctx->next_seq_to_write >= GZ_MAX_IN_FLIGHT) {
        pthread_cond_wait(&ctx->cond, &ctx->mutex);
    }
    uint64_t seq = ctx->next_seq_to_dispatch++;
    pthread_mutex_unlock(&ctx->mutex);
    
    uint8_t *data_copy = malloc(ctx->current_len);
    memcpy(data_copy, ctx->current_buffer, ctx->current_len);
    
    compress_chunk_async(ctx, seq, data_copy, ctx->current_len);
    ctx->current_len = 0;
}

static void parallel_gz_write(parallel_gz_ctx *ctx, const void *buff, size_t length) {
    const uint8_t *ptr = buff;
    while (length > 0) {
        size_t space = GZ_CHUNK_SIZE - ctx->current_len;
        size_t to_copy = length < space ? length : space;
        memcpy(ctx->current_buffer + ctx->current_len, ptr, to_copy);
        ctx->current_len += to_copy;
        ptr += to_copy;
        length -= to_copy;
        
        if (ctx->current_len == GZ_CHUNK_SIZE) {
            dispatch_current_buffer(ctx);
        }
    }
}

static void finish_parallel_gz(parallel_gz_ctx *ctx) {
    if (!ctx) return;
    dispatch_current_buffer(ctx);
    
    pthread_mutex_lock(&ctx->mutex);
    while (ctx->next_seq_to_write < ctx->next_seq_to_dispatch) {
        pthread_cond_wait(&ctx->cond, &ctx->mutex);
    }
    pthread_mutex_unlock(&ctx->mutex);
    
    if (ctx->fd >= 0 && ctx->fd != STDOUT_FILENO) {
        close(ctx->fd);
    }
    free(ctx->current_buffer);
    dispatch_release(ctx->compress_queue);
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
