// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/ttzip_path_filter.h"
#include <string.h>
#include <strings.h>
#include <fnmatch.h>
#include <ctype.h>
#include <stdlib.h>

static const char* g_vcs_names[] = {
    ".git", ".svn", ".hg", ".bzr", "CVS", "_darcs",
    ".gitignore", ".gitmodules", ".gitattributes", ".gitkeep",
    ".hgignore", ".hgtags", ".svnignore", ".bzrignore"
};
static const size_t g_vcs_names_count = sizeof(g_vcs_names) / sizeof(g_vcs_names[0]);

static const char* g_mac_junk[] = {
    ".DS_Store", "__MACOSX", ".Spotlight-V100", ".Trashes",
    ".fseventsd", ".TemporaryItems", ".VolumeIcon.icns",
    "Thumbs.db", "$RECYCLE.BIN", "ehthumbs.db", "Desktop.ini"
};
static const size_t g_mac_junk_count = sizeof(g_mac_junk) / sizeof(g_mac_junk[0]);

static const char* get_last_component(const char* path) {
    if (!path) return "";
    const char* slash = strrchr(path, '/');
    return slash ? (slash + 1) : path;
}

bool ttzip_path_matches(const char* pattern, const char* path, bool case_sensitive) {
    if (!pattern || !path) return false;
    if (pattern[0] == '\0') return path[0] == '\0';
    if (path[0] == '\0') return (pattern[0] == '*' && pattern[1] == '\0');

    // 1. Wildcard short-circuit
    if (pattern[0] == '*' && pattern[1] == '\0') {
        return true;
    }

    // 2. Exact match short-circuit
    if (case_sensitive) {
        if (strcmp(pattern, path) == 0) return true;
    } else {
        if (strcasecmp(pattern, path) == 0) return true;
    }

    // 3. Fast path for suffix patterns (*.ext)
    if (pattern[0] == '*' && pattern[1] == '.' && !strpbrk(pattern + 2, "*?[/\\")) {
        const char* suffix = pattern + 1; // ".ext"
        size_t path_len = strlen(path);
        size_t suff_len = strlen(suffix);
        if (path_len >= suff_len) {
            const char* path_suffix = path + (path_len - suff_len);
            if (case_sensitive) {
                if (strcmp(path_suffix, suffix) == 0) return true;
            } else {
                if (strcasecmp(path_suffix, suffix) == 0) return true;
            }
        }
    }

    int case_flags = case_sensitive ? 0 : FNM_CASEFOLD;

    // 4. Root anchored pattern (e.g. "/build/*")
    if (pattern[0] == '/') {
        const char* p = pattern;
        while (*p == '/') p++;
        const char* q = path;
        while (*q == '/') q++;
        return fnmatch(p, q, FNM_PATHNAME | case_flags) == 0;
    }

    // 5. Hierarchical path pattern (contains '/')
    if (strchr(pattern, '/') != NULL) {
        const char* trimmed_path = path;
        while (*trimmed_path == '/') trimmed_path++;

        if (strncmp(pattern, "**/", 3) == 0) {
            const char* sub_pattern = pattern + 3;
            if (strchr(sub_pattern, '/') == NULL) {
                if (ttzip_path_matches(sub_pattern, path, case_sensitive)) {
                    return true;
                }
            }
        }

        size_t pat_len = strlen(pattern);
        if (pat_len >= 3 && strcmp(pattern + pat_len - 3, "/**") == 0) {
            size_t prefix_len = pat_len - 3;
            const char* prefix = pattern;
            while (*prefix == '/' && prefix_len > 0) {
                prefix++;
                prefix_len--;
            }
            if (strncmp(trimmed_path, prefix, prefix_len) == 0) {
                if (trimmed_path[prefix_len] == '/' || trimmed_path[prefix_len] == '\0') {
                    return true;
                }
            }
        }

        return fnmatch(pattern, trimmed_path, FNM_PATHNAME | case_flags) == 0;
    }

    // 6. Basename and component matching (pattern contains NO slash)
    const char* last_comp = get_last_component(path);
    if (fnmatch(pattern, last_comp, case_flags) == 0) {
        return true;
    }

    // Check each component in path
    const char* cur = path;
    while (*cur) {
        while (*cur == '/') cur++;
        if (!*cur) break;
        const char* slash = strchr(cur, '/');
        size_t clen = slash ? (size_t)(slash - cur) : strlen(cur);
        char comp_buf[256];
        if (clen < sizeof(comp_buf)) {
            memcpy(comp_buf, cur, clen);
            comp_buf[clen] = '\0';
            if (fnmatch(pattern, comp_buf, case_flags) == 0) {
                return true;
            }
        }
        cur += clen;
    }

    return fnmatch(pattern, path, case_flags) == 0;
}

bool ttzip_path_is_vcs_metadata(const char* path) {
    if (!path || path[0] == '\0') return false;

    // Check last component first
    const char* last = get_last_component(path);
    for (size_t i = 0; i < g_vcs_names_count; i++) {
        if (strcasecmp(last, g_vcs_names[i]) == 0) return true;
    }

    // Check every component
    const char* cur = path;
    while (*cur) {
        while (*cur == '/') cur++;
        if (!*cur) break;
        const char* slash = strchr(cur, '/');
        size_t clen = slash ? (size_t)(slash - cur) : strlen(cur);
        for (size_t i = 0; i < g_vcs_names_count; i++) {
            size_t nlen = strlen(g_vcs_names[i]);
            if (clen == nlen && strncasecmp(cur, g_vcs_names[i], clen) == 0) {
                return true;
            }
        }
        cur += clen;
    }

    return false;
}

bool ttzip_path_is_mac_metadata(const char* path) {
    if (!path || path[0] == '\0') return false;

    // Check last component
    const char* last = get_last_component(path);
    if (strncmp(last, "._", 2) == 0) {
        return true;
    }
    for (size_t i = 0; i < g_mac_junk_count; i++) {
        if (strcasecmp(last, g_mac_junk[i]) == 0) return true;
    }

    // Check every component
    const char* cur = path;
    while (*cur) {
        while (*cur == '/') cur++;
        if (!*cur) break;
        const char* slash = strchr(cur, '/');
        size_t clen = slash ? (size_t)(slash - cur) : strlen(cur);

        if (clen >= 2 && cur[0] == '.' && cur[1] == '_') {
            return true;
        }

        for (size_t i = 0; i < g_mac_junk_count; i++) {
            size_t nlen = strlen(g_mac_junk[i]);
            if (clen == nlen && strncasecmp(cur, g_mac_junk[i], clen) == 0) {
                return true;
            }
        }
        cur += clen;
    }

    return false;
}
