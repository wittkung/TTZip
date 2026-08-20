// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_7z_block_decoder.h
 * @brief 7Z payload chunk parallel decoder and filter pipeline dispatcher.
 */

#ifndef TTZIP_7Z_BLOCK_DECODER_H
#define TTZIP_7Z_BLOCK_DECODER_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    const uint8_t* pack_ptr;
    size_t pack_size;
    size_t unpack_offset;
    size_t unpack_size;
} ttzip_7z_dec_chunk_t;

int ttzip_7z_decode_payload_parallel(
    const uint8_t* payload_start,
    size_t payload_len,
    uint64_t primary_method_id,
    const uint8_t* coder_props,
    size_t coder_props_len,
    const uint64_t* stream_sizes,
    size_t num_stream_sizes,
    const uint64_t* coder_unpack_sizes,
    size_t num_coder_unpack_sizes,
    uint8_t** out_unpack_buf,
    size_t* out_total_unpacked
);

int ttzip_7z_decode_solid_entry_stream(
    const uint8_t* payload_start,
    size_t payload_len,
    uint64_t primary_method_id,
    const uint8_t* coder_props,
    size_t coder_props_len,
    uint64_t pre_entry_skip_bytes,
    uint64_t target_entry_size,
    uint8_t* out_buffer,
    int out_fd,
    uint32_t* out_crc32
);

#ifdef __cplusplus
}
#endif

#endif /* TTZIP_7Z_BLOCK_DECODER_H */
