// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/ttzip_search_index.h"
#include <string.h>
#include <strings.h>
#include <stdlib.h>
#include <ctype.h>

#if defined(__ARM_NEON) || defined(__ARM_NEON__)
#include <arm_neon.h>
#define TTZIP_HAS_NEON 1
#else
#define TTZIP_HAS_NEON 0
#endif

int ttzip_search_index_init(ttzip_search_index_t* index, size_t initial_entries) {
    if (!index) return -1;
    memset(index, 0, sizeof(*index));

    size_t initial_cap = initial_entries > 0 ? initial_entries : 256;
    index->descriptors = (ttzip_search_entry_desc_t*)malloc(initial_cap * sizeof(ttzip_search_entry_desc_t));
    if (!index->descriptors) return -1;
    index->entry_capacity = initial_cap;
    index->entry_count = 0;

    size_t init_buf_cap = initial_cap * 64;
    index->buffer = (uint8_t*)malloc(init_buf_cap);
    if (!index->buffer) {
        free(index->descriptors);
        index->descriptors = NULL;
        return -1;
    }
    index->buffer_capacity = init_buf_cap;
    index->buffer_size = 0;

    return 0;
}

void ttzip_search_index_free(ttzip_search_index_t* index) {
    if (!index) return;
    if (index->buffer) {
        free(index->buffer);
        index->buffer = NULL;
    }
    if (index->descriptors) {
        free(index->descriptors);
        index->descriptors = NULL;
    }
    index->buffer_size = 0;
    index->buffer_capacity = 0;
    index->entry_count = 0;
    index->entry_capacity = 0;
}

void ttzip_search_index_clear(ttzip_search_index_t* index) {
    if (!index) return;
    index->buffer_size = 0;
    index->entry_count = 0;
}

int ttzip_search_index_add_entry(
    ttzip_search_index_t* index,
    int32_t entry_idx,
    const char* path,
    int64_t uncompressed_size,
    bool is_dir
) {
    if (!index || !path) return -1;

    size_t path_len = strlen(path);
    const char* name = strrchr(path, '/');
    name = name ? (name + 1) : path;
    size_t name_len = strlen(name);

    // Expand descriptors if needed
    if (index->entry_count >= index->entry_capacity) {
        size_t new_cap = (index->entry_capacity * 2) + 64;
        ttzip_search_entry_desc_t* new_descs = (ttzip_search_entry_desc_t*)realloc(
            index->descriptors,
            new_cap * sizeof(ttzip_search_entry_desc_t)
        );
        if (!new_descs) return -1;
        index->descriptors = new_descs;
        index->entry_capacity = new_cap;
    }

    // Expand buffer if needed
    size_t needed_bytes = path_len + 1 + name_len + 1;
    if (index->buffer_size + needed_bytes > index->buffer_capacity) {
        size_t new_buf_cap = (index->buffer_capacity * 2) + needed_bytes + 1024;
        uint8_t* new_buf = (uint8_t*)realloc(index->buffer, new_buf_cap);
        if (!new_buf) return -1;
        index->buffer = new_buf;
        index->buffer_capacity = new_buf_cap;
    }

    // Append normalized lowercase path
    uint32_t p_offset = (uint32_t)index->buffer_size;
    for (size_t i = 0; i < path_len; i++) {
        index->buffer[index->buffer_size++] = (uint8_t)tolower((unsigned char)path[i]);
    }
    index->buffer[index->buffer_size++] = 0; // null-terminate

    // Append normalized lowercase name
    uint32_t n_offset = (uint32_t)index->buffer_size;
    for (size_t i = 0; i < name_len; i++) {
        index->buffer[index->buffer_size++] = (uint8_t)tolower((unsigned char)name[i]);
    }
    index->buffer[index->buffer_size++] = 0;

    ttzip_search_entry_desc_t* desc = &index->descriptors[index->entry_count++];
    desc->index = entry_idx;
    desc->name_offset = n_offset;
    desc->name_length = (uint16_t)name_len;
    desc->path_offset = p_offset;
    desc->path_length = (uint16_t)path_len;
    desc->uncompressed_size = uncompressed_size;
    desc->is_directory = is_dir;

    return 0;
}

size_t ttzip_search_index_query_neon(
    const ttzip_search_index_t* index,
    const ttzip_search_query_t* query,
    int32_t* out_matched_indices,
    size_t max_matches
) {
    if (!index || !query || !out_matched_indices || max_matches == 0) return 0;
    if (index->entry_count == 0 || !index->buffer || !index->descriptors) return 0;

    size_t query_len = query->query_text ? strlen(query->query_text) : 0;
    char lower_query[256];
    if (query_len > 0 && query_len < sizeof(lower_query)) {
        for (size_t i = 0; i < query_len; i++) {
            lower_query[i] = (char)tolower((unsigned char)query->query_text[i]);
        }
        lower_query[query_len] = '\0';
    } else if (query_len > 0) {
        return 0; // Query exceeds search bounds
    }

    size_t matched = 0;

    for (size_t i = 0; i < index->entry_count && matched < max_matches; i++) {
        const ttzip_search_entry_desc_t* desc = &index->descriptors[i];

        // Size filter
        if (query->min_size_bytes >= 0 && desc->uncompressed_size < query->min_size_bytes) {
            continue;
        }
        if (query->max_size_bytes >= 0 && desc->uncompressed_size > query->max_size_bytes) {
            continue;
        }

        // Empty query matches all
        if (query_len == 0) {
            out_matched_indices[matched++] = desc->index;
            continue;
        }

        const char* name_ptr = (const char*)(index->buffer + desc->name_offset);
        const char* path_ptr = (const char*)(index->buffer + desc->path_offset);

        // Fast substring match in name first, then in path
        if (strstr(name_ptr, lower_query) != NULL || strstr(path_ptr, lower_query) != NULL) {
            out_matched_indices[matched++] = desc->index;
        }
    }

    return matched;
}
