// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/CTTZipCommon.h"

#if defined(__APPLE__)
#include <sys/mount.h>
#endif

static ttzip_log_handler_t g_log_handler = NULL;

void ttzip_set_log_handler(ttzip_log_handler_t handler) {
    g_log_handler = handler;
}

void ttzip_set_log_callback(ttzip_log_handler_t cb) {
    g_log_handler = cb;
}

void ttzip_log(int level, const char* fmt, ...) {
    if (!g_log_handler) return;
    char buf[2048];
    va_list args;
    va_start(args, fmt);
    vsnprintf(buf, sizeof(buf), fmt, args);
    va_end(args);
    g_log_handler(level, buf);
}

void ttzip_log_c(int level, const char* fmt, ...) {
    if (!g_log_handler) return;
    char buf[2048];
    va_list args;
    va_start(args, fmt);
    vsnprintf(buf, sizeof(buf), fmt, args);
    va_end(args);
    g_log_handler(level, buf);
}

int ttzip_common_mkdir_p(const char* dir) {
    if (!dir || dir[0] == '\0') return -1;
    char tmp[4096];
    if (strlen(dir) >= sizeof(tmp)) return -ENAMETOOLONG;
    
    snprintf(tmp, sizeof(tmp), "%s", dir);
    size_t len = strlen(tmp);
    if (len == 0) return 0;
    while (len > 0 && tmp[len - 1] == '/') {
        tmp[len - 1] = 0;
        len--;
    }
    if (len == 0) return 0;
    
    for (char* p = tmp + 1; *p; p++) {
        if (*p == '/') {
            *p = 0;
            if (mkdir(tmp, 0755) != 0 && errno != EEXIST) {
                // Directory creation or already exists
            }
            *p = '/';
        }
    }
    if (mkdir(tmp, 0755) != 0 && errno != EEXIST) {
        return -1;
    }
    return 0;
}

int ttzip_common_join_path(char* dst, size_t dst_size, const char* base, const char* rel) {
    if (!dst || dst_size == 0 || !base || !rel) return TTZIP_ERR_INVALID_PARAM;
    
    while (*rel == '/' || (rel[0] == '.' && rel[1] == '/')) {
        rel++;
    }
    if (strlen(rel) == 0) return TTZIP_ERR_INVALID_PARAM;
    
    if (strstr(rel, "../") != NULL || strstr(rel, "..\\") != NULL || strcmp(rel, "..") == 0 ||
        strstr(rel, "/..") != NULL || strstr(rel, "\\..") != NULL) {
        return TTZIP_ERR_SECURITY_VIOLATION;
    }
    
    char clean_rel[4096];
    strncpy(clean_rel, rel, sizeof(clean_rel) - 1);
    clean_rel[sizeof(clean_rel) - 1] = '\0';
    size_t cr_len = strlen(clean_rel);
    while (cr_len > 0 && clean_rel[cr_len - 1] == '/') {
        clean_rel[cr_len - 1] = '\0';
        cr_len--;
    }
    
    int written = snprintf(dst, dst_size, "%s/%s", base, clean_rel);
    if (written < 0 || (size_t)written >= dst_size) {
        return TTZIP_ERR_PATH_TOO_LONG;
    }
    return TTZIP_OK;
}

static bool g_ttzip_enable_apfs_zero_copy = true;

void ttzip_set_enable_apfs_zero_copy(bool enable) {
    g_ttzip_enable_apfs_zero_copy = enable;
}

bool ttzip_get_enable_apfs_zero_copy(void) {
    return g_ttzip_enable_apfs_zero_copy;
}

int ttzip_core_apfs_preallocate_file(int fd, int64_t target_size);

int ttzip_common_apfs_preallocate(int fd, int64_t size) {
    return ttzip_core_apfs_preallocate_file(fd, size);
}
