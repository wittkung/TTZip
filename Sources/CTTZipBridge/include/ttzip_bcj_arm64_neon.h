// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_bcj_arm64_neon.h
 * @brief ARM64 NEON vectorized BCJ branch/jump filter encoder and decoder.
 */

#ifndef TTZIP_BCJ_ARM64_NEON_H
#define TTZIP_BCJ_ARM64_NEON_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

size_t ttzip_arm64_bcj_encode_neon(uint8_t* data, size_t size, uint32_t ip);
size_t ttzip_arm64_bcj_decode_neon(uint8_t* data, size_t size, uint32_t ip);

#ifdef __cplusplus
}
#endif

#endif // TTZIP_BCJ_ARM64_NEON_H
