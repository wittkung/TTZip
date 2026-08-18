// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file CTTZipBridge_7zStore.h
 * @brief High-speed 7Z store and solid packaging interfaces.
 */

#ifndef CTTZipBridge_7zStore_h
#define CTTZipBridge_7zStore_h

#include "CTTZipBridge.h"
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

int ttzip_create_7z_store_fast_c(
    const char* output_path,
    const char* const* input_paths,
    size_t input_count
);

int ttzip_create_7z_solid_fast_c(
    const char* output_path,
    const char* const* input_paths,
    size_t input_count,
    int level
);

#ifdef __cplusplus
}
#endif

#endif // CTTZipBridge_7zStore_h
