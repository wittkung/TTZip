// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file CTTZipZipWriteInternal.h
 * @brief Internal data structures and prototypes for multi-core ZIP archive disk writer.
 */

#ifndef CTTZIP_ZIP_WRITE_INTERNAL_H
#define CTTZIP_ZIP_WRITE_INTERNAL_H

#include "CTTZipBridge_ZipWrite.h"
#include "CTTZipCommon.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <stdint.h>
#include <sys/types.h>

typedef struct {
    char src_path[4096];
    char rel_path[4096];
    bool is_directory;
    bool is_mmapped;
    int64_t uncompressed_size;
    int64_t compressed_size;
    uint32_t crc32;
    uint16_t compression_method;
    uint16_t actual_method;
    void* compressed_payload;
    size_t arena_offset;
    size_t arena_cap;
} ttzip_c_item_t;

typedef struct {
    ttzip_c_item_t* items;
    size_t count;
    size_t capacity;
} ttzip_c_item_list_t;

typedef struct {
    size_t start_index;
    size_t count;
    uint64_t total_uncompressed_bytes;
    size_t arena_offset;
    size_t arena_cap;
} ttzip_c_batch_unit_t;

typedef struct {
    ttzip_c_batch_unit_t* units;
    size_t count;
    size_t capacity;
} ttzip_c_batch_list_t;

int ttzip_cluster_small_files_into_batches(
    const ttzip_c_item_list_t* list,
    size_t target_batch_bytes,
    size_t max_files_per_batch,
    ttzip_c_batch_list_t* out_batches
);

int ttzip_write_zip_archive_disk(const char* output_zip_path, ttzip_c_item_list_t* list, bool has_password);

#endif // CTTZIP_ZIP_WRITE_INTERNAL_H
