// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_7z_header_writer.h
 * @brief 7Z archive header metadata serialization and disk flushing routines.
 */

#ifndef TTZIP_7Z_HEADER_WRITER_H
#define TTZIP_7Z_HEADER_WRITER_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include "CTTZip7zStoreInternal.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    int level;
    bool has_password;
    uint32_t num_cycles_power;
    const uint8_t* aes_iv;
    size_t packed_stream_size;
    uint64_t total_uncompressed_bytes;
    size_t total_compressed_len;
    uint32_t max_dict_size;
    size_t num_streams;
    size_t num_empty_streams;
    size_t num_empty_files;
} ttzip_7z_header_params_t;

size_t ttzip_7z_enc_write_varint(uint8_t* buf, uint64_t val);
size_t ttzip_7z_enc_utf8_to_utf16le(const char* utf8, uint8_t* out_utf16);
uint8_t ttzip_7z_enc_dict_to_prop(uint32_t dict_size);

int ttzip_7z_write_metadata_and_flush(
    int out_fd,
    const ttzip_7z_store_list_t* list,
    const ttzip_7z_header_params_t* params
);

#ifdef __cplusplus
}
#endif

#endif // TTZIP_7Z_HEADER_WRITER_H
