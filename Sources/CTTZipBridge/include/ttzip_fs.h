// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine.

/**
 * @file ttzip_fs.h
 * @brief High-performance cross-platform file system, directory traversal, and memory-mapped I/O.
 * @details Supports POSIX and Win32 (with automatic \\?\ long path support up to 32,768 characters).
 */

#ifndef TTZIP_FS_H
#define TTZIP_FS_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include "ttzip_platform.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    char        path[4096];         /**< Normalized UTF-8 relative path */
    uint64_t    size_bytes;         /**< Uncompressed file size in bytes */
    uint64_t    mtime_epoch_secs;   /**< Modification time in UTC seconds */
    uint32_t    posix_mode;         /**< Standard POSIX permissions (e.g. 0644, 0755) */
    bool        is_directory;       /**< True if entry is a directory */
    bool        is_symlink;         /**< True if entry is a symbolic link */
    char        symlink_target[1024]; /**< UTF-8 target path if symlink */
} ttzip_fs_entry_t;

typedef struct ttzip_dir_iterator ttzip_dir_iterator_t;

/**
 * @brief Opens a directory stream for recursive or flat traversal.
 * @param utf8_root_path Root directory in UTF-8.
 * @return Iterator handle or NULL on failure.
 */
TTZIP_API ttzip_dir_iterator_t* ttzip_fs_opendir(const char* utf8_root_path);

/**
 * @brief Reads the next entry from the directory stream.
 * @param it Iterator handle.
 * @param out_entry Output metadata record.
 * @return 0 on success, 1 on EOF, negative on I/O error.
 */
TTZIP_API int ttzip_fs_readdir(ttzip_dir_iterator_t* it, ttzip_fs_entry_t* out_entry);

/**
 * @brief Closes the directory iterator and frees internal traversal buffers.
 * @param it Iterator handle.
 */
TTZIP_API void ttzip_fs_closedir(ttzip_dir_iterator_t* it);

/**
 * @brief Obtains detailed stat metadata for a single UTF-8 file path.
 * @param utf8_path Target path.
 * @param out_entry Output metadata record.
 * @return 0 on success, negative error code on failure.
 */
TTZIP_API int ttzip_fs_stat(const char* utf8_path, ttzip_fs_entry_t* out_entry);

/**
 * @brief Recursively creates directories along the given UTF-8 path.
 * @param utf8_path Target directory path.
 * @param mode POSIX permission bits (e.g. 0755).
 * @return 0 on success, negative on error.
 */
TTZIP_API int ttzip_fs_mkdir_p(const char* utf8_path, uint32_t mode);

/**
 * @brief Memory-maps a file for ultra-fast sequential read access.
 * @param utf8_path File path to map.
 * @param out_length Receives mapped byte length.
 * @return Pointer to mapped memory or NULL on error.
 */
TTZIP_API const void* ttzip_fs_mmap_read(const char* utf8_path, uint64_t* out_length);

/**
 * @brief Unmaps a previously memory-mapped file buffer.
 * @param ptr Buffer pointer.
 * @param length Mapped byte length.
 */
TTZIP_API void ttzip_fs_munmap(const void* ptr, uint64_t length);

#ifdef __cplusplus
}
#endif

#endif /* TTZIP_FS_H */
