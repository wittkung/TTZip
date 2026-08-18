// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file CTTZipCRC32Neon.h
 * @brief High-performance ARM NEON & PMULL hardware CRC-32 calculation interfaces.
 */

#ifndef CTTZipCRC32Neon_h
#define CTTZipCRC32Neon_h

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Standard entry point for hardware-accelerated CRC-32 calculation (IEEE 802.3).
 * @details Automatically dispatches to 12-way PMULL+EOR3 folding on Apple Silicon (> 65 GB/s),
 *          or scalar fallback on generic architectures.
 * @param crc Initial running CRC-32 (pass 0 for first chunk).
 * @param buf Pointer to byte buffer.
 * @param len Length of buffer in bytes.
 * @return 32-bit updated CRC-32 checksum.
 */
uint32_t ttzip_core_crc32_neon_single(uint32_t crc, const uint8_t* buf, size_t len);

/**
 * @brief Dedicated 12-way PMULL wide vector folding CRC-32 kernel.
 */
uint32_t ttzip_crc32_pmull_wide(uint32_t crc, const uint8_t* buf, size_t len);

/**
 * @brief Reference portable scalar slice-by-8 CRC-32 kernel.
 */
uint32_t ttzip_crc32_scalar(uint32_t crc, const uint8_t* buf, size_t len);

/**
 * @brief Unified fast-path alias for C bridge and Swift callers.
 */
uint32_t ttzip_crc32_fast(uint32_t crc, const uint8_t* data, size_t len);

#ifdef __cplusplus
}
#endif

#endif // CTTZipCRC32Neon_h
