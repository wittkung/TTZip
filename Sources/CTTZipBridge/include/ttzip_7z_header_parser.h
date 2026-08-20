// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_7z_header_parser.h
 * @brief 7Z archive header metadata parsing and resource management.
 */

#ifndef TTZIP_7Z_HEADER_PARSER_H
#define TTZIP_7Z_HEADER_PARSER_H

#include "ttzip_platform.h"
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    char rel_path[1024];
    uint64_t file_size;
    bool is_dir;
    bool is_empty_stream;
} ttzip_7z_file_meta_t;

typedef struct {
    uint32_t magic;
    uint64_t primary_method_id;
    uint64_t total_folders;
    size_t payload_offset;
    size_t payload_len;
    
    // AES-256 Crypto Info
    bool is_encrypted;
    uint32_t aes_num_cycles_power;
    uint8_t aes_salt[16];
    size_t aes_salt_len;
    uint8_t aes_iv[16];
    size_t aes_iv_len;

    // Coder Properties (e.g. LZMA1 5-byte properties)
    uint8_t coder_props[32];
    size_t coder_props_len;

    // File and Stream Sizes Metadata
    ttzip_7z_file_meta_t* files;
    size_t num_files;
    uint64_t* stream_sizes;
    size_t num_stream_sizes;
    uint64_t* coder_unpack_sizes;
    size_t num_coder_unpack_sizes;
    uint32_t* stream_crcs;
    size_t num_stream_crcs;
} ttzip_7z_header_info_t;

/**
 * @brief Decodes a 7Z variable-length 64-bit integer using branchless __builtin_clz and 64-bit load.
 *
 * @param[in]  buf Pointer to the input byte buffer.
 * @param[in]  len Available bytes in buffer.
 * @param[out] val Pointer to store the decoded 64-bit integer.
 * @return size_t Number of bytes consumed (1 to 9), or 0 if `len` is insufficient.
 *
 * @pre `buf != NULL && val != NULL`
 * @post If return > 0, `val` contains the decoded value without UB shift overflow.
 * @complexity Time: O(1) (~3-4 CPU cycles) | Space: O(1)
 * @threadsafe Fully reentrant and thread-safe.
 */
TTZIP_API size_t ttzip_7z_read_varint(const uint8_t* buf, size_t len, uint64_t* val);

/**
 * @brief Parses 7Z archive header metadata, folder structures, and encryption parameters.
 *
 * @param[in]  mapped_data Read-only memory-mapped archive buffer.
 * @param[in]  file_size   Total archive file size in bytes.
 * @param[out] out_info    Pointer to the output header metadata structure.
 * @return int 0 on success, negative error code on failure.
 *
 * @pre `mapped_data != NULL && file_size >= 32 && out_info != NULL`
 * @post `out_info` is initialized and populated with heap-allocated arrays (must be freed via `ttzip_7z_free_header_info`).
 * @complexity Time: O(metadata_size) | Space: O(num_files)
 * @threadsafe Reentrant across independent header info objects.
 */
TTZIP_API int ttzip_7z_parse_header_metadata(
    const uint8_t* mapped_data,
    size_t file_size,
    ttzip_7z_header_info_t* out_info
);

/**
 * @brief Frees all dynamically allocated arrays inside a 7Z header info struct and poisons memory.
 *
 * @param[in,out] info Pointer to the header info structure to deallocate.
 *
 * @pre `info != NULL`
 * @post Internal file and size arrays are freed and pointers set to NULL.
 * @threadsafe Thread-safe on exclusive instance.
 */
TTZIP_API void ttzip_7z_free_header_info(ttzip_7z_header_info_t* info);

typedef struct {
    uint8_t major_version;
    uint8_t minor_version;
    uint32_t start_header_crc;
    uint64_t next_header_offset;
    uint64_t next_header_size;
    uint32_t next_header_crc;
} ttzip_7z_signature_header_t;

/**
 * @brief Parses and validates 32-byte 7z Signature Header.
 */
TTZIP_API int ttzip_7z_parse_signature_header(
    const uint8_t* mapped_data,
    size_t file_size,
    ttzip_7z_signature_header_t* out_sig
);

#ifdef __cplusplus
}
#endif

#endif // TTZIP_7Z_HEADER_PARSER_H
