// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine.

/**
 * @file ttzip_archive.h
 * @brief Top-level pure C11 archive creation, extraction, listing, and testing interface.
 */

#ifndef TTZIP_ARCHIVE_H
#define TTZIP_ARCHIVE_H

#include "ttzip_platform.h"
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct ttzip_archive_config {
    uint32_t codec; /* 0=Store, 1=Deflate, 2=Zstd, 3=LZMA2, etc. */
    int32_t level;
    uint32_t threads;
    const char *password;
    size_t solid_block_size;
    const char *format_override; /* "zip", "tar", "7z", or NULL (auto by extension) */
} ttzip_archive_config_t;

typedef struct ttzip_archive_entry {
    const char *path;
    uint64_t uncompressed_size;
    uint64_t compressed_size;
    uint32_t crc32;
    bool is_directory;
    bool is_encrypted;
} ttzip_archive_entry_t;

typedef struct ttzip_archive_report {
    uint64_t total_entries;
    uint64_t total_uncompressed_bytes;
    uint64_t total_compressed_bytes;
    uint32_t corrupted_entries;
    bool is_encrypted;
    bool is_solid;
    char detected_format[32];
    double compression_ratio;
} ttzip_archive_report_t;

typedef void (*ttzip_progress_fn)(
    uint64_t bytes_processed,
    uint64_t total_bytes,
    const char *current_file,
    void *user_data
);

typedef void (*ttzip_entry_fn)(
    const ttzip_archive_entry_t *entry,
    void *user_data
);

/**
 * @brief Creates a compressed archive (ZIP / TAR / 7Z) from the specified input paths.
 * @return 0 on success, or negative error code.
 */
TTZIP_API int ttzip_archive_create(
    const ttzip_archive_config_t *config,
    const char *const *input_paths,
    size_t input_count,
    const char *output_archive_path,
    ttzip_progress_fn progress_cb,
    void *user_data
);

/**
 * @brief Extracts all files from an archive into the destination directory.
 * @return 0 on success, or negative error code.
 */
TTZIP_API int ttzip_archive_extract(
    const char *archive_path,
    const char *destination_dir,
    const char *password,
    ttzip_progress_fn progress_cb,
    void *user_data
);

/**
 * @brief Decompresses a single archive entry directly into an in-memory buffer (Zero Disk I/O).
 * @param archive_path Path to the archive.
 * @param entry_index 0-based entry index.
 * @param out_buf Buffer receiving decompressed bytes.
 * @param out_cap Allocated capacity of out_buf.
 * @param out_decomp_size Receives actual decompressed size.
 * @return 0 on success, or negative error code.
 */
TTZIP_API int ttzip_archive_extract_entry_mem(
    const char *archive_path,
    size_t entry_index,
    void *out_buf,
    size_t out_cap,
    size_t *out_decomp_size
);

/**
 * @brief Lists all entries in an archive without extracting.
 * @return 0 on success, or negative error code.
 */
TTZIP_API int ttzip_archive_list(
    const char *archive_path,
    const char *password,
    ttzip_entry_fn entry_cb,
    void *user_data
);

/**
 * @brief Verifies the cryptographic and container CRC integrity of an archive.
 * @return 0 if integrity is 100% valid, or non-zero error code.
 */
TTZIP_API int ttzip_archive_test(
    const char *archive_path,
    const char *password
);

/**
 * @brief Performs comprehensive multicore inspection and returns detailed diagnostics.
 * @return 0 on success, or negative error code.
 */
TTZIP_API int ttzip_archive_inspect(
    const char *archive_path,
    const char *password,
    ttzip_archive_report_t *out_report
);

#ifdef __cplusplus
}
#endif

#endif /* TTZIP_ARCHIVE_H */
