// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file CTTZipIO.h
 * @brief High-performance I/O engine, directory scanner, and write loop abstractions.
 */

#ifndef CTTZIP_IO_H
#define CTTZIP_IO_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>
#include <sys/types.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    char src_path[4096];
    char rel_path[2048];
    uint64_t file_size;
    uint32_t crc32;
    uint32_t mtime;
    bool is_directory;
    uint8_t* payload_buf;
} ttzip_io_entry_t;

typedef struct {
    ttzip_io_entry_t* entries;
    size_t count;
    size_t capacity;
} ttzip_io_file_list_t;

int ttzip_io_collect_recursive(const char* base_path, const char* rel_path, ttzip_io_file_list_t* list);
void ttzip_io_file_list_free(ttzip_io_file_list_t* list);
ssize_t ttzip_io_write_all(int fd, const void* buf, size_t count);
int ttzip_io_apfs_preallocate(int fd, int64_t size);
int ttzip_io_mkdir_p(const char *dir_path);

#ifdef __cplusplus
}
#endif

#endif /* CTTZIP_IO_H */
