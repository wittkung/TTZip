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

/**
 * @brief Decoded metadata of a TAR 512-byte header block.
 */
typedef struct {
    uint32_t magic;           /**< TTZIP_STRUCT_MAGIC sentinel */
    uint64_t size;            /**< Uncompressed file size in bytes */
    uint32_t mode;            /**< POSIX file permissions mode */
    int64_t mtime;            /**< Modification time (seconds since epoch) */
    uint8_t typeflag;         /**< TAR entry type flag ('0'=reg, '5'=dir, '2'=symlink) */
    bool is_ustar;            /**< True if USTAR / POSIX.1-1988 magic detected */
    bool is_eoa_zero;         /**< True if block is 512-byte all-zero End-of-Archive record */
    bool checksum_valid;      /**< True if stored checksum matches computed sum */
    uint32_t stored_checksum; /**< Stored header checksum */
    uint32_t computed_unsigned;/**< Computed POSIX unsigned checksum */
    int32_t computed_signed;  /**< Computed legacy BSD signed checksum */
    char name[256];           /**< Extracted normalized file path */
} ttzip_tar_entry_info_t;

/**
 * @brief Parses an 8-byte ASCII octal integer using 64-bit SWAR 3-level binary reduction.
 *
 * @param[in] w_be 8-byte big-endian ASCII octal digits.
 * @return uint64_t Decoded integer value.
 *
 * @pre All 8 bytes must be ASCII '0'..'7' (0x30..0x37).
 * @post Return value is in range [0, 0o77777777].
 * @invariant 100% Branchless, zero heap allocations, completes in 4-6 CPU cycles.
 * @complexity Time: O(1) | Space: O(1)
 * @threadsafe Fully reentrant and thread-safe.
 */
TTZIP_API uint64_t ttzip_octal_parse8_swar(uint64_t w_be);

/**
 * @brief Parses variable-length octal or GNU base-256 binary integer from a TAR header field.
 *
 * @param[in] p   Pointer to the character buffer.
 * @param[in] len Length of the field in bytes (e.g. 8 for mode, 12 for size).
 * @return uint64_t Decoded value, or 0 if empty/invalid.
 *
 * @pre `p != NULL && len > 0`
 * @complexity Time: O(len) | Space: O(1)
 * @threadsafe Reentrant and thread-safe.
 */
TTZIP_API uint64_t ttzip_tar_parse_octal(const char* p, size_t len);

/**
 * @brief Fast check whether a 512-byte block is entirely composed of zero bytes (EoA marker).
 *
 * @param[in] block 512-byte aligned or unaligned memory buffer.
 * @return bool True if all 512 bytes are 0x00, false otherwise.
 *
 * @pre `block != NULL`
 * @complexity Time: O(1) (64 word OR operations) | Space: O(1)
 * @threadsafe Reentrant and thread-safe.
 */
TTZIP_API bool ttzip_tar_is_zero_block_512(const uint8_t block[512]);

/**
 * @brief Computes both POSIX unsigned and BSD signed 512-byte header checksums with O(1) adjustment.
 *
 * @param[in]  block             512-byte TAR header block.
 * @param[out] out_unsigned_sum  Pointer to store POSIX unsigned checksum sum.
 * @param[out] out_signed_sum    Pointer to store BSD signed checksum sum.
 *
 * @pre `block != NULL && out_unsigned_sum != NULL && out_signed_sum != NULL`
 * @complexity Time: O(1) (~6-10ns on Apple Silicon via NEON vpadalq) | Space: O(1)
 * @threadsafe Reentrant and thread-safe.
 */
TTZIP_API void ttzip_tar_checksum_512(const uint8_t block[512], uint32_t* out_unsigned_sum, int32_t* out_signed_sum);

/**
 * @brief Fast single-pass TAR 512-byte header parser and validator.
 *
 * @param[in]  block     512-byte TAR block.
 * @param[out] out_entry Decoded entry metadata structure.
 * @return bool True if parsing succeeded (even if EoA zero), false on invalid header structure.
 *
 * @pre `block != NULL && out_entry != NULL`
 * @post `out_entry` is populated with validated name, size, mode, and checksum validity flag.
 * @complexity Time: O(1) | Space: O(1)
 * @threadsafe Reentrant and thread-safe.
 */
TTZIP_API bool ttzip_tar_header_parse_fast(const uint8_t block[512], ttzip_tar_entry_info_t* out_entry);

#ifdef __cplusplus
}
#endif

#endif // TTZIP_TAR_NATIVE_H
