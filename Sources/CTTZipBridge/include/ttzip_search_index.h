// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#ifndef TTZIP_SEARCH_INDEX_H
#define TTZIP_SEARCH_INDEX_H

#include "ttzip_platform.h"
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    int32_t index;
    uint32_t name_offset;
    uint16_t name_length;
    uint32_t path_offset;
    uint16_t path_length;
    int64_t uncompressed_size;
    bool is_directory;
} ttzip_search_entry_desc_t;

typedef struct {
    const char* query_text;
    size_t query_len;
    bool case_sensitive;
    int64_t min_size_bytes; // -1 to disable
    int64_t max_size_bytes; // -1 to disable
} ttzip_search_query_t;

typedef struct {
    uint8_t* buffer;
    size_t buffer_size;
    size_t buffer_capacity;
    ttzip_search_entry_desc_t* descriptors;
    size_t entry_count;
    size_t entry_capacity;
} ttzip_search_index_t;

/**
 * @brief Initializes a contiguous columnar search index.
 */
TTZIP_API int ttzip_search_index_init(ttzip_search_index_t* index, size_t initial_entries);

/**
 * @brief Deallocates all memory for the search index.
 */
TTZIP_API void ttzip_search_index_free(ttzip_search_index_t* index);

/**
 * @brief Clears entries in index keeping allocated capacities.
 */
TTZIP_API void ttzip_search_index_clear(ttzip_search_index_t* index);

/**
 * @brief Appends an archive entry path to the contiguous search buffer.
 */
TTZIP_API int ttzip_search_index_add_entry(
    ttzip_search_index_t* index,
    int32_t entry_idx,
    const char* path,
    int64_t uncompressed_size,
    bool is_dir
);

/**
 * @brief Executes a search query over the contiguous search index using ARM NEON acceleration.
 * @param index Pointer to populated search index.
 * @param query Pointer to search criteria.
 * @param out_matched_indices Output buffer for matched entry IDs.
 * @param max_matches Maximum capacity of out_matched_indices.
 * @return Number of matched entries.
 */
TTZIP_API size_t ttzip_search_index_query_neon(
    const ttzip_search_index_t* index,
    const ttzip_search_query_t* query,
    int32_t* out_matched_indices,
    size_t max_matches
);

#ifdef __cplusplus
}
#endif

#endif // TTZIP_SEARCH_INDEX_H
