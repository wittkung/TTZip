// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_fl2_lzma2.h
 * @brief High-performance Fast-LZMA2 multi-threaded block and streaming compressor.
 */

#ifndef TTZIP_FL2_LZMA2_H
#define TTZIP_FL2_LZMA2_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

#define TTZIP_FL2C_MAGIC 0x464C3243U /* "FL2C" */
#define TTZIP_FL2S_MAGIC 0x464C3253U /* "FL2S" */

int ttzip_fl2_compress_block(
    const uint8_t* src,
    size_t src_len,
    uint8_t* dst,
    size_t dst_capacity,
    size_t* out_compressed_len,
    int level,
    bool is_zero_block,
    uint32_t* out_dict_size,
    int thread_count
);

typedef struct ttzip_fl2_stream_ctx_s ttzip_fl2_stream_ctx_t;

ttzip_fl2_stream_ctx_t* ttzip_fl2_stream_create(int level, uint32_t dict_size, int thread_count);

int ttzip_fl2_stream_process(
    ttzip_fl2_stream_ctx_t* ctx,
    const uint8_t* in_data,
    size_t in_size,
    size_t* in_consumed,
    uint8_t* out_buf,
    size_t out_capacity,
    size_t* out_produced,
    bool is_end
);

void ttzip_fl2_stream_free(ttzip_fl2_stream_ctx_t* ctx);

bool ttzip_fl2_is_supported(void);

#ifdef __cplusplus
}
#endif

#endif /* TTZIP_FL2_LZMA2_H */
