// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine.

#include "include/ttzip_archive_tree.h"
#include "include/ttzip_strnatcmp.h"
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

static ttzip_tree_node_t *node_create(const char *name, const char *full_path, bool is_dir) {
    ttzip_tree_node_t *node = (ttzip_tree_node_t *)calloc(1, sizeof(ttzip_tree_node_t));
    if (!node) return NULL;
    if (name) strncpy(node->name, name, sizeof(node->name) - 1);
    if (full_path) strncpy(node->full_path, full_path, sizeof(node->full_path) - 1);
    node->is_directory = is_dir;
    return node;
}

static void node_destroy(ttzip_tree_node_t *node) {
    if (!node) return;
    for (size_t i = 0; i < node->child_count; i++) {
        node_destroy(node->children[i]);
    }
    if (node->children) free(node->children);
    free(node);
}

ttzip_tree_t *ttzip_tree_create(void) {
    ttzip_tree_t *tree = (ttzip_tree_t *)calloc(1, sizeof(ttzip_tree_t));
    if (!tree) return NULL;
    tree->root = node_create("", "", true);
    return tree;
}

static ttzip_tree_node_t *find_or_add_child(ttzip_tree_node_t *parent, const char *name, const char *accum_path, bool is_dir) {
    for (size_t i = 0; i < parent->child_count; i++) {
        if (strcmp(parent->children[i]->name, name) == 0) {
            return parent->children[i];
        }
    }
    ttzip_tree_node_t *child = node_create(name, accum_path, is_dir);
    if (!child) return NULL;

    ttzip_tree_node_t **new_children = (ttzip_tree_node_t **)realloc(
        parent->children, sizeof(ttzip_tree_node_t *) * (parent->child_count + 1)
    );
    if (!new_children) {
        node_destroy(child);
        return NULL;
    }
    parent->children = new_children;
    parent->children[parent->child_count++] = child;
    return child;
}

int ttzip_tree_insert(
    ttzip_tree_t *tree,
    const char *path,
    uint64_t uncompressed_size,
    uint64_t compressed_size,
    uint32_t crc32,
    bool is_directory
) {
    if (!tree || !path || !tree->root) return -1;

    char path_buf[1024];
    strncpy(path_buf, path, sizeof(path_buf) - 1);
    path_buf[sizeof(path_buf) - 1] = '\0';

    ttzip_tree_node_t *curr = tree->root;
    char accum[1024] = "";
    char *token = strtok(path_buf, "/\\");
    char *next_token = NULL;

    while (token) {
        next_token = strtok(NULL, "/\\");
        if (accum[0] != '\0') strncat(accum, "/", sizeof(accum) - strlen(accum) - 1);
        strncat(accum, token, sizeof(accum) - strlen(accum) - 1);

        bool is_leaf = (next_token == NULL);
        bool seg_is_dir = is_leaf ? is_directory : true;

        curr = find_or_add_child(curr, token, accum, seg_is_dir);
        if (!curr) return -1;

        if (is_leaf) {
            curr->uncompressed_size = uncompressed_size;
            curr->compressed_size = compressed_size;
            curr->crc32 = crc32;
            curr->is_directory = is_directory;
        }

        token = next_token;
    }

    if (is_directory) tree->total_folders++;
    else tree->total_files++;

    tree->total_uncompressed_bytes += uncompressed_size;
    tree->total_compressed_bytes += compressed_size;

    return 0;
}

static char *str_casestr(const char *haystack, const char *needle) {
    if (!haystack || !needle) return NULL;
    if (!*needle) return (char *)haystack;

    for (; *haystack; haystack++) {
        if (tolower((unsigned char)*haystack) == tolower((unsigned char)*needle)) {
            const char *h = haystack;
            const char *n = needle;
            while (*h && *n && tolower((unsigned char)*h) == tolower((unsigned char)*n)) {
                h++;
                n++;
            }
            if (!*n) return (char *)haystack;
        }
    }
    return NULL;
}

static void search_recursive(
    const ttzip_tree_node_t *node,
    const char *query,
    const char **out_matched,
    size_t *match_count,
    size_t max_results
) {
    if (!node || *match_count >= max_results) return;

    if (node->full_path[0] != '\0' && str_casestr(node->name, query)) {
        out_matched[*match_count] = node->full_path;
        (*match_count)++;
    }

    for (size_t i = 0; i < node->child_count && *match_count < max_results; i++) {
        search_recursive(node->children[i], query, out_matched, match_count, max_results);
    }
}

size_t ttzip_tree_search(
    const ttzip_tree_t *tree,
    const char *query,
    const char **out_matched_paths,
    size_t max_results
) {
    if (!tree || !tree->root || !query || !out_matched_paths || max_results == 0) return 0;
    size_t match_count = 0;
    search_recursive(tree->root, query, out_matched_paths, &match_count, max_results);
    return match_count;
}

void ttzip_tree_destroy(ttzip_tree_t *tree) {
    if (!tree) return;
    if (tree->root) node_destroy(tree->root);
    free(tree);
}
