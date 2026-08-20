// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine.

/**
 * @file ttzip_7z_container.h
 * @brief Pure C11 7Z container signature and Start Header serialization.
 */

#ifndef TTZIP_7Z_CONTAINER_H
#define TTZIP_7Z_CONTAINER_H

#include "ttzip_platform.h"
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

#define TTZIP_7Z_SIGNATURE_SIZE 32

/**
 * @brief 7z 6-byte signature magic: '7', 'z', 0xBC, 0xAF, 0x27, 0x1C.
 */
extern const uint8_t TTZIP_7Z_MAGIC[6];

/**
 * @brief Serializes a 32-byte 7Z file Signature Header.
 * @param next_header_offset Byte offset from end of Signature Header to Next Header.
 * @param next_header_size Byte size of Next Header block.
 * @param next_header_crc CRC32 of Next Header.
 * @param dst_header 32-byte destination buffer.
 * @return 32 on success, or 0 on error.
 */
TTZIP_API size_t ttzip_7z_write_signature_header(
    uint64_t next_header_offset,
    uint64_t next_header_size,
    uint32_t next_header_crc,
    uint8_t dst_header[TTZIP_7Z_SIGNATURE_SIZE]
);

#ifdef __cplusplus
}
#endif

#endif /* TTZIP_7Z_CONTAINER_H */
