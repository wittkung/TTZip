// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/CTTZipBridge_Archive.h"
#include "include/CTTZipBridge.h"
#include "include/CTTZipCommon.h"
#include "include/CTTZipCoreArchitecture.h"
#include "include/ttzip_native_archive.h"
#include "include/CTTZipGzParallel.h"
#include "include/CTTZipBridge_APFS.h"
#include "include/CTTZipBridge_ZipWrite.h"
#include "include/CTTZipBridge_Zstd.h"
#include "include/CTTZipUtils.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <locale.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>
#include <libgen.h>
#include <dirent.h>
#include <stdbool.h>

int ttzip_core_posix_spawn_fast(
    const char* bin_path,
    const char* const* argv,
    const char* working_dir
);

static void split_input_path(const char* input_dir, char* dir_path, size_t dir_len, char* file_name, size_t file_len) {
    strncpy(dir_path, input_dir, dir_len);
    dir_path[dir_len - 1] = '\0';
    
    char* last_slash = strrchr(dir_path, '/');
    if (last_slash) {
        *last_slash = '\0';
        strncpy(file_name, last_slash + 1, file_len);
    } else {
        strncpy(file_name, input_dir, file_len);
        strncpy(dir_path, ".", dir_len);
    }
    file_name[file_len - 1] = '\0';
    dir_path[dir_len - 1] = '\0';
}

int ttzip_inspect_archive_advanced(
    const char* archive_path,
    const char* password,
    void* context,
    ttzip_entry_callback callback
) {
    if (!archive_path || !callback) return TTZIP_ERR_INVALID_PARAM;
    setlocale(LC_ALL, "en_US.UTF-8");
    
    // Fast path: try native zero-copy mmap parser first
    int fast_res = ttzip_native_inspect_archive(archive_path, context, (ttzip_native_entry_cb)callback);
    if (fast_res == 0) return 0;
    
    // Libarchive in-process inspection with full format & passphrase support
    struct archive* a = archive_read_new();
    if (!a) return TTZIP_ERR_OUT_OF_MEMORY;
    
    archive_read_support_format_all(a);
    archive_read_support_filter_all(a);
    
    if (password && password[0] != '\0') {
        archive_read_add_passphrase(a, password);
    }
    
    if (archive_read_open_filename(a, archive_path, 10240) != ARCHIVE_OK) {
        archive_read_free(a);
        return TTZIP_ERR_OPEN_FAILED;
    }
    
    struct archive_entry* entry;
    int r;
    int entry_count = 0;
    while ((r = archive_read_next_header(a, &entry)) == ARCHIVE_OK) {
        const char* pathname = archive_entry_pathname(entry);
        if (!pathname || pathname[0] == '\0') continue;
        
        int64_t size = archive_entry_size(entry);
        mode_t mode = archive_entry_filetype(entry);
        bool is_dir = S_ISDIR(mode) || (pathname[strlen(pathname) - 1] == '/');
        
        callback(context, pathname, size, is_dir);
        entry_count++;
        archive_read_data_skip(a);
    }
    
    archive_read_close(a);
    archive_read_free(a);
    return (entry_count > 0 || r == ARCHIVE_EOF) ? TTZIP_OK : -1;
}

int ttzip_inspect_archive(const char* archive_path, void* context, ttzip_entry_callback callback) {
    return ttzip_inspect_archive_advanced(archive_path, NULL, context, callback);
}

int ttzip_inspect_archive_v2(
    const char* archive_path,
    const char* password,
    void* context,
    ttzip_entry_callback_v2 callback
) {
    if (!archive_path || !callback) return TTZIP_ERR_INVALID_PARAM;
    setlocale(LC_ALL, "en_US.UTF-8");
    
    struct archive* a = archive_read_new();
    if (!a) return TTZIP_ERR_OUT_OF_MEMORY;
    
    archive_read_support_format_all(a);
    archive_read_support_filter_all(a);
    
    if (password && password[0] != '\0') {
        archive_read_add_passphrase(a, password);
    }
    
    if (archive_read_open_filename(a, archive_path, 10240) != ARCHIVE_OK) {
        archive_read_free(a);
        return TTZIP_ERR_OPEN_FAILED;
    }
    
    struct archive_entry* entry;
    int r;
    int entry_count = 0;
    while ((r = archive_read_next_header(a, &entry)) == ARCHIVE_OK) {
        const char* pathname = archive_entry_pathname(entry);
        if (!pathname || pathname[0] == '\0') continue;
        
        int64_t size = archive_entry_size(entry);
        mode_t mode = archive_entry_filetype(entry);
        bool is_dir = S_ISDIR(mode) || (pathname[strlen(pathname) - 1] == '/');
        
        int is_data_enc = archive_entry_is_data_encrypted(entry);
        int is_meta_enc = archive_entry_is_metadata_encrypted(entry);
        
        callback(context, pathname, size, is_dir, is_data_enc == 1, is_meta_enc == 1);
        entry_count++;
        archive_read_data_skip(a);
    }
    
    archive_read_close(a);
    archive_read_free(a);
    return (entry_count > 0 || r == ARCHIVE_EOF) ? TTZIP_OK : -1;
}

int ttzip_extract_archive_advanced(
    const char* archive_path,
    const char* destination_dir,
    bool skip_mac_junk,
    const char* password
) {
    if (!archive_path || !destination_dir) return TTZIP_ERR_INVALID_PARAM;
    
    // Fast path: Try hardware-accelerated / SIMD native C engines first
    int res = ttzip_native_extract_archive(archive_path, destination_dir, skip_mac_junk, password);
    if (res == TTZIP_OK) {
        return TTZIP_OK;
    }
    
    // Universal Robust In-Process Fallback via libarchive engine
    struct archive* a = archive_read_new();
    if (!a) return TTZIP_ERR_OUT_OF_MEMORY;
    
    struct archive* ext = archive_write_disk_new();
    if (!ext) {
        archive_read_free(a);
        return TTZIP_ERR_OUT_OF_MEMORY;
    }
    
    archive_read_support_format_all(a);
    archive_read_support_filter_all(a);
    archive_write_disk_set_options(ext,
        ARCHIVE_EXTRACT_TIME |
        ARCHIVE_EXTRACT_PERM |
        ARCHIVE_EXTRACT_SECURE_NODOTDOT |
        ARCHIVE_EXTRACT_UNLINK
    );

    if (password && password[0] != '\0') {
        archive_read_add_passphrase(a, password);
    }
    
    if (archive_read_open_filename(a, archive_path, 65536) != ARCHIVE_OK) {
        archive_write_free(ext);
        archive_read_free(a);
        return TTZIP_ERR_OPEN_FAILED;
    }
    
    ttzip_common_mkdir_p(destination_dir);
    
    struct archive_entry* entry;
    int r;
    int entry_count = 0;
    int success_count = 0;
    while ((r = archive_read_next_header(a, &entry)) == ARCHIVE_OK) {
        const char* pathname = archive_entry_pathname(entry);
        if (!pathname || pathname[0] == '\0') continue;
        entry_count++;
        
        if (skip_mac_junk) {
            const char* last_slash = strrchr(pathname, '/');
            const char* fname = last_slash ? last_slash + 1 : pathname;
            if (strncmp(fname, "._", 2) == 0 || strcmp(fname, ".DS_Store") == 0 || strcmp(fname, "__MACOSX") == 0) {
                archive_read_data_skip(a);
                continue;
            }
        }
        
        char full_dest[4096];
        if (ttzip_common_join_path(full_dest, sizeof(full_dest), destination_dir, pathname) != TTZIP_OK) {
            archive_read_data_skip(a);
            continue;
        }
        
        char parent_dir[4096];
        strncpy(parent_dir, full_dest, sizeof(parent_dir) - 1);
        parent_dir[sizeof(parent_dir) - 1] = '\0';
        char* last_slash_p = strrchr(parent_dir, '/');
        if (last_slash_p && last_slash_p != parent_dir) {
            *last_slash_p = '\0';
            ttzip_common_mkdir_p(parent_dir);
        }
        
        archive_entry_set_pathname(entry, full_dest);
        
        int r_write = archive_write_header(ext, entry);
        if (r_write >= ARCHIVE_WARN) {
            const void* buff;
            size_t size;
            int64_t offset;
            int data_err = 0;
            int r_block = ARCHIVE_OK;
            while ((r_block = archive_read_data_block(a, &buff, &size, &offset)) == ARCHIVE_OK) {
                if (archive_write_data_block(ext, buff, size, offset) < ARCHIVE_WARN) {
                    data_err = 1;
                    break;
                }
            }
            if (r_block != ARCHIVE_EOF && r_block != ARCHIVE_OK) {
                data_err = 1;
            }
            archive_write_finish_entry(ext);
            if (!data_err) {
                success_count++;
            }
        } else {
            archive_read_data_skip(a);
        }
    }
    
    archive_write_close(ext);
    archive_write_free(ext);
    archive_read_close(a);
    archive_read_free(a);
    
    if (success_count > 0 && (r == ARCHIVE_EOF || r == ARCHIVE_OK)) {
        return TTZIP_OK;
    }
    return (res != 0) ? res : TTZIP_ERR_INVALID_PASSWORD;
}

int ttzip_extract_archive(const char* archive_path, const char* destination_dir) {
    return ttzip_extract_archive_advanced(archive_path, destination_dir, false, NULL);
}

int ttzip_stream_archive_entries_to_fd(
    const char* archive_path,
    const char* const* entry_patterns,
    size_t pattern_count,
    int target_fd,
    const char* password,
    bool force_binary,
    char* err_buf,
    size_t err_len
) {
    if (!archive_path) return TTZIP_ERR_INVALID_PARAM;
    setlocale(LC_ALL, "en_US.UTF-8");

    struct archive* a = archive_read_new();
    if (!a) return TTZIP_ERR_OUT_OF_MEMORY;

    archive_read_support_format_all(a);
    archive_read_support_filter_all(a);

    if (password && password[0] != '\0') {
        archive_read_add_passphrase(a, password);
    }

    int open_rc;
    if (strcmp(archive_path, "-") == 0) {
        open_rc = archive_read_open_fd(a, STDIN_FILENO, 65536);
    } else {
        open_rc = archive_read_open_filename(a, archive_path, 65536);
    }

    if (open_rc != ARCHIVE_OK) {
        if (err_buf && err_len > 0) {
            snprintf(err_buf, err_len, "%s", archive_error_string(a));
        }
        archive_read_free(a);
        return TTZIP_ERR_OPEN_FAILED;
    }

    bool is_target_tty = (isatty(target_fd) != 0);
    struct archive_entry* entry;
    int r;
    bool found = false;

    while ((r = archive_read_next_header(a, &entry)) == ARCHIVE_OK) {
        const char* pathname = archive_entry_pathname(entry);
        if (!pathname || pathname[0] == '\0') continue;

        mode_t mode = archive_entry_filetype(entry);
        if (S_ISDIR(mode)) {
            archive_read_data_skip(a);
            continue;
        }

        bool match = false;
        if (pattern_count == 0) {
            match = true;
        } else {
            for (size_t i = 0; i < pattern_count; i++) {
                const char* target = entry_patterns[i];
                if (!target) continue;
                if (strcmp(pathname, target) == 0 ||
                    (pathname[0] == '.' && pathname[1] == '/' && strcmp(pathname + 2, target) == 0) ||
                    (strcmp(pathname, target + 1) == 0 && target[0] == '/')) {
                    match = true;
                    break;
                }
            }
        }

        if (!match) {
            archive_read_data_skip(a);
            continue;
        }

        found = true;

        if (is_target_tty && !force_binary) {
            const void* sample_buff = NULL;
            size_t sample_size = 0;
            la_int64_t sample_offset = 0;
            int blk_rc = archive_read_data_block(a, &sample_buff, &sample_size, &sample_offset);
            if (blk_rc == ARCHIVE_OK && sample_size > 0) {
                if (ttzip_is_buffer_binary(sample_buff, sample_size > 4096 ? 4096 : sample_size)) {
                    if (err_buf && err_len > 0) {
                        snprintf(err_buf, err_len, "Entry '%s' contains binary data. Use --force (-f) to override.", pathname);
                    }
                    archive_read_close(a);
                    archive_read_free(a);
                    return -2;
                }
                ssize_t written = write(target_fd, sample_buff, sample_size);
                (void)written;
            }
        }

        int write_rc = archive_read_data_into_fd(a, target_fd);
        if (write_rc != ARCHIVE_OK && write_rc != ARCHIVE_EOF) {
            if (err_buf && err_len > 0) {
                snprintf(err_buf, err_len, "%s", archive_error_string(a));
            }
            archive_read_close(a);
            archive_read_free(a);
            return ARCHIVE_FATAL;
        }

        if (pattern_count > 0) {
            break;
        }
    }

    archive_read_close(a);
    archive_read_free(a);
    return found ? TTZIP_OK : -1;
}

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
) {
    (void)zstd_long_window_log; (void)cpu_threads;
    if (!output_archive_path || !input_paths || input_count == 0) {
        return TTZIP_ERR_INVALID_PARAM;
    }
    setlocale(LC_ALL, "en_US.UTF-8");

    if (strcmp(format, "7z") == 0 || strcmp(format, "7zip") == 0) {
        return ttzip_create_7z_native_c(output_archive_path, input_paths, input_count, zstd_level, password);
    } else if (strcmp(format, "zip") == 0) {
        return ttzip_create_zip_parallel_c(output_archive_path, input_paths, input_count, zstd_level, skip_mac_junk, password);
    } else if (strcmp(format, "tar") == 0) {
        return ttzip_create_tar_native_c(output_archive_path, "tar", input_paths, input_count, skip_mac_junk, zstd_level);
    } else if (strcmp(format, "tar.gz") == 0 || strcmp(format, "tgz") == 0 || strcmp(format, "gz") == 0) {
        return ttzip_create_tar_native_c(output_archive_path, "tar.gz", input_paths, input_count, skip_mac_junk, zstd_level);
    } else if (strcmp(format, "tar.bz2") == 0 || strcmp(format, "tbz2") == 0 || strcmp(format, "bz2") == 0) {
        return ttzip_create_tar_native_c(output_archive_path, "tar.bz2", input_paths, input_count, skip_mac_junk, zstd_level);
    } else if (strcmp(format, "tar.xz") == 0 || strcmp(format, "txz") == 0 || strcmp(format, "xz") == 0) {
        return ttzip_create_tar_native_c(output_archive_path, "tar.xz", input_paths, input_count, skip_mac_junk, zstd_level);
    } else if (strcmp(format, "zst") == 0 || strcmp(format, "zstd") == 0 || strcmp(format, "tar.zst") == 0 || strcmp(format, "tzst") == 0) {
        return ttzip_create_tar_zstd_direct_c(output_archive_path, input_paths, input_count, zstd_level, skip_mac_junk);
    } else if (strcmp(format, "lzip") == 0 || strcmp(format, "lz") == 0 || strcmp(format, "tar.lz") == 0) {
        return ttzip_create_tar_native_c(output_archive_path, "lzip", input_paths, input_count, skip_mac_junk, zstd_level);
    } else if (strcmp(format, "lz4") == 0 || strcmp(format, "tar.lz4") == 0) {
        return ttzip_create_tar_native_c(output_archive_path, "lz4", input_paths, input_count, skip_mac_junk, zstd_level);
    } else if (strcmp(format, "brotli") == 0 || strcmp(format, "br") == 0) {
        return ttzip_create_tar_native_c(output_archive_path, "brotli", input_paths, input_count, skip_mac_junk, zstd_level);
    } else if (strcmp(format, "lrzip") == 0 || strcmp(format, "lrz") == 0) {
        return ttzip_create_tar_native_c(output_archive_path, "lrzip", input_paths, input_count, skip_mac_junk, zstd_level);
    } else if (strcmp(format, "snappy") == 0 || strcmp(format, "sz") == 0) {
        return ttzip_create_tar_native_c(output_archive_path, "snappy", input_paths, input_count, skip_mac_junk, zstd_level);
    } else if (strcmp(format, "iso") == 0 || strcmp(format, "iso9660") == 0 || strcmp(format, "dmg") == 0) {
        return ttzip_create_tar_native_c(output_archive_path, "iso", input_paths, input_count, skip_mac_junk, zstd_level);
    } else if (strcmp(format, "wim") == 0) {
        return ttzip_create_tar_native_c(output_archive_path, "tar", input_paths, input_count, skip_mac_junk, zstd_level);
    }

    return ttzip_create_zip_parallel_c(output_archive_path, input_paths, input_count, zstd_level, skip_mac_junk, password);
}

int ttzip_create_archive_advanced(
    const char* output_archive_path,
    const char* format,
    const char* const* input_paths,
    size_t input_count,
    bool skip_mac_junk
) {
    return ttzip_create_archive_tuned(output_archive_path, format, input_paths, input_count, skip_mac_junk, 3, 0, 0, NULL);
}

int ttzip_create_archive(
    const char* output_archive_path,
    const char* format,
    const char* const* input_paths,
    size_t input_count
) {
    return ttzip_create_archive_advanced(output_archive_path, format, input_paths, input_count, false);
}

void* ttzip_aligned_alloc_16k(size_t size) {
    return ttzip_core_aligned_alloc_16k(size);
}

void ttzip_aligned_free_16k(void* ptr) {
    ttzip_core_aligned_free_16k(ptr);
}
