// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine.

/**
 * @file CTTZipBridge_ZipChunkedStream.c
 * @brief TTZip large file 1MB chunked multithreaded DEFLATE stream compressor.
 * @details Strictly conforms to PKWARE ZIP Method 8 and RFC 1951 byte alignment,
 *          bounding resident memory consumption within <= 64MB via a 32-slot ring buffer.
 *          Powered by cross-platform ttzip_threadpool (zero Apple GCD/Blocks dependency).
 */

#include "include/CTTZipBridge_ZipChunkedStream.h"
#include "include/CTTZipPlatform.h"
#include "include/CTTZipStreamCoder.h"
#include "include/CTTZipCommon.h"
#include "include/ttzip_threadpool.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <pthread.h>
#include <libdeflate.h>

#if defined(TTZIP_OS_WINDOWS)
#include <io.h>
#else
#include <unistd.h>
#endif

typedef struct {
    uint8_t* compressed_data;
    size_t compressed_size;
    uint32_t chunk_crc;
    bool is_ready;
    bool is_final;
} chunk_result_slot_t;

struct ttzip_zip_chunked_stream {
    int out_fd;
    int level;
    
    uint8_t* current_in_buffer;
    size_t current_in_len;
    
    uint64_t total_uncompressed_bytes;
    uint64_t total_compressed_bytes;
    uint32_t running_crc32;
    
    uint64_t next_seq_to_submit;
    uint64_t next_seq_to_write;
    
    chunk_result_slot_t slots[TTZIP_CHUNK_MAX_IN_FLIGHT];
    
    pthread_mutex_t mutex;
    pthread_cond_t cond;
    bool has_error;
};

static void flush_ready_slots_locked(ttzip_zip_chunked_stream_t* s) {
    while (s->next_seq_to_write < s->next_seq_to_submit) {
        size_t slot_idx = (size_t)(s->next_seq_to_write % TTZIP_CHUNK_MAX_IN_FLIGHT);
        if (!s->slots[slot_idx].is_ready) {
            break;
        }
        
        uint8_t* data = s->slots[slot_idx].compressed_data;
        size_t len = s->slots[slot_idx].compressed_size;
        
        if (data && len > 0 && s->out_fd >= 0) {
            size_t written = 0;
            while (written < len) {
#if defined(TTZIP_OS_WINDOWS)
                int n = _write(s->out_fd, data + written, (unsigned int)(len - written));
#else
                ssize_t n = write(s->out_fd, data + written, len - written);
#endif
                if (n <= 0) {
                    s->has_error = true;
                    break;
                }
                written += (size_t)n;
            }
            s->total_compressed_bytes += written;
        }
        
        if (data) {
            free(data);
            s->slots[slot_idx].compressed_data = NULL;
        }
        s->slots[slot_idx].compressed_size = 0;
        s->slots[slot_idx].is_ready = false;
        s->next_seq_to_write++;
        
        pthread_cond_broadcast(&s->cond);
    }
}

static void compress_chunk_worker(ttzip_zip_chunked_stream_t* s, uint64_t seq, uint8_t* uncompressed_data, size_t uncompressed_size, bool is_final) {
    struct libdeflate_compressor* compressor = libdeflate_alloc_compressor(s->level);
    if (!compressor) {
        pthread_mutex_lock(&s->mutex);
        s->has_error = true;
        pthread_cond_broadcast(&s->cond);
        pthread_mutex_unlock(&s->mutex);
        free(uncompressed_data);
        return;
    }
    
    size_t max_out = libdeflate_deflate_compress_bound(compressor, uncompressed_size);
    // Add extra padding to guarantee room for final uncompressed sync block
    max_out += 64;
    
    uint8_t* out_buf = (uint8_t*)malloc(max_out);
    if (!out_buf) {
        libdeflate_free_compressor(compressor);
        pthread_mutex_lock(&s->mutex);
        s->has_error = true;
        pthread_cond_broadcast(&s->cond);
        pthread_mutex_unlock(&s->mutex);
        free(uncompressed_data);
        return;
    }
    
    size_t actual_out = 0;
    if (uncompressed_size > 0) {
        actual_out = libdeflate_deflate_compress(compressor, uncompressed_data, uncompressed_size, out_buf, max_out);
    }
    libdeflate_free_compressor(compressor);
    
    if (uncompressed_size > 0 && actual_out == 0) {
        pthread_mutex_lock(&s->mutex);
        s->has_error = true;
        pthread_cond_broadcast(&s->cond);
        pthread_mutex_unlock(&s->mutex);
        free(out_buf);
        free(uncompressed_data);
        return;
    }
    
    // RFC 1951 Deflate sync block alignment:
    // If not final chunk, append an empty uncompressed block (BFINAL=0, BTYPE=00) to force byte alignment
    size_t final_size = actual_out;
    if (!is_final) {
        out_buf[final_size++] = 0x00;
        out_buf[final_size++] = 0x00;
        out_buf[final_size++] = 0x00;
        out_buf[final_size++] = 0xFF;
        out_buf[final_size++] = 0xFF;
    }
    
    free(uncompressed_data);
    
    pthread_mutex_lock(&s->mutex);
    size_t slot_idx = (size_t)(seq % TTZIP_CHUNK_MAX_IN_FLIGHT);
    s->slots[slot_idx].compressed_data = out_buf;
    s->slots[slot_idx].compressed_size = final_size;
    s->slots[slot_idx].is_final = is_final;
    s->slots[slot_idx].is_ready = true;
    
    flush_ready_slots_locked(s);
    pthread_mutex_unlock(&s->mutex);
}

typedef struct {
    ttzip_zip_chunked_stream_t* s;
    uint64_t seq;
    uint8_t* uncompressed_data;
    size_t uncompressed_size;
    bool is_final;
} chunk_worker_arg_t;

static void chunk_worker_trampoline(void* arg) {
    chunk_worker_arg_t* w = (chunk_worker_arg_t*)arg;
    if (w) {
        compress_chunk_worker(w->s, w->seq, w->uncompressed_data, w->uncompressed_size, w->is_final);
        free(w);
    }
}

static int flush_current_buffer_locked(ttzip_zip_chunked_stream_t* s, bool is_final) {
    if (s->current_in_len == 0 && !is_final) {
        return 0;
    }
    
    // Backpressure: wait if in-flight slots reach maximum limit
    while ((s->next_seq_to_submit - s->next_seq_to_write) >= TTZIP_CHUNK_MAX_IN_FLIGHT && !s->has_error) {
        pthread_cond_wait(&s->cond, &s->mutex);
    }
    
    if (s->has_error) {
        return -1;
    }
    
    uint64_t seq = s->next_seq_to_submit++;
    uint8_t* chunk_copy = (uint8_t*)malloc(s->current_in_len > 0 ? s->current_in_len : 1);
    if (!chunk_copy) {
        s->has_error = true;
        return -1;
    }
    
    if (s->current_in_len > 0) {
        memcpy(chunk_copy, s->current_in_buffer, s->current_in_len);
        s->running_crc32 = libdeflate_crc32(s->running_crc32, s->current_in_buffer, s->current_in_len);
        s->total_uncompressed_bytes += s->current_in_len;
    }
    
    size_t len_to_compress = s->current_in_len;
    s->current_in_len = 0;
    
    chunk_worker_arg_t* w = (chunk_worker_arg_t*)malloc(sizeof(chunk_worker_arg_t));
    if (!w) {
        free(chunk_copy);
        s->has_error = true;
        return -1;
    }
    w->s = s;
    w->seq = seq;
    w->uncompressed_data = chunk_copy;
    w->uncompressed_size = len_to_compress;
    w->is_final = is_final;
    
    if (ttzip_threadpool_submit(ttzip_threadpool_shared(), chunk_worker_trampoline, w) != 0) {
        // Fallback synchronously if pool queue rejected
        chunk_worker_trampoline(w);
    }
    
    return 0;
}

ttzip_zip_chunked_stream_t* ttzip_zip_chunked_stream_create(int out_fd, int level) {
    ttzip_zip_chunked_stream_t* s = (ttzip_zip_chunked_stream_t*)calloc(1, sizeof(ttzip_zip_chunked_stream_t));
    if (!s) return NULL;
    
    s->out_fd = out_fd;
    s->level = level > 0 ? (level > 12 ? 12 : level) : 6;
    s->current_in_buffer = (uint8_t*)malloc(TTZIP_CHUNK_SIZE_BYTES);
    if (!s->current_in_buffer) {
        free(s);
        return NULL;
    }
    
    pthread_mutex_init(&s->mutex, NULL);
    pthread_cond_init(&s->cond, NULL);
    
    return s;
}

int64_t ttzip_zip_chunked_stream_write(ttzip_zip_chunked_stream_t* s, const void* data, size_t size) {
    if (!s || s->has_error) return -1;
    if (!data || size == 0) return 0;
    
    const uint8_t* ptr = (const uint8_t*)data;
    size_t remaining = size;
    
    while (remaining > 0) {
        size_t available_in_chunk = TTZIP_CHUNK_SIZE_BYTES - s->current_in_len;
        size_t to_copy = remaining < available_in_chunk ? remaining : available_in_chunk;
        
        memcpy(s->current_in_buffer + s->current_in_len, ptr, to_copy);
        s->current_in_len += to_copy;
        ptr += to_copy;
        remaining -= to_copy;
        
        if (s->current_in_len >= TTZIP_CHUNK_SIZE_BYTES) {
            pthread_mutex_lock(&s->mutex);
            int res = flush_current_buffer_locked(s, false);
            pthread_mutex_unlock(&s->mutex);
            if (res != 0) return -1;
        }
    }
    
    return (int64_t)size;
}

int ttzip_zip_chunked_stream_finish(ttzip_zip_chunked_stream_t* s, uint64_t* out_total_compressed, uint32_t* out_final_crc32) {
    if (!s) return -1;
    
    pthread_mutex_lock(&s->mutex);
    flush_current_buffer_locked(s, true);
    
    while (s->next_seq_to_write < s->next_seq_to_submit && !s->has_error) {
        flush_ready_slots_locked(s);
        if (s->next_seq_to_write < s->next_seq_to_submit) {
            pthread_cond_wait(&s->cond, &s->mutex);
        }
    }
    
    bool ok = !s->has_error;
    if (out_total_compressed) *out_total_compressed = s->total_compressed_bytes;
    if (out_final_crc32) *out_final_crc32 = s->running_crc32;
    pthread_mutex_unlock(&s->mutex);
    
    return ok ? 0 : -1;
}

void ttzip_zip_chunked_stream_destroy(ttzip_zip_chunked_stream_t* s) {
    if (!s) return;
    
    pthread_mutex_lock(&s->mutex);
    if (s->current_in_buffer) {
        free(s->current_in_buffer);
        s->current_in_buffer = NULL;
    }
    
    for (size_t i = 0; i < TTZIP_CHUNK_MAX_IN_FLIGHT; i++) {
        if (s->slots[i].compressed_data) {
            free(s->slots[i].compressed_data);
            s->slots[i].compressed_data = NULL;
        }
    }
    pthread_mutex_unlock(&s->mutex);
    
    pthread_mutex_destroy(&s->mutex);
    pthread_cond_destroy(&s->cond);
    free(s);
}
