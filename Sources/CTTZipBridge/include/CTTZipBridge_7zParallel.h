// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file CTTZipBridge_7zParallel.h
 * @brief Multi-threaded 7Z extraction interface.
 */

#ifndef CTTZipBridge_7zParallel_h
#define CTTZipBridge_7zParallel_h

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

int ttzip_7z_extract_parallel_c(
    const char* archive_path,
    const char* destination_dir,
    const char* password
);

#ifdef __cplusplus
}
#endif

#endif // CTTZipBridge_7zParallel_h
