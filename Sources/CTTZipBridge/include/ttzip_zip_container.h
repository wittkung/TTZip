// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine.

/**
 * @file ttzip_zip_container.h
 * @brief High-performance C11 ZIP container metadata framing, Local Headers, Central Directory & EOCD.
 */

#ifndef TTZIP_ZIP_CONTAINER_H
#define TTZIP_ZIP_CONTAINER_H

#include "ttzip_platform.h"
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

#define TTZIP_ZIP_LOCAL_HEADER_MAGIC 0x04034b50
#define TTZIP_ZIP_CD_HEADER_MAGIC    0x02014b50
#define TTZIP_ZIP_EOCD_MAGIC         0x06054b50
#define TTZIP_ZIP64_EOCD_MAGIC       0x06064b50
#define TTZIP_ZIP64_LOCATOR_MAGIC    0x07064b50

#define TTZIP_ZIP_LOCAL_HEADER_SIZE  30
#define TTZIP_ZIP_CD_HEADER_SIZE     46
#define TTZIP_ZIP_EOCD_SIZE          22

typedef struct ttzip_zip_entry_meta {
    const char *file_name;
    uint16_t file_name_len;
    uint32_t crc32;
    uint64_t compressed_size;
    uint64_t uncompressed_size;
    uint64_t local_header_offset;
    uint16_t compression_method; /* 0 = Store, 8 = Deflate, 93 = Zstd */
    uint32_t dos_datetime;
    uint32_t external_attributes;
    bool is_directory;
    bool is_utf8;
} ttzip_zip_entry_meta_t;

/**
 * @brief Writes a PKZip Local File Header into the provided buffer.
 * @return Number of bytes written, or 0 if output buffer is too small.
 */
TTZIP_API size_t ttzip_zip_write_local_header(
    const ttzip_zip_entry_meta_t *meta,
    void *out_buf,
    size_t out_buf_cap
);

/**
 * @brief Writes a Central Directory Record into the provided buffer.
 * @return Number of bytes written, or 0 if output buffer is too small.
 */
TTZIP_API size_t ttzip_zip_write_cd_header(
    const ttzip_zip_entry_meta_t *meta,
    void *out_buf,
    size_t out_buf_cap
);

/**
 * @brief Writes End of Central Directory (EOCD) into the provided buffer.
 * @return Number of bytes written, or 0 if output buffer is too small.
 */
TTZIP_API size_t ttzip_zip_write_eocd(
    uint16_t entry_count,
    uint32_t cd_size,
    uint32_t cd_offset,
    void *out_buf,
    size_t out_buf_cap
);

#ifdef __cplusplus
}
#endif

#endif /* TTZIP_ZIP_CONTAINER_H */
