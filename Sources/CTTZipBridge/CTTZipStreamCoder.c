// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/CTTZipStreamCoder.h"
#include "include/CTTZipBridge.h"
#include "include/CTTZipPlatform.h"
#include <stdlib.h>
#include <string.h>
#include <libdeflate.h>
#include <limits.h>
#include "lz4.h"

#include <zlib.h>

static TTZIP_THREAD_LOCAL struct libdeflate_compressor* g_tls_compressors[14] = { NULL };
static TTZIP_THREAD_LOCAL struct libdeflate_decompressor* g_tls_decompressor = NULL;

struct libdeflate_compressor* ttzip_get_tls_compressor(int level) {
    int l = level > 0 ? (level > 12 ? 12 : (level == 6 ? 4 : level)) : 4;
    if (!g_tls_compressors[l]) {
        g_tls_compressors[l] = libdeflate_alloc_compressor(l);
    }
    return g_tls_compressors[l];
}

struct libdeflate_decompressor* ttzip_get_tls_decompressor(void) {
    if (!g_tls_decompressor) {
        g_tls_decompressor = libdeflate_alloc_decompressor();
    }
    return g_tls_decompressor;
}

size_t ttzip_libdeflate_compress(const void* src, size_t src_size, void* dst, size_t dst_capacity, int level) {
    if (!src || !dst || src_size == 0 || dst_capacity == 0) return 0;
    TTZIP_PREFETCH(src);
    struct libdeflate_compressor* compressor = ttzip_get_tls_compressor(level);
    if (!compressor) return 0;
    return libdeflate_deflate_compress(compressor, src, src_size, dst, dst_capacity);
}

size_t ttzip_libdeflate_decompress(const void* src, size_t src_size, void* dst, size_t dst_capacity) {
    if (!src || !dst || src_size == 0 || dst_capacity == 0) return 0;
    __builtin_prefetch(src, 0, 3);
    struct libdeflate_decompressor* decompressor = ttzip_get_tls_decompressor();
    if (!decompressor) return 0;
    size_t actual_out = 0;
    enum libdeflate_result res = libdeflate_deflate_decompress(decompressor, src, src_size, dst, dst_capacity, &actual_out);
    return (res == LIBDEFLATE_SUCCESS) ? actual_out : 0;
}

size_t ttzip_raw_deflate_block_compress(const void* src, size_t src_size, void* dst, size_t dst_capacity, int level, bool is_final) {
    if (!src || !dst || src_size == 0 || dst_capacity == 0) return 0;
    
    z_stream strm;
    memset(&strm, 0, sizeof(strm));
    
    int z_lvl = level > 0 ? (level > 9 ? 9 : level) : 6;
    int ret = deflateInit2(&strm, z_lvl, Z_DEFLATED, -15, 8, Z_DEFAULT_STRATEGY);
    if (ret != Z_OK) return 0;
    
    strm.next_in = (Bytef*)src;
    strm.avail_in = (uInt)src_size;
    strm.next_out = (Bytef*)dst;
    strm.avail_out = (uInt)dst_capacity;
    
    int flush = is_final ? Z_FINISH : Z_SYNC_FLUSH;
    ret = deflate(&strm, flush);
    if (ret < 0 || (is_final && ret != Z_STREAM_END)) {
        deflateEnd(&strm);
        return 0;
    }
    
    size_t comp_size = (size_t)strm.total_out;
    deflateEnd(&strm);
    return comp_size;
}

static TTZIP_THREAD_LOCAL LZ4_stream_t* g_tls_lz4_stream = NULL;

static LZ4_stream_t* ttzip_get_tls_lz4_stream(void) {
    if (!g_tls_lz4_stream) {
        g_tls_lz4_stream = LZ4_createStream();
    }
    return g_tls_lz4_stream;
}

size_t ttzip_lz4_compress_bound(size_t src_size) {
    if (src_size > INT_MAX) return 0;
    int bound = LZ4_compressBound((int)src_size);
    return bound > 0 ? (size_t)bound : 0;
}

size_t ttzip_lz4_compress(const void* src, size_t src_size, void* dst, size_t dst_capacity, int acceleration) {
    if (!src || !dst || src_size == 0 || dst_capacity == 0) return 0;
    if (src_size > INT_MAX || dst_capacity > INT_MAX) return 0;
    int accel = acceleration > 0 ? acceleration : 1;
    
    // Adaptive heuristics: <= 64KB utilizes TLS stream state, > 64KB uses direct one-shot compression
    if (src_size <= 64 * 1024) {
        LZ4_stream_t* stream = ttzip_get_tls_lz4_stream();
        if (stream) {
            LZ4_resetStream_fast(stream);
            int res = LZ4_compress_fast_continue(stream, (const char*)src, (char*)dst, (int)src_size, (int)dst_capacity, accel);
            return res > 0 ? (size_t)res : 0;
        }
    }
    
    int res = LZ4_compress_fast((const char*)src, (char*)dst, (int)src_size, (int)dst_capacity, accel);
    return res > 0 ? (size_t)res : 0;
}

size_t ttzip_lz4_compress_fast_tls(const void* src, size_t src_size, void* dst, size_t dst_capacity, int acceleration) {
    if (!src || !dst || src_size == 0 || dst_capacity == 0) return 0;
    if (src_size > INT_MAX || dst_capacity > INT_MAX) return 0;
    LZ4_stream_t* stream = ttzip_get_tls_lz4_stream();
    if (!stream) {
        return ttzip_lz4_compress(src, src_size, dst, dst_capacity, acceleration);
    }
    LZ4_resetStream_fast(stream);
    int accel = acceleration > 0 ? acceleration : 1;
    int res = LZ4_compress_fast_continue(stream, (const char*)src, (char*)dst, (int)src_size, (int)dst_capacity, accel);
    return res > 0 ? (size_t)res : 0;
}

size_t ttzip_lz4_decompress(const void* src, size_t src_size, void* dst, size_t dst_capacity) {
    if (!src || !dst || src_size == 0 || dst_capacity == 0) return 0;
    if (src_size > INT_MAX || dst_capacity > INT_MAX) return 0;
    int res = LZ4_decompress_safe((const char*)src, (char*)dst, (int)src_size, (int)dst_capacity);
    return res > 0 ? (size_t)res : 0;
}

size_t ttzip_lz4_decompress_partial(const void* src, size_t src_size, void* dst, size_t target_size, size_t dst_capacity) {
    if (!src || !dst || src_size == 0 || dst_capacity == 0 || target_size == 0) return 0;
    if (src_size > INT_MAX || dst_capacity > INT_MAX || target_size > INT_MAX) return 0;
    int res = LZ4_decompress_safe_partial((const char*)src, (char*)dst, (int)src_size, (int)target_size, (int)dst_capacity);
    return res > 0 ? (size_t)res : 0;
}

static int store_init(ttzip_stream_coder_t* coder, int level, const char* password) {
    (void)coder; (void)level; (void)password;
    return 0;
}

static size_t store_process_chunk(ttzip_stream_coder_t* coder, const uint8_t* src, size_t src_len, uint8_t* dst, size_t dst_cap) {
    (void)coder;
    if (dst_cap < src_len) return 0;
    memcpy(dst, src, src_len);
    return src_len;
}

static void store_free(ttzip_stream_coder_t* coder) {
    (void)coder;
}

ttzip_stream_coder_t* ttzip_create_stream_coder(ttzip_codec_type_t codec) {
    ttzip_stream_coder_t* coder = (ttzip_stream_coder_t*)malloc(sizeof(ttzip_stream_coder_t));
    if (!coder) return NULL;

    memset(coder, 0, sizeof(ttzip_stream_coder_t));
    coder->codec_type = codec;

    if (codec == TTZIP_CODEC_STORE) {
        coder->init = store_init;
        coder->process_chunk = store_process_chunk;
        coder->free_coder = store_free;
    } else {
        coder->init = store_init;
        coder->process_chunk = store_process_chunk;
        coder->free_coder = store_free;
    }

    return coder;
}

#include <zlib.h>

int ttzip_deflate_stream_init(ttzip_deflate_stream_state_t* state, const ttzip_deflate_stream_config_t* config) {
    if (!state || !config) return -1;
    memset(state, 0, sizeof(*state));
    
    state->tier_mode = config->tier_mode;
    z_stream* strm = (z_stream*)calloc(1, sizeof(z_stream));
    if (!strm) return -2;

    int level = config->compression_level > 0 ? config->compression_level : 6;
    int wb = config->window_bits != 0 ? config->window_bits : 15;
    int mem = config->mem_level > 0 ? config->mem_level : 8;
    int strat = config->strategy;

    int ret = deflateInit2(strm, level, Z_DEFLATED, wb, mem, strat);
    if (ret != Z_OK) {
        free(strm);
        return ret;
    }

    state->internal_state = strm;
    state->magic = TTZIP_DEFLATE_STREAM_MAGIC;
    state->adler32_checksum = 1; // standard initial adler32
    return 0;
}

size_t ttzip_deflate_stream_process(ttzip_deflate_stream_state_t* state, const uint8_t* in_buf, size_t in_len, uint8_t* out_buf, size_t out_cap, int flush) {
    if (!state || state->magic != TTZIP_DEFLATE_STREAM_MAGIC || !state->internal_state) return 0;
    if (!out_buf || out_cap == 0) return 0;

    z_stream* strm = (z_stream*)state->internal_state;
    strm->next_in = (Bytef*)in_buf;
    strm->avail_in = (uInt)in_len;
    strm->next_out = (Bytef*)out_buf;
    strm->avail_out = (uInt)out_cap;

    int ret = deflate(strm, flush);
    state->last_status = ret;
    if (ret != Z_OK && ret != Z_STREAM_END && ret != Z_BUF_ERROR) {
        return 0;
    }

    size_t produced = out_cap - strm->avail_out;
    size_t consumed = in_len - strm->avail_in;
    state->total_in += consumed;
    state->total_out += produced;

    if (ret == Z_STREAM_END) {
        state->is_finished = true;
    }
    state->adler32_checksum = (uint32_t)strm->adler;
    if (in_buf && consumed > 0) {
        state->crc32_checksum = libdeflate_crc32(state->crc32_checksum, in_buf, consumed);
    }

    return produced;
}

void ttzip_deflate_stream_free(ttzip_deflate_stream_state_t* state) {
    if (!state || state->magic != TTZIP_DEFLATE_STREAM_MAGIC) return;
    if (state->internal_state) {
        z_stream* strm = (z_stream*)state->internal_state;
        deflateEnd(strm);
        free(strm);
        state->internal_state = NULL;
    }
    state->magic = 0; // Invariant-First: invalidate magic before zeroing
    memset(state, 0, sizeof(*state));
}

int ttzip_inflate_stream_init(ttzip_deflate_stream_state_t* state, int window_bits) {
    if (!state) return -1;
    memset(state, 0, sizeof(*state));

    z_stream* strm = (z_stream*)calloc(1, sizeof(z_stream));
    if (!strm) return -2;

    int wb = window_bits != 0 ? window_bits : 15;
    int ret = inflateInit2(strm, wb);
    if (ret != Z_OK) {
        free(strm);
        return ret;
    }

    state->internal_state = strm;
    state->tier_mode = TTZIP_DEFLATE_TIER_STREAM;
    state->magic = TTZIP_DEFLATE_STREAM_MAGIC;
    state->adler32_checksum = 1;
    state->crc32_checksum = 0;
    state->last_status = Z_OK;
    return 0;
}

size_t ttzip_inflate_stream_process(ttzip_deflate_stream_state_t* state, const uint8_t* in_buf, size_t in_len, uint8_t* out_buf, size_t out_cap, int flush) {
    if (!state || state->magic != TTZIP_DEFLATE_STREAM_MAGIC || !state->internal_state) return 0;
    if (!out_buf || out_cap == 0) return 0;

    z_stream* strm = (z_stream*)state->internal_state;
    strm->next_in = (Bytef*)in_buf;
    strm->avail_in = (uInt)in_len;
    strm->next_out = (Bytef*)out_buf;
    strm->avail_out = (uInt)out_cap;

    int ret = inflate(strm, flush);
    state->last_status = ret;
    if (ret != Z_OK && ret != Z_STREAM_END && ret != Z_BUF_ERROR) {
        return 0;
    }

    size_t produced = out_cap - strm->avail_out;
    size_t consumed = in_len - strm->avail_in;
    state->total_in += consumed;
    state->total_out += produced;

    if (ret == Z_STREAM_END) {
        state->is_finished = true;
    }
    state->adler32_checksum = (uint32_t)strm->adler;
    if (out_buf && produced > 0) {
        state->crc32_checksum = libdeflate_crc32(state->crc32_checksum, out_buf, produced);
    }

    return produced;
}

void ttzip_inflate_stream_free(ttzip_deflate_stream_state_t* state) {
    if (!state || state->magic != TTZIP_DEFLATE_STREAM_MAGIC) return;
    if (state->internal_state) {
        z_stream* strm = (z_stream*)state->internal_state;
        inflateEnd(strm);
        free(strm);
        state->internal_state = NULL;
    }
    state->magic = 0;
    memset(state, 0, sizeof(*state));
}

void ttzip_destroy_stream_coder(ttzip_stream_coder_t* coder) {
    if (!coder) return;
    if (coder->free_coder) {
        coder->free_coder(coder);
    }
    free(coder);
}
