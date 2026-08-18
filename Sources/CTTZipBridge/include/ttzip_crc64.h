// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_crc64.h
 * @brief ARM64 PMULL hardware accelerated and scalar fallback CRC64 (ECMA-182) engine.
 * @details ARMv8-A vmull_p64 4-way 64-byte vector folding with Barrett polynomial reduction.
 */

#ifndef TTZIP_CRC64_H
#define TTZIP_CRC64_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

uint64_t ttzip_crc64(const uint8_t *buf, size_t size, uint64_t crc);
uint64_t ttzip_crc64_pmull(const uint8_t *buf, size_t size, uint64_t crc);
uint64_t ttzip_crc64_scalar(const uint8_t *buf, size_t size, uint64_t crc);

#ifdef __cplusplus
}
#endif

#endif // TTZIP_CRC64_H
