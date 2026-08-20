// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#ifndef TTZIP_PATH_FILTER_H
#define TTZIP_PATH_FILTER_H

#include "ttzip_platform.h"
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    const char* const* exclude_patterns;
    size_t exclude_count;
    const char* const* include_patterns;
    size_t include_count;
    bool exclude_vcs;
    bool no_mac_metadata;
    bool case_sensitive;
} ttzip_path_filter_opts_t;

/**
 * @brief Tests if a path matches a POSIX.2 glob pattern with fast prefix/suffix bypass.
 */
TTZIP_API bool ttzip_path_matches(const char* pattern, const char* path, bool case_sensitive);

/**
 * @brief Returns true if path corresponds to VCS directories or files (.git, .svn, etc.).
 */
TTZIP_API bool ttzip_path_is_vcs_metadata(const char* path);

/**
 * @brief Returns true if path corresponds to OS temporary junk (.DS_Store, __MACOSX, ._*, etc.).
 */
TTZIP_API bool ttzip_path_is_mac_metadata(const char* path);

/**
 * @brief Evaluates whether a path should be included based on filter options.
 */
TTZIP_API bool ttzip_path_should_include(const char* path, const ttzip_path_filter_opts_t* opts);

/**
 * @brief Strips count leading path components in-place without dynamic heap allocation.
 * @return Pointer within path string to the remainder, or NULL if path has insufficient components.
 */
TTZIP_API const char* ttzip_path_strip_leading_components(const char* path, size_t count);

#ifdef __cplusplus
}
#endif

#endif // TTZIP_PATH_FILTER_H
