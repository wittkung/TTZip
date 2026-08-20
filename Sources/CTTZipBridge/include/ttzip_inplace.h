// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine.

/**
 * @file ttzip_inplace.h
 * @brief High-speed in-place archive entry mutation and fast appending without full archive rewrite.
 */

#ifndef TTZIP_INPLACE_H
#define TTZIP_INPLACE_H

#include "ttzip_platform.h"
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Appends a new file into an existing ZIP archive in-place without rewriting existing entries.
 * @param archive_path Path to the existing ZIP archive.
 * @param new_file_path Path to the file to append.
 * @param entry_name Name of the entry inside the archive (or NULL for basename).
 * @return 0 on success, or negative error code.
 */
TTZIP_API int ttzip_inplace_append_file(
    const char *archive_path,
    const char *new_file_path,
    const char *entry_name
);

#ifdef __cplusplus
}
#endif

#endif /* TTZIP_INPLACE_H */
