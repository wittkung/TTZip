// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file CTTZipBridge_Mmap.h
 * @brief Memory-mapped fast ZIP central directory inspection interface.
 */

#ifndef CTTZipBridge_Mmap_h
#define CTTZipBridge_Mmap_h

#include "CTTZipBridge.h"
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

int ttzip_mmap_zip_inspect(const char* archive_path, void* context, ttzip_entry_callback callback);

#ifdef __cplusplus
}
#endif

#endif // CTTZipBridge_Mmap_h
