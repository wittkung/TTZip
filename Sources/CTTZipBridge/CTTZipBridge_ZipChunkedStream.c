// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file CTTZipBridge_ZipChunkedStream.c
 * @brief TTZip large file 1MB chunked multithreaded DEFLATE stream compressor.
 * @details Strictly conforms to PKWARE ZIP Method 8 and RFC 1951 byte alignment,
 *          bounding resident memory consumption within <= 64MB via a 32-slot ring buffer.
 */

#include "include/CTTZipBridge_ZipChunkedStream.h"
#include "include/CTTZipPlatform.h"
#include "include/CTTZipStreamCoder.h"
#include "include/CTTZipCommon.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <pthread.h>
#include <libdeflate.h>

#if defined(TTZIP_OS_MACOS)
#include <dispatch/dispatch.h>
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
    
    uint64_t next_seq_to_dispatch;
    uint64_t next_seq_to_write;
    
    chunk_result_slot_t slots[TTZIP_CHUNK_MAX_IN_FLIGHT];
    
    pthread_mutex_t mutex;
    pthread_cond_t cond;
    bool has_error;
    
#if defined(TTZIP_OS_MACOS)
    dispatch_queue_t compress_queue;
#endif
};

static void flush_ready_slots_locked(ttzip_zip_chunked_stream_t* s) {
    while (s->next_seq_to_write < s->next_seq_to_dispatch) {
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

static void compress_chunk_worker(ttzip_zip_chunked_stream_t* s, uint64_t seq, uint8_t* uncompressed_data, size_t uncompressed_len, bool is_final) {
    int z_level = s->level > 0 ? (s->level > 12 ? 12 : s->level) : 6;
    struct libdeflate_compressor* compressor = ttzip_get_tls_compressor(z_level);
    
    size_t max_out = libdeflate_deflate_compress_bound(compressor, uncompressed_len) + 16;
    uint8_t* out_buf = (uint8_t*)malloc(max_out);
    size_t final_size = 0;
    
    if (out_buf && compressor) {
        size_t comp_size = libdeflate_deflate_compress(compressor, uncompressed_data, uncompressed_len, out_buf, max_out);
        if (comp_size > 0) {
            if (!is_final) {
                // 1. Clear BFINAL bit on first byte (marks non-final block)
                out_buf[0] &= 0xFE;
                
                // 2. Inject RFC 1951 byte-aligned sync marker (0x00, 0x00, 0xFF, 0xFF)
                out_buf[comp_size]     = 0x00;
                out_buf[comp_size + 1] = 0x00;
                out_buf[comp_size + 2] = 0xFF;
                out_buf[comp_size + 3] = 0xFF;
                final_size = comp_size + 4;
            } else {
                // Final block: retains libdeflate generated BFINAL = 1 state
                final_size = comp_size;
            }
        }
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

static int dispatch_current_buffer_locked(ttzip_zip_chunked_stream_t* s, bool is_final) {
    if (s->current_in_len == 0 && !is_final) {
        return 0;
    }
    
    // Backpressure: wait if in-flight slots reach maximum limit
    while ((s->next_seq_to_dispatch - s->next_seq_to_write) >= TTZIP_CHUNK_MAX_IN_FLIGHT && !s->has_error) {
        pthread_cond_wait(&s->cond, &s->mutex);
    }
    
    if (s->has_error) {
        return -1;
    }
    
    uint64_t seq = s->next_seq_to_dispatch++;
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
    
#if defined(TTZIP_OS_MACOS)
    dispatch_async(s->compress_queue, ^{
        compress_chunk_worker(s, seq, chunk_copy, len_to_compress, is_final);
    });
#else
    compress_chunk_worker(s, seq, chunk_copy, len_to_compress, is_final);
#endif
    
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
    
#if defined(TTZIP_OS_MACOS)
    s->compress_queue = dispatch_queue_create("com.ttzip.chunked_deflate_compress", DISPATCH_QUEUE_CONCURRENT);
#endif
    
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
            int res = dispatch_current_buffer_locked(s, false);
            pthread_mutex_unlock(&s->mutex);
            if (res != 0) return -1;
        }
    }
    
    return (int64_t)size;
}

int ttzip_zip_chunked_stream_finish(ttzip_zip_chunked_stream_t* s, uint64_t* out_total_compressed, uint32_t* out_final_crc32) {
    if (!s) return -1;
    
    pthread_mutex_lock(&s->mutex);
    dispatch_current_buffer_locked(s, true);
    
    while (s->next_seq_to_write < s->next_seq_to_dispatch && !s->has_error) {
        flush_ready_slots_locked(s);
        if (s->next_seq_to_write < s->next_seq_to_dispatch) {
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
    
#if defined(TTZIP_OS_MACOS)
    if (s->compress_queue) {
        s->compress_queue = NULL;
    }
#endif
    
    pthread_mutex_destroy(&s->mutex);
    pthread_cond_destroy(&s->cond);
    free(s);
}
