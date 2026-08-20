// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine.

/**
 * @file ttzip_split.h
 * @brief High-speed zero-copy multi-volume split stream writer and merger.
 */

#ifndef TTZIP_SPLIT_H
#define TTZIP_SPLIT_H

#include "ttzip_platform.h"
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum ttzip_split_style {
    TTZIP_SPLIT_ZIP = 0, /* archive.z01, archive.z02, ..., archive.zip */
    TTZIP_SPLIT_7Z  = 1, /* archive.7z.001, archive.7z.002, ... */
    TTZIP_SPLIT_RAW = 2  /* file.part1, file.part2, ... */
} ttzip_split_style_t;

typedef struct ttzip_split_writer ttzip_split_writer_t;

/**
 * @brief Opens a multi-volume stream writer.
 */
TTZIP_API ttzip_split_writer_t *ttzip_split_writer_open(
    const char *base_path,
    uint64_t max_volume_bytes,
    ttzip_split_style_t style
);

/**
 * @brief Writes bytes to the split stream, automatically rotating to new volume files on boundary.
 */
TTZIP_API size_t ttzip_split_writer_write(
    ttzip_split_writer_t *writer,
    const void *buf,
    size_t len
);

/**
 * @brief Closes the split writer, finalizing the last volume file name.
 */
TTZIP_API int ttzip_split_writer_close(ttzip_split_writer_t *writer);

#ifdef __cplusplus
}
#endif

#endif /* TTZIP_SPLIT_H */
