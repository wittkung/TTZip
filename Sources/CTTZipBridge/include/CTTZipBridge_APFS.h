// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file CTTZipBridge_APFS.h
 * @brief APFS file system primitives (preallocation, clonefile, stat, fast unlink).
 */

#ifndef CTTZipBridge_APFS_h
#define CTTZipBridge_APFS_h

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

int ttzip_apfs_preallocate(int fd, int64_t target_size);
int ttzip_stat_file_info(const char* path, uint64_t* out_size, uint32_t* out_mode, uint64_t* out_mtime);
int ttzip_remove_path_fast(const char* path);
int ttzip_apfs_clone_range(int in_fd, int64_t in_offset, int out_fd, int64_t out_offset, uint64_t count);
bool ttzip_is_mac_junk(const char* path);

#ifdef __cplusplus
}
#endif

#endif // CTTZipBridge_APFS_h
