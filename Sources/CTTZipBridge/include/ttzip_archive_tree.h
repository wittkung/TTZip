// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine.

/**
 * @file ttzip_archive_tree.h
 * @brief High-speed C11 in-memory Archive Tree structure and fast search filtering.
 */

#ifndef TTZIP_ARCHIVE_TREE_H
#define TTZIP_ARCHIVE_TREE_H

#include "ttzip_platform.h"
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct ttzip_tree_node {
    char name[256];
    char full_path[1024];
    uint64_t uncompressed_size;
    uint64_t compressed_size;
    uint32_t crc32;
    bool is_directory;
    size_t child_count;
    struct ttzip_tree_node **children;
} ttzip_tree_node_t;

typedef struct ttzip_tree {
    ttzip_tree_node_t *root;
    size_t total_files;
    size_t total_folders;
    uint64_t total_uncompressed_bytes;
    uint64_t total_compressed_bytes;
} ttzip_tree_t;

/**
 * @brief Creates an empty in-memory archive tree.
 */
TTZIP_API ttzip_tree_t *ttzip_tree_create(void);

/**
 * @brief Inserts a path entry into the tree hierarchy (splitting on '/').
 */
TTZIP_API int ttzip_tree_insert(
    ttzip_tree_t *tree,
    const char *path,
    uint64_t uncompressed_size,
    uint64_t compressed_size,
    uint32_t crc32,
    bool is_directory
);

/**
 * @brief Performs fast case-insensitive search across tree paths.
 * @param query Substring search query.
 * @param out_matched_paths Array of pointers receiving matched paths.
 * @param max_results Maximum results capacity.
 * @return Number of matching paths found.
 */
TTZIP_API size_t ttzip_tree_search(
    const ttzip_tree_t *tree,
    const char *query,
    const char **out_matched_paths,
    size_t max_results
);

/**
 * @brief Frees the entire tree memory pool.
 */
TTZIP_API void ttzip_tree_destroy(ttzip_tree_t *tree);

#ifdef __cplusplus
}
#endif

#endif /* TTZIP_ARCHIVE_TREE_H */
