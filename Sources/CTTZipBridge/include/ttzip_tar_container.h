// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine.

/**
 * @file ttzip_tar_container.h
 * @brief Pure C11 high-speed POSIX UStar and PAX TAR container framing.
 */

#ifndef TTZIP_TAR_CONTAINER_H
#define TTZIP_TAR_CONTAINER_H

#include "ttzip_platform.h"
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

#define TTZIP_TAR_BLOCK_SIZE 512

typedef struct ttzip_tar_entry_meta {
    const char *path;
    uint64_t file_size;
    uint32_t mode;
    uint32_t mtime;
    uint32_t uid;
    uint32_t gid;
    const char *uname;
    const char *gname;
    bool is_directory;
} ttzip_tar_entry_meta_t;

/**
 * @brief Formats and serializes a 512-byte POSIX UStar header block into dst_block.
 * @param meta Entry metadata.
 * @param dst_block 512-byte pre-allocated buffer.
 * @return TTZIP_TAR_BLOCK_SIZE (512) on success, or 0 on failure.
 */
TTZIP_API size_t ttzip_tar_write_header(
    const ttzip_tar_entry_meta_t *meta,
    uint8_t dst_block[TTZIP_TAR_BLOCK_SIZE]
);

/**
 * @brief Serializes the 1024-byte double zero-block trailer ending a standard TAR stream.
 * @param dst_trailer 1024-byte pre-allocated buffer.
 * @return 1024.
 */
TTZIP_API size_t ttzip_tar_write_trailer(
    uint8_t dst_trailer[1024]
);

#ifdef __cplusplus
}
#endif

#endif /* TTZIP_TAR_CONTAINER_H */
