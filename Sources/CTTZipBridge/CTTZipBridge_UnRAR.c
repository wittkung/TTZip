// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/CTTZipBridge_UnRAR.h"
#include "include/CTTZipBridge_Archive.h"
#include "include/CTTZipCommon.h"
#include "include/ttzip_native_archive.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int ttzip_unrar_extract_archive(
    const char* archive_path,
    const char* destination_dir,
    bool skip_mac_junk,
    const char* password
) {
    if (!archive_path || !destination_dir) return TTZIP_ERR_INVALID_PARAM;
    return ttzip_extract_archive_advanced(archive_path, destination_dir, skip_mac_junk, password);
}

static void count_cb(void* ctx, const char* path, int64_t size, bool is_dir) {
    (void)path; (void)size; (void)is_dir;
    int* c = (int*)ctx;
    if (c) (*c)++;
}

int ttzip_unrar_inspect_entry_count(const char* archive_path) {
    if (!archive_path) return -1;
    int count = 0;
    if (ttzip_native_inspect_archive(archive_path, &count, count_cb) == 0) {
        return count;
    }
    return -1;
}
