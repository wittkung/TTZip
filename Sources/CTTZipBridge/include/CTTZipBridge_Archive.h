// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file CTTZipBridge_Archive.h
 * @brief Generic archive inspection, extraction, creation, and SIMD utility interfaces.
 */

#ifndef CTTZipBridge_Archive_h
#define CTTZipBridge_Archive_h

#include "CTTZipBridge.h"
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

int ttzip_inspect_archive(const char* archive_path, void* context, ttzip_entry_callback callback);
int ttzip_extract_archive_advanced(const char* archive_path, const char* destination_dir, bool skip_mac_junk, const char* password);
int ttzip_extract_archive(const char* archive_path, const char* destination_dir);
int ttzip_extract_7z_libarchive_c(const char* archive_path, const char* dest_dir, const char* password);

int ttzip_stream_archive_entries_to_fd(
    const char* archive_path,
    const char* const* entry_patterns,
    size_t pattern_count,
    int target_fd,
    const char* password,
    bool force_binary,
    char* err_buf,
    size_t err_len
);

int ttzip_create_archive_tuned(
    const char* output_archive_path,
    const char* format,
    const char* const* input_paths,
    size_t input_count,
    bool skip_mac_junk,
    int zstd_level,
    int zstd_long_window_log,
    int cpu_threads,
    const char* password
);

int ttzip_create_archive_advanced(
    const char* output_archive_path,
    const char* format,
    const char* const* input_paths,
    size_t input_count,
    bool skip_mac_junk
);

int ttzip_create_archive(
    const char* output_archive_path,
    const char* format,
    const char* const* input_paths,
    size_t input_count
);

void* ttzip_aligned_alloc_16k(size_t size);
void ttzip_aligned_free_16k(void* ptr);

char* ttzip_detect_charset(const char* bytes, size_t length);
uint32_t ttzip_compute_buffer_crc32(const void* buf, size_t len);
uint32_t ttzip_compute_buffer_crc32_neon(uint32_t initial_crc, const void* buf, size_t len);
void ttzip_neon_memcpy_64b(void* dst, const void* src, size_t len);
uint32_t ttzip_compute_file_crc32(const char* file_path);
double ttzip_estimate_buffer_entropy(const void* buf, size_t len);
bool ttzip_is_ascii_fast(const void* buf, size_t len);

#ifdef __cplusplus
}
#endif

#endif /* CTTZipBridge_Archive_h */
