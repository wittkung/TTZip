// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file CTTZipCRC32Neon.h
 * @brief ARM NEON hardware CRC-32 calculation interfaces.
 */

#ifndef CTTZipCRC32Neon_h
#define CTTZipCRC32Neon_h

#include <stdio.h>
#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

uint32_t ttzip_core_crc32_neon_single(uint32_t crc, const uint8_t* buf, size_t len);

#ifdef __cplusplus
}
#endif

#endif // CTTZipCRC32Neon_h
