// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/CTTZipSysAlloc.h"
#include "include/CTTZipCommon.h"
#include "include/ttzip_platform.h"

#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>

#if defined(__APPLE__)
#include <sys/mount.h>
#endif

int ttzip_core_apfs_preallocate_file(int fd, int64_t target_size) {
    if (fd < 0 || target_size <= 0) return -1;
    if (!ttzip_get_enable_apfs_zero_copy()) {
        return ftruncate(fd, (off_t)target_size);
    }
#if defined(__APPLE__) && defined(F_PREALLOCATE)
    fstore_t fst;
    fst.fst_flags = F_ALLOCATECONTIG | F_ALLOCATEALL;
    fst.fst_posmode = F_PEOFPOSMODE;
    fst.fst_offset = 0;
    fst.fst_length = target_size;
    fst.fst_bytesalloc = 0;
    if (fcntl(fd, F_PREALLOCATE, &fst) == -1) {
        fst.fst_flags = F_ALLOCATEALL;
        fcntl(fd, F_PREALLOCATE, &fst);
    }
    return ftruncate(fd, (off_t)target_size);
#else
    return ftruncate(fd, (off_t)target_size);
#endif
}

void* ttzip_core_aligned_alloc_16k(size_t size) {
    if (size == 0) return NULL;
    return ttzip_platform_aligned_alloc(16384, size);
}

void ttzip_core_aligned_free_16k(void* ptr) {
    if (ptr) {
        ttzip_platform_aligned_free(ptr);
    }
}
