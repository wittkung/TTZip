// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#ifndef TTZIP_ZIP_EXTRA_FIELD_H
#define TTZIP_ZIP_EXTRA_FIELD_H

#include "ttzip_platform.h"
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

#define TTZIP_ZIP_TAG_ZIP64             0x0001
#define TTZIP_ZIP_TAG_EXT_TIMESTAMP     0x5455 // "UT"
#define TTZIP_ZIP_TAG_UNICODE_PATH      0x7075 // "up"
#define TTZIP_ZIP_TAG_INFOZIP_UNIX      0x7875 // "ux"
#define TTZIP_ZIP_TAG_WINZIP_AES        0x9901 // "AE"

typedef struct {
    // 0x5455 Extended Timestamp
    bool has_extended_timestamp;
    uint8_t timestamp_flags;
    uint32_t mod_time;
    uint32_t acc_time;
    uint32_t create_time;

    // 0x7075 Unicode Path
    const char* unicode_path;
    size_t unicode_path_len;
    uint32_t unicode_path_crc32;
    bool unicode_path_crc_valid;

    // 0x7875 Info-ZIP Unix
    bool has_posix_permissions;
    uint32_t uid;
    uint32_t gid;

    // 0x0001 Zip64
    bool has_zip64;
    uint64_t uncompressed_size;
    uint64_t compressed_size;
    uint64_t relative_offset;
    uint32_t disk_number;
    uint8_t zip64_presence_mask; // Bit 0: uncomp, Bit 1: comp, Bit 2: offset, Bit 3: disk

    // 0x9901 WinZip AES
    bool has_winzip_aes;
    uint16_t aes_version;
    uint16_t aes_vendor_id;
    uint16_t aes_strength; // 128: AES-128, 192: AES-192, 256: AES-256
    uint16_t aes_actual_method;
} ttzip_zip_extra_fields_t;

/**
 * @brief Parses ZIP Extra Field buffer into a flat struct without memory allocations.
 * @param extra_data Pointer to extra field buffer.
 * @param extra_len Total length of extra field buffer.
 * @param standard_filename Optional standard filename to validate Unicode Path CRC32 (can be NULL).
 * @param out_fields Destination struct.
 * @return 0 on success, negative error code on malformed block.
 */
TTZIP_API int ttzip_zip_parse_extra_fields(
    const uint8_t* extra_data,
    size_t extra_len,
    const char* standard_filename,
    ttzip_zip_extra_fields_t* out_fields
);

#ifdef __cplusplus
}
#endif

#endif // TTZIP_ZIP_EXTRA_FIELD_H
