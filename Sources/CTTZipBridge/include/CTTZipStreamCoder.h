// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file CTTZipStreamCoder.h
 * @brief Unified streaming compression codec abstractions and CPU feature detection.
 */

#ifndef CTTZIP_STREAM_CODER_H
#define CTTZIP_STREAM_CODER_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

struct libdeflate_compressor;
struct libdeflate_decompressor;

struct libdeflate_compressor* ttzip_get_tls_compressor(int level);
struct libdeflate_decompressor* ttzip_get_tls_decompressor(void);

size_t ttzip_libdeflate_compress(const void* src, size_t src_size, void* dst, size_t dst_capacity, int level);
size_t ttzip_libdeflate_decompress(const void* src, size_t src_size, void* dst, size_t dst_capacity);

typedef enum {
    TTZIP_CODEC_STORE = 0,
    TTZIP_CODEC_DEFLATE = 8,
    TTZIP_CODEC_AES256 = 99,
    TTZIP_CODEC_ZSTD = 93,
    TTZIP_CODEC_XZ = 95
} ttzip_codec_type_t;

typedef enum {
    TTZIP_DEFLATE_TIER_BLOCK = 1,
    TTZIP_DEFLATE_TIER_STREAM = 2
} ttzip_deflate_tier_t;

typedef struct {
    uint32_t tier_mode;          // 1 = libdeflate block, 2 = zlib-ng streaming
    int32_t compression_level;   // 1 to 9
    int32_t window_bits;         // 15 (zlib), 31 (gzip), -15 (raw)
    int32_t mem_level;           // 1 to 9 (default 8)
    int32_t strategy;            // 0=Default, 1=Filtered, 2=HuffmanOnly, 3=RLE, 4=Fixed
} ttzip_deflate_stream_config_t;

#define TTZIP_DEFLATE_STREAM_MAGIC 0x545A4453U // 'TZDS'

typedef struct ttzip_deflate_stream_state {
    uint32_t magic;              // TTZIP_DEFLATE_STREAM_MAGIC
    uint32_t tier_mode;          // TTZIP_DEFLATE_TIER_BLOCK or TTZIP_DEFLATE_TIER_STREAM
    uint64_t total_in;
    uint64_t total_out;
    uint32_t adler32_checksum;
    uint32_t crc32_checksum;
    bool is_finished;
    int32_t last_status;
    void* internal_state;        // z_stream or internal buffer
} ttzip_deflate_stream_state_t;

typedef struct {
    bool has_arm_neon;
    bool has_arm_crc32;
    bool has_x86_avx2;
    bool has_x86_avx512;
    bool has_x86_vpclmul;
} ttzip_hardware_capabilities_t;

ttzip_hardware_capabilities_t ttzip_detect_cpu_features(void);

int ttzip_deflate_stream_init(ttzip_deflate_stream_state_t* state, const ttzip_deflate_stream_config_t* config);
size_t ttzip_deflate_stream_process(ttzip_deflate_stream_state_t* state, const uint8_t* in_buf, size_t in_len, uint8_t* out_buf, size_t out_cap, int flush);
void ttzip_deflate_stream_free(ttzip_deflate_stream_state_t* state);

int ttzip_inflate_stream_init(ttzip_deflate_stream_state_t* state, int window_bits);
size_t ttzip_inflate_stream_process(ttzip_deflate_stream_state_t* state, const uint8_t* in_buf, size_t in_len, uint8_t* out_buf, size_t out_cap, int flush);
void ttzip_inflate_stream_free(ttzip_deflate_stream_state_t* state);

typedef struct ttzip_stream_coder {
    ttzip_codec_type_t codec_type;
    void* user_data;
    int (*init)(struct ttzip_stream_coder* coder, int level, const char* password);
    size_t (*process_chunk)(struct ttzip_stream_coder* coder, const uint8_t* src, size_t src_len, uint8_t* dst, size_t dst_cap);
    void (*free_coder)(struct ttzip_stream_coder* coder);
} ttzip_stream_coder_t;

ttzip_stream_coder_t* ttzip_create_stream_coder(ttzip_codec_type_t codec);
void ttzip_destroy_stream_coder(ttzip_stream_coder_t* coder);

#ifdef __cplusplus
}
#endif

#endif // CTTZIP_STREAM_CODER_H
