// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_tar_native.h
 * @brief High-performance TAR 512-byte header SWAR parsing, checksum vectorization, and metadata extraction.
 */

#ifndef TTZIP_TAR_NATIVE_H
#define TTZIP_TAR_NATIVE_H

#include "ttzip_platform.h"
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    uint64_t size;
    uint32_t mode;
    int64_t mtime;
    uint8_t typeflag;
    bool is_ustar;
    bool is_eoa_zero;
    bool checksum_valid;
    uint32_t stored_checksum;
    uint32_t computed_unsigned;
    int32_t computed_signed;
    char name[256];
} ttzip_tar_entry_info_t;

TTZIP_API uint64_t ttzip_octal_parse8_swar(uint64_t w_be);
TTZIP_API uint64_t ttzip_tar_parse_octal(const char* p, size_t len);
TTZIP_API bool ttzip_tar_is_zero_block_512(const uint8_t block[512]);
TTZIP_API void ttzip_tar_checksum_512(const uint8_t block[512], uint32_t* out_unsigned_sum, int32_t* out_signed_sum);
TTZIP_API bool ttzip_tar_header_parse_fast(const uint8_t block[512], ttzip_tar_entry_info_t* out_entry);

#ifdef __cplusplus
}
#endif

#endif // TTZIP_TAR_NATIVE_H
