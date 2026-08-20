// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine.

/**
 * @file ttzip_magic_sniff.h
 * @brief High-speed binary magic number sniffing and MIME/format detection.
 */

#ifndef TTZIP_MAGIC_SNIFF_H
#define TTZIP_MAGIC_SNIFF_H

#include "ttzip_platform.h"
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum ttzip_file_kind {
    TTZIP_KIND_UNKNOWN = 0,
    TTZIP_KIND_IMAGE   = 1,
    TTZIP_KIND_VIDEO   = 2,
    TTZIP_KIND_AUDIO   = 3,
    TTZIP_KIND_PDF     = 4,
    TTZIP_KIND_ARCHIVE = 5,
    TTZIP_KIND_TEXT    = 6,
    TTZIP_KIND_CODE    = 7,
    TTZIP_KIND_DOC     = 8
} ttzip_file_kind_t;

typedef struct ttzip_magic_info {
    ttzip_file_kind_t kind;
    const char *format_name;  /**< e.g. "PNG", "JPEG", "ZIP", "7Z", "MP4", "PDF" */
    const char *mime_type;    /**< e.g. "image/png", "application/zip" */
    bool is_archive;
    bool is_media;
} ttzip_magic_info_t;

/**
 * @brief Sniffs binary data buffer (at least 16-32 bytes) and returns format classification.
 */
TTZIP_API ttzip_magic_info_t ttzip_magic_sniff_buffer(const void *buf, size_t len);

/**
 * @brief Opens file via mmap, sniffs magic headers, and returns classification in <1ms.
 */
TTZIP_API ttzip_magic_info_t ttzip_magic_sniff_file(const char *utf8_path);

#ifdef __cplusplus
}
#endif

#endif /* TTZIP_MAGIC_SNIFF_H */
