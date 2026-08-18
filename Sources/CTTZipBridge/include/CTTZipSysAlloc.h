// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file CTTZipSysAlloc.h
 * @brief 16KB aligned physical page allocations and APFS file preallocation.
 */

#ifndef CTTZipSysAlloc_h
#define CTTZipSysAlloc_h

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

int ttzip_core_apfs_preallocate_file(int fd, int64_t target_size);
void* ttzip_core_aligned_alloc_16k(size_t size);
void ttzip_core_aligned_free_16k(void* ptr);

#ifdef __cplusplus
}
#endif

#endif /* CTTZipSysAlloc_h */
