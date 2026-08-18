// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_tar_native.c
 * @brief High-performance native TAR/GZ/BZ2/XZ archive creation and extraction engine.
 */

#include "include/CTTZipBridge.h"
#include "include/ttzip_native_archive.h"
#include "include/ttzip_tar_zstd_direct.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <dirent.h>
#include <fcntl.h>
#include <unistd.h>
#include <archive.h>
#include <archive_entry.h>

#include <sys/mman.h>

static void write_reg_file_data(struct archive* a, const char* full_path, int64_t file_size) {
    int fd = open(full_path, O_RDONLY);
    if (fd < 0) return;
    
    if (file_size >= 64 * 1024) {
        size_t mapped_size = ttzip_clamp_size((uint64_t)file_size);
        void* mapped = mmap(NULL, mapped_size, PROT_READ, MAP_SHARED, fd, 0);
        if (mapped != MAP_FAILED) {
            madvise(mapped, mapped_size, MADV_WILLNEED | MADV_SEQUENTIAL);
            archive_write_data(a, mapped, mapped_size);
            munmap(mapped, mapped_size);
            close(fd);
            return;
        }
    }
    
    char stack_buff[4096];
    if (file_size > 0 && file_size <= (int64_t)sizeof(stack_buff)) {
        ssize_t bytes_read = read(fd, stack_buff, (size_t)file_size);
        if (bytes_read > 0) {
            archive_write_data(a, stack_buff, (size_t)bytes_read);
        }
        close(fd);
        return;
    }
    
    size_t chunk_cap = 1048576;
    char* buff = (char*)malloc(chunk_cap);
    if (buff) {
        ssize_t bytes_read;
        while ((bytes_read = read(fd, buff, chunk_cap)) > 0) {
            archive_write_data(a, buff, (size_t)bytes_read);
        }
        free(buff);
    }
    close(fd);
}

static int add_file_or_dir_to_archive(
    struct archive* a,
    const char* full_path,
    const char* rel_path,
    bool skip_mac_junk
) {
    if (!full_path || !rel_path || rel_path[0] == '\0') return 0;
    
    if (skip_mac_junk && ttzip_is_mac_junk(rel_path)) {
        return 0;
    }
    
    struct stat st;
    if (lstat(full_path, &st) != 0) {
        return -1;
    }
    
    struct archive_entry* entry = archive_entry_new();
    if (!entry) return -1;
    
    size_t rel_len = strlen(rel_path);
    if (S_ISDIR(st.st_mode) && rel_len > 0 && rel_path[rel_len - 1] != '/') {
        char* dir_path = NULL;
        if (asprintf(&dir_path, "%s/", rel_path) > 0 && dir_path) {
            archive_entry_set_pathname(entry, dir_path);
            free(dir_path);
        } else {
            archive_entry_set_pathname(entry, rel_path);
        }
    } else {
        archive_entry_set_pathname(entry, rel_path);
    }
    archive_entry_copy_stat(entry, &st);
    
    if (S_ISLNK(st.st_mode)) {
        char symlink_target[1024];
        ssize_t len = readlink(full_path, symlink_target, sizeof(symlink_target) - 1);
        if (len >= 0) {
            symlink_target[len] = '\0';
            archive_entry_set_symlink(entry, symlink_target);
        }
    }
    
    int r = archive_write_header(a, entry);
    if (r != ARCHIVE_OK) {
        archive_entry_free(entry);
        return -1;
    }
    
    if (S_ISREG(st.st_mode)) {
        write_reg_file_data(a, full_path, (int64_t)st.st_size);
    }
    
    archive_entry_free(entry);
    
    if (S_ISDIR(st.st_mode)) {
        DIR* dir = opendir(full_path);
        if (dir) {
            struct dirent* de;
            while ((de = readdir(dir)) != NULL) {
                if (strcmp(de->d_name, ".") == 0 || strcmp(de->d_name, "..") == 0) {
                    continue;
                }
                char* sub_full = NULL;
                char* sub_rel = NULL;
                if (asprintf(&sub_full, "%s/%s", full_path, de->d_name) > 0 &&
                    asprintf(&sub_rel, "%s/%s", rel_path, de->d_name) > 0) {
                    add_file_or_dir_to_archive(a, sub_full, sub_rel, skip_mac_junk);
                }
                if (sub_full) free(sub_full);
                if (sub_rel) free(sub_rel);
            }
            closedir(dir);
        }
    }
    
    return 0;
}

#include "include/CTTZipGzParallel.h"

int ttzip_create_tar_native_c(
    const char* output_path,
    const char* format_flag,
    const char* const* input_paths,
    size_t input_count,
    bool skip_mac_junk,
    int level
) {
    if (!output_path || !input_paths || input_count == 0) {
        return TTZIP_ERR_INVALID_PARAM;
    }
    
    struct archive* a = archive_write_new();
    if (!a) return TTZIP_ERR_OUT_OF_MEMORY;
    
    parallel_gz_ctx* parallel_ctx = NULL;
    char lvl_str[16];
    int effective_level = level > 0 ? level : 1;
    snprintf(lvl_str, sizeof(lvl_str), "%d", effective_level);

    if (format_flag) {
        if (strcmp(format_flag, "tar.gz") == 0 || strcmp(format_flag, "tgz") == 0 || strcmp(format_flag, "gz") == 0) {
            parallel_ctx = init_parallel_gz(output_path, effective_level);
            if (!parallel_ctx) {
                archive_write_free(a);
                return TTZIP_ERR_OPEN_FAILED;
            }
        } else if (strcmp(format_flag, "tar.bz2") == 0 || strcmp(format_flag, "tbz2") == 0 || strcmp(format_flag, "bz2") == 0) {
            parallel_ctx = init_parallel_bz2(output_path, effective_level);
            if (!parallel_ctx) {
                archive_write_free(a);
                return TTZIP_ERR_OPEN_FAILED;
            }
        } else if (strcmp(format_flag, "tar.xz") == 0 || strcmp(format_flag, "txz") == 0 || strcmp(format_flag, "xz") == 0) {
            parallel_ctx = init_parallel_xz(output_path, effective_level);
            if (!parallel_ctx) {
                archive_write_free(a);
                return TTZIP_ERR_OPEN_FAILED;
            }
        } else if (strcmp(format_flag, "tar.zst") == 0 || strcmp(format_flag, "tzst") == 0 || strcmp(format_flag, "zst") == 0) {
            archive_write_free(a);
            return ttzip_create_tar_zstd_direct_c(output_path, input_paths, input_count, effective_level, skip_mac_junk);
        } else if (strcmp(format_flag, "lzip") == 0 || strcmp(format_flag, "lz") == 0 || strcmp(format_flag, "tar.lz") == 0) {
            parallel_ctx = init_parallel_xz(output_path, effective_level);
            if (!parallel_ctx) {
                archive_write_free(a);
                return TTZIP_ERR_OPEN_FAILED;
            }
        } else if (strcmp(format_flag, "lz4") == 0 || strcmp(format_flag, "tar.lz4") == 0) {
            parallel_ctx = init_parallel_lz4(output_path, effective_level);
            if (!parallel_ctx) {
                archive_write_free(a);
                return TTZIP_ERR_OPEN_FAILED;
            }
        } else if (strcmp(format_flag, "lrzip") == 0 || strcmp(format_flag, "lrz") == 0) {
            parallel_ctx = init_parallel_xz(output_path, effective_level);
            if (!parallel_ctx) {
                archive_write_free(a);
                return TTZIP_ERR_OPEN_FAILED;
            }
        } else if (strcmp(format_flag, "brotli") == 0 || strcmp(format_flag, "br") == 0) {
            if (archive_write_add_filter_by_name(a, "brotli") != ARCHIVE_OK) {
                archive_write_add_filter_program(a, "brotli");
            }
        } else if (strcmp(format_flag, "snappy") == 0 || strcmp(format_flag, "sz") == 0) {
            if (archive_write_add_filter_by_name(a, "snappy") != ARCHIVE_OK) {
                archive_write_add_filter_program(a, "snappy");
            }
        } else {
            archive_write_add_filter_none(a);
        }
    } else {
        archive_write_add_filter_none(a);
    }
    
    if (format_flag && (strcmp(format_flag, "iso") == 0 || strcmp(format_flag, "iso9660") == 0 || strcmp(format_flag, "dmg") == 0)) {
        archive_write_set_format_iso9660(a);
    } else {
        archive_write_set_format_pax_restricted(a);
    }
    
    archive_write_set_bytes_per_block(a, 8 * 1024 * 1024);
    archive_write_set_bytes_in_last_block(a, 1);
    
    if (parallel_ctx) {
        if (archive_write_open(a, parallel_ctx, NULL, (archive_write_callback*)ttzip_archive_gz_write_cb, (archive_close_callback*)ttzip_archive_gz_close_cb) != ARCHIVE_OK) {
            archive_write_free(a);
            return TTZIP_ERR_OPEN_FAILED;
        }
    } else {
        if (strcmp(output_path, "-") == 0) {
            if (archive_write_open_fd(a, STDOUT_FILENO) != ARCHIVE_OK) {
                archive_write_free(a);
                return TTZIP_ERR_OPEN_FAILED;
            }
        } else {
            if (archive_write_open_filename(a, output_path) != ARCHIVE_OK) {
                archive_write_free(a);
                return TTZIP_ERR_OPEN_FAILED;
            }
        }
    }
    
    for (size_t i = 0; i < input_count; i++) {
        const char* in_path = input_paths[i];
        if (!in_path || in_path[0] == '\0') continue;
        
        const char* slash = strrchr(in_path, '/');
        const char* rel_name = slash ? (slash + 1) : in_path;
        if (rel_name[0] == '\0') rel_name = in_path;
        
        add_file_or_dir_to_archive(a, in_path, rel_name, skip_mac_junk);
    }
    
    archive_write_close(a);
    archive_write_free(a);
    return TTZIP_OK;
}

int ttzip_extract_tar_native_c(
    const char* archive_path,
    const char* dest_dir,
    bool skip_mac_junk
) {
    if (!archive_path || !dest_dir) return TTZIP_ERR_INVALID_PARAM;
    
    ttzip_common_mkdir_p(dest_dir);
    
    struct archive* a = archive_read_new();
    if (!a) return TTZIP_ERR_OUT_OF_MEMORY;
    
    archive_read_support_filter_all(a);
    archive_read_support_format_all(a);
    archive_read_set_filter_option(a, NULL, "threads", "0");
    archive_read_set_filter_option(a, "xz", "threads", "0");
    archive_read_set_filter_option(a, "zstd", "threads", "0");
    archive_read_set_filter_option(a, "lzip", "threads", "0");
    
    struct archive* ext = archive_write_disk_new();
    if (!ext) {
        archive_read_free(a);
        return TTZIP_ERR_OUT_OF_MEMORY;
    }
    
    int flags = ARCHIVE_EXTRACT_TIME | ARCHIVE_EXTRACT_PERM | ARCHIVE_EXTRACT_SECURE_NODOTDOT | ARCHIVE_EXTRACT_UNLINK;
    archive_write_disk_set_options(ext, flags);
    
    if (strcmp(archive_path, "-") == 0) {
        if (archive_read_open_fd(a, STDIN_FILENO, 8 * 1024 * 1024) != ARCHIVE_OK) {
            archive_write_free(ext);
            archive_read_free(a);
            return TTZIP_ERR_OPEN_FAILED;
        }
    } else {
        if (archive_read_open_filename(a, archive_path, 8 * 1024 * 1024) != ARCHIVE_OK) {
            archive_write_free(ext);
            archive_read_free(a);
            return TTZIP_ERR_OPEN_FAILED;
        }
    }
    
    char last_parent_dir[1024] = {0};
    struct {
        uint32_t hash;
        char path[512];
    } mkdir_cache[64];
    memset(mkdir_cache, 0, sizeof(mkdir_cache));

    struct archive_entry* entry;
    int r;
    while ((r = archive_read_next_header(a, &entry)) == ARCHIVE_OK) {
        const char* entry_pathname = archive_entry_pathname(entry);
        if (skip_mac_junk && ttzip_is_mac_junk(entry_pathname)) {
            archive_read_data_skip(a);
            continue;
        }
        
        char full_dest_path[4096];
        ttzip_common_join_path(full_dest_path, sizeof(full_dest_path), dest_dir, entry_pathname);
        
        if (strchr(entry_pathname, '/') != NULL) {
            char parent_dir[1024];
            snprintf(parent_dir, sizeof(parent_dir), "%s", full_dest_path);
            char* last_slash = strrchr(parent_dir, '/');
            if (last_slash && last_slash != parent_dir) {
                *last_slash = '\0';
                if (last_parent_dir[0] != '\0' && strcmp(parent_dir, last_parent_dir) == 0) {
                    // L1 Hit: Skip mkdir_p
                } else {
                    uint32_t h = 2166136261u;
                    for (const char* p = parent_dir; *p; p++) {
                        h = (h ^ (uint8_t)*p) * 16777619u;
                    }
                    size_t slot = (size_t)(h & 63);
                    if (mkdir_cache[slot].hash == h && strcmp(mkdir_cache[slot].path, parent_dir) == 0) {
                        // L2 Hit: Skip mkdir_p
                    } else {
                        ttzip_common_mkdir_p(parent_dir);
                        mkdir_cache[slot].hash = h;
                        snprintf(mkdir_cache[slot].path, sizeof(mkdir_cache[slot].path), "%s", parent_dir);
                    }
                    snprintf(last_parent_dir, sizeof(last_parent_dir), "%s", parent_dir);
                }
            }
        }
        
        archive_entry_set_pathname(entry, full_dest_path);
        
        int h_res = archive_write_header(ext, entry);
        if (h_res >= ARCHIVE_WARN) {
            const void* buff;
            size_t size;
            int64_t offset;
            while ((r = archive_read_data_block(a, &buff, &size, &offset)) == ARCHIVE_OK) {
                archive_write_data_block(ext, buff, size, offset);
            }
            archive_write_finish_entry(ext);
        } else {
            archive_read_data_skip(a);
        }
    }
    
    archive_write_close(ext);
    archive_write_free(ext);
    archive_read_close(a);
    archive_read_free(a);
    return TTZIP_OK;
}
