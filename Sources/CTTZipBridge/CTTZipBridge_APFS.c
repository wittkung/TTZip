// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/CTTZipBridge_APFS.h"
#include "include/CTTZipBridge.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#if defined(__APPLE__)
#include <copyfile.h>
#endif

#include <fcntl.h>

int ttzip_apfs_preallocate(int fd, int64_t target_size) {
    if (fd < 0 || target_size <= 0) return -1;
#if defined(__APPLE__)
    fstore_t fst;
    memset(&fst, 0, sizeof(fst));
    fst.fst_flags = F_ALLOCATECONTIG | F_ALLOCATEALL;
    fst.fst_posmode = F_PEOFPOSMODE;
    fst.fst_offset = 0;
    fst.fst_length = target_size;
    fst.fst_bytesalloc = 0;
    if (fcntl(fd, F_PREALLOCATE, &fst) == 0) {
        return 0;
    }
    // Fallback: If contiguous allocation fails due to fragmentation, retry non-contiguous allocation
    fst.fst_flags = F_ALLOCATEALL;
    if (fcntl(fd, F_PREALLOCATE, &fst) == 0) {
        return 0;
    }
#endif
    return ftruncate(fd, target_size);
}

int ttzip_stat_file_info(const char* path, uint64_t* out_size, uint32_t* out_mode, uint64_t* out_mtime) {
    if (!path) return -1;
    struct stat st;
    if (lstat(path, &st) != 0) return -2;
    if (out_size) *out_size = (uint64_t)st.st_size;
    if (out_mode) *out_mode = (uint32_t)st.st_mode;
    if (out_mtime) *out_mtime = (uint64_t)st.st_mtime;
    return 0;
}

int ttzip_remove_path_fast(const char* path) {
    if (!path) return -1;
    struct stat st;
    if (lstat(path, &st) != 0) return -2;
    if (S_ISDIR(st.st_mode)) {
        return rmdir(path);
    }
    return unlink(path);
}

int ttzip_apfs_clone_range(int in_fd, int64_t in_offset, int out_fd, int64_t out_offset, uint64_t count) {
    if (!ttzip_get_enable_apfs_zero_copy()) return -1;
    if (in_fd < 0 || out_fd < 0 || count == 0) return -1;
    if (in_offset != 0 || out_offset != 0) return -1;
#if defined(__APPLE__)
    int ret = fcopyfile(in_fd, out_fd, NULL, COPYFILE_DATA | COPYFILE_CLONE);
    if (ret == 0) {
        return 0;
    }
#endif
    return -1;
}

bool ttzip_is_mac_junk(const char* path) {
    if (!path) return false;
    if (strstr(path, ".DS_Store") || strstr(path, "__MACOSX") || strstr(path, "Thumbs.db") || strstr(path, ".Spotlight-V100") || strstr(path, ".Trashes")) {
        return true;
    }
    const char* filename = strrchr(path, '/');
    filename = filename ? filename + 1 : path;
    if (filename[0] == '.' && filename[1] == '_') {
        return true;
    }
    return false;
}
