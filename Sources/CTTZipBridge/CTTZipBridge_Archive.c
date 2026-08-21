// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/CTTZipBridge.h"
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <archive.h>
#include <archive_entry.h>

// MARK: - 1. Magic Number Sniffer
ttzip_magic_info_t ttzip_magic_sniff_buffer(const void *buf, size_t len) {
    ttzip_magic_info_t res;
    memset(&res, 0, sizeof(res));
    res.kind = TTZIP_KIND_UNKNOWN;
    res.format_name = "BINARY";
    res.mime_type = "application/octet-stream";
    res.is_archive = false;

    if (!buf || len < 4) return res;
    const uint8_t *b = (const uint8_t *)buf;

    if (len >= 4 && b[0] == 'P' && b[1] == 'K' && b[2] == 0x03 && b[3] == 0x04) {
        res.kind = TTZIP_KIND_ARCHIVE;
        res.format_name = "ZIP";
        res.mime_type = "application/zip";
        res.is_archive = true;
        return res;
    }
    if (len >= 6 && b[0] == '7' && b[1] == 'z' && b[2] == 0xBC && b[3] == 0xAF && b[4] == 0x27 && b[5] == 0x1C) {
        res.kind = TTZIP_KIND_ARCHIVE;
        res.format_name = "7Z";
        res.mime_type = "application/x-7z-compressed";
        res.is_archive = true;
        return res;
    }
    if (len >= 2 && b[0] == 0x1F && b[1] == 0x8B) {
        res.kind = TTZIP_KIND_ARCHIVE;
        res.format_name = "GZIP";
        res.mime_type = "application/gzip";
        res.is_archive = true;
        return res;
    }
    if (len >= 6 && b[0] == 0xFD && b[1] == '7' && b[2] == 'z' && b[3] == 'X' && b[4] == 'Z' && b[5] == 0x00) {
        res.kind = TTZIP_KIND_ARCHIVE;
        res.format_name = "XZ";
        res.mime_type = "application/x-xz";
        res.is_archive = true;
        return res;
    }
    if (len >= 4 && b[0] == 0x28 && b[1] == 0xB5 && b[2] == 0x2F && b[3] == 0xFD) {
        res.kind = TTZIP_KIND_ARCHIVE;
        res.format_name = "ZSTD";
        res.mime_type = "application/zstd";
        res.is_archive = true;
        return res;
    }
    if (len >= 3 && b[0] == 'B' && b[1] == 'Z' && b[2] == 'h') {
        res.kind = TTZIP_KIND_ARCHIVE;
        res.format_name = "BZIP2";
        res.mime_type = "application/x-bzip2";
        res.is_archive = true;
        return res;
    }
    if (len >= 7 && b[0] == 'R' && b[1] == 'a' && b[2] == 'r' && b[3] == '!' && b[4] == 0x1A && b[5] == 0x07) {
        res.kind = TTZIP_KIND_ARCHIVE;
        res.format_name = "RAR";
        res.mime_type = "application/x-rar-compressed";
        res.is_archive = true;
        return res;
    }
    return res;
}

// MARK: - 2. Libarchive Wrappers
int ttzip_extract_tar_native_c(const char* tar_path, const char* dest_dir, bool skip_mac_junk) {
    if (!tar_path || !dest_dir) return -1;
    return ttzip_extract_archive_advanced(tar_path, dest_dir, skip_mac_junk, NULL);
}

int ttzip_create_tar_native_c(
    const char* out_path,
    const char* format_name,
    const char* const* input_paths,
    size_t num_inputs,
    bool skip_mac_junk,
    int level
) {
    if (!out_path || !input_paths || num_inputs == 0) return -1;
    TTZipCreateOptions opt;
    memset(&opt, 0, sizeof(opt));
    opt.format = TTZIP_ARCHIVE_FORMAT_TAR;
    opt.level = TTZIP_COMPRESSION_LEVEL_STORE;
    opt.encryption = TTZIP_ENCRYPTION_NONE;
    return (int)ttzip_rust_create_archive(input_paths, num_inputs, out_path, &opt);
}

int ttzip_extract_archive_advanced(
    const char* archive_path,
    const char* destination_dir,
    bool skip_mac_junk,
    const char* password
) {
    if (!archive_path || !destination_dir) return -1;
    
    TTZipExtractOptions opt;
    memset(&opt, 0, sizeof(opt));
    opt.destination_path = destination_dir;
    opt.password = password;
    opt.thread_budget = 0;
    opt.overwrite_existing = true;
    opt.preserve_permissions = true;
    
    TTZipStatus status = ttzip_rust_extract_archive(archive_path, destination_dir, &opt);
    if (status == TTZIP_STATUS_OK) return 0;
    
    // Libarchive fallback
    struct archive* a = archive_read_new();
    if (!a) return -1;
    struct archive* ext = archive_write_disk_new();
    if (!ext) { archive_read_free(a); return -1; }

    archive_read_support_format_all(a);
    archive_read_support_filter_all(a);
    archive_write_disk_set_options(ext, ARCHIVE_EXTRACT_TIME | ARCHIVE_EXTRACT_PERM | ARCHIVE_EXTRACT_SECURE_NODOTDOT | ARCHIVE_EXTRACT_UNLINK);

    if (password && password[0] != '\0') {
        archive_read_add_passphrase(a, password);
    }

    if (archive_read_open_filename(a, archive_path, 65536) != ARCHIVE_OK) {
        archive_write_free(ext);
        archive_read_free(a);
        return -1;
    }

    struct archive_entry* entry;
    int r;
    int extracted_count = 0;
    while ((r = archive_read_next_header(a, &entry)) == ARCHIVE_OK) {
        const char* pathname = archive_entry_pathname(entry);
        if (!pathname || pathname[0] == '\0') continue;
        if (skip_mac_junk) {
            const char* base = strrchr(pathname, '/');
            const char* name = base ? (base + 1) : pathname;
            if (strncmp(name, "._", 2) == 0 || strcmp(name, ".DS_Store") == 0 || strstr(pathname, "__MACOSX") != NULL) {
                archive_read_data_skip(a);
                continue;
            }
        }
        char full_dest[4096];
        snprintf(full_dest, sizeof(full_dest), "%s/%s", destination_dir, pathname);
        archive_entry_set_pathname(entry, full_dest);
        if (archive_write_header(ext, entry) == ARCHIVE_OK) {
            const void* buff;
            size_t size;
            la_int64_t offset;
            int data_ok = 1;
            while ((r = archive_read_data_block(a, &buff, &size, &offset)) == ARCHIVE_OK) {
                if (archive_write_data_block(ext, buff, size, offset) != ARCHIVE_OK) {
                    data_ok = 0;
                    break;
                }
            }
            if (r != ARCHIVE_EOF && r != ARCHIVE_OK) {
                data_ok = 0;
            }
            archive_write_finish_entry(ext);
            if (data_ok) {
                extracted_count++;
            } else {
                unlink(full_dest);
            }
        }
    }

    archive_read_close(a);
    archive_read_free(a);
    archive_write_close(ext);
    archive_write_free(ext);
    return (extracted_count > 0) ? 0 : -1;
}
