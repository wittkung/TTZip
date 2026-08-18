// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file CTTZipChecksum.h
 * @brief Hardware-accelerated Adler-32 and CRC-32 checksum kernel interface.
 * @details Implements ARM64 PMULL / DotProd / AVX2 vectorization with NMAX=5552 deferred modular reduction.
 */

#ifndef CTTZIP_CHECKSUM_H
#define CTTZIP_CHECKSUM_H

#include "ttzip_platform.h"
#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief 硬件级极速 Adler-32 校验和计算
 * @param adler 初始 Adler-32 值 (初次调用传入 1)
 * @param data  待计算数据缓冲区指针
 * @param len   待计算数据字节长度
 * @return 计算更新后的 32-bit Adler-32 校验和
 */
TTZIP_API uint32_t ttzip_adler32_fast(uint32_t adler, const uint8_t *data, size_t len);

/**
 * @brief 硬件级极速 CRC-32 校验和计算 (直通 libdeflate_crc32 / PMULL 宽折叠)
 * @param crc  初始 CRC-32 值 (初次调用传入 0)
 * @param data 待计算数据缓冲区指针
 * @param len  待计算数据字节长度
 * @return 计算更新后的 32-bit CRC-32 校验和
 */
TTZIP_API uint32_t ttzip_crc32_fast(uint32_t crc, const uint8_t *data, size_t len);

#ifdef __cplusplus
}
#endif

#endif /* CTTZIP_CHECKSUM_H */
