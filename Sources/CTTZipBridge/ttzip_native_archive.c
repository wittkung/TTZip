// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_native_archive.c
 * @brief High-performance native archive inspector and extractor router.
 */

#include "include/ttzip_native_archive.h"
#include "include/CTTZipParser.h"
#include "include/CTTZipBridge.h"
#include "include/CTTZipCommon.h"
#include "include/CTTZipBridge_Zstd.h"
#include "include/ttzip_7z_header_parser.h"
#include "include/ttzip_tar_native.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/mman.h>

int ttzip_core_posix_spawn_fast(
    const char* bin_path,
    const char* const* argv,
    const char* working_dir
);

int ttzip_extract_zip_c_parallel(
    const char* archive_path,
    const char* destination_dir,
    bool skip_mac_junk,
    const char* password
);

int ttzip_extract_7z_native_c(
    const char* archive_path,
    const char* destination_dir,
    const char* password
);

ttzip_native_fmt_t ttzip_detect_format_from_header(const uint8_t* buffer, size_t len) {
    if (!buffer || len == 0) return TTZIP_NATIVE_FMT_UNKNOWN;

    if (len >= 2) {
        uint16_t u16;
        memcpy(&u16, buffer, 2);
        if (u16 == 0x4B50) return TTZIP_NATIVE_FMT_ZIP; // 'PK'
        if (u16 == 0x8B1F) return TTZIP_NATIVE_FMT_GZ;
    }

    if (len >= 6) {
        uint32_t m32;
        uint16_t m16;
        memcpy(&m32, buffer, 4);
        memcpy(&m16, buffer + 4, 2);
        if (m32 == 0xAFBC7A37 && m16 == 0x1C27) { // "7z\xbc\xaf\x27\x1c"
            return TTZIP_NATIVE_FMT_7Z;
        }
        if (buffer[0] == 0xFD) {
            uint32_t xz_magic;
            memcpy(&xz_magic, buffer + 1, 4);
            if (xz_magic == 0x5A587A37) { // '7zXZ'
                return TTZIP_NATIVE_FMT_XZ;
            }
        }
    }

    if (len >= 4) {
        uint32_t u32;
        memcpy(&u32, buffer, 4);
        if (u32 == 0xFD2FB528) return TTZIP_NATIVE_FMT_ZSTD;
        if (u32 == 0x184D2204) return TTZIP_NATIVE_FMT_LZ4;
    }

    if (len >= 3 && buffer[0] == 'B' && buffer[1] == 'Z' && buffer[2] == 'h') {
        return TTZIP_NATIVE_FMT_BZ2;
    }

    if (len >= 262) {
        uint32_t ustar4;
        memcpy(&ustar4, buffer + 257, 4);
        if (ustar4 == 0x61747375 && buffer[261] == 'r') { // 'usta' + 'r'
            return TTZIP_NATIVE_FMT_TAR;
        }
    }

    return TTZIP_NATIVE_FMT_UNKNOWN;
}

ttzip_native_fmt_t ttzip_detect_format_from_filename(const char* filename) {
    if (!filename) return TTZIP_NATIVE_FMT_UNKNOWN;
    if (strstr(filename, ".zip") || strstr(filename, ".ZIP")) return TTZIP_NATIVE_FMT_ZIP;
    if (strstr(filename, ".7z") || strstr(filename, ".7Z")) return TTZIP_NATIVE_FMT_7Z;
    if (strstr(filename, ".tar") || strstr(filename, ".tgz") || strstr(filename, ".tzst")) return TTZIP_NATIVE_FMT_TAR;
    if (strstr(filename, ".gz")) return TTZIP_NATIVE_FMT_GZ;
    if (strstr(filename, ".zst")) return TTZIP_NATIVE_FMT_ZSTD;
    if (strstr(filename, ".lz4")) return TTZIP_NATIVE_FMT_LZ4;
    if (strstr(filename, ".xz")) return TTZIP_NATIVE_FMT_XZ;
    if (strstr(filename, ".bz2")) return TTZIP_NATIVE_FMT_BZ2;
    return TTZIP_NATIVE_FMT_UNKNOWN;
}

int ttzip_native_inspect_archive(const char* archive_path, void* context, ttzip_native_entry_cb callback) {
    if (!archive_path || !callback) return -1;

    int fd = open(archive_path, O_RDONLY);
    if (fd < 0) return -1;

    struct stat st;
    if (fstat(fd, &st) != 0) {
        close(fd);
        return -1;
    }

    if (st.st_size == 0) {
        close(fd);
        return 0;
    }

    size_t file_size = (size_t)st.st_size;
    void* mapped = mmap(NULL, file_size, PROT_READ, MAP_SHARED, fd, 0);
    close(fd);

    if (mapped == MAP_FAILED) return -1;

    const uint8_t* byte_ptr = (const uint8_t*)mapped;
    ttzip_native_fmt_t fmt = ttzip_detect_format_from_header(byte_ptr, file_size);
    if (fmt == TTZIP_NATIVE_FMT_UNKNOWN) {
        fmt = ttzip_detect_format_from_filename(archive_path);
    }

    if (fmt == TTZIP_NATIVE_FMT_ZIP) {
        ttzip_eocd_info_t eocd;
        if (ttzip_find_eocd(byte_ptr, file_size, &eocd)) {
            size_t curr_pos = (size_t)eocd.cd_offset;
            for (uint64_t i = 0; i < eocd.total_entries; i++) {
                ttzip_parsed_entry_t entry;
                size_t next_pos = 0;
                if (!ttzip_parse_cdfh_entry(byte_ptr, file_size, curr_pos, &entry, &next_pos)) {
                    break;
                }
                callback(context, entry.rel_path, (int64_t)entry.uncompressed_size, entry.is_directory);
                curr_pos = next_pos;
            }
            munmap(mapped, file_size);
            return 0;
        }
    } else if (fmt == TTZIP_NATIVE_FMT_7Z) {
        ttzip_7z_header_info_t info;
        if (ttzip_7z_parse_header_metadata(byte_ptr, file_size, &info) == 0 && info.num_files > 0) {
            size_t size_idx = 0;
            for (size_t f = 0; f < info.num_files; f++) {
                if (info.files[f].rel_path[0] == '\0') continue;
                int64_t unp_size = 0;
                if (!info.files[f].is_empty_stream && size_idx < info.num_stream_sizes) {
                    unp_size = (int64_t)info.stream_sizes[size_idx++];
                }
                callback(context, info.files[f].rel_path, unp_size, info.files[f].is_dir);
            }
            ttzip_7z_free_header_info(&info);
            munmap(mapped, file_size);
            return 0;
        }
        ttzip_7z_free_header_info(&info);
    } else if (fmt == TTZIP_NATIVE_FMT_TAR) {
        size_t offset = 0;
        int count = 0;
        ttzip_tar_entry_info_t entry;
        while (offset + 512 <= file_size) {
            const uint8_t *block = byte_ptr + offset;
            if (!ttzip_tar_header_parse_fast(block, &entry)) break;
            if (entry.is_eoa_zero || strlen(entry.name) == 0) break;

            bool is_dir = (entry.typeflag == '5') || (entry.name[strlen(entry.name)-1] == '/');
            callback(context, entry.name, (int64_t)entry.size, is_dir);
            count++;

            size_t blocks = ((size_t)entry.size + 511) / 512;
            offset += 512 + blocks * 512;
        }
        munmap(mapped, file_size);
        return (count > 0) ? 0 : -1;
    } else if (fmt == TTZIP_NATIVE_FMT_ZSTD) {
        uint8_t *decomp_buf = malloc(128 * 1024);
        if (decomp_buf) {
            size_t decomp_size = ttzip_zstd_decompress(byte_ptr, file_size > 128 * 1024 ? 128 * 1024 : file_size, decomp_buf, 128 * 1024);
            if (decomp_size >= 262 && memcmp(decomp_buf + 257, "ustar", 5) == 0) {
                size_t offset = 0;
                int count = 0;
                ttzip_tar_entry_info_t entry;
                while (offset + 512 <= decomp_size) {
                    const uint8_t *block = decomp_buf + offset;
                    if (!ttzip_tar_header_parse_fast(block, &entry)) break;
                    if (entry.is_eoa_zero || strlen(entry.name) == 0) break;

                    bool is_dir = (entry.typeflag == '5') || (entry.name[strlen(entry.name)-1] == '/');
                    callback(context, entry.name, (int64_t)entry.size, is_dir);
                    count++;

                    size_t blocks = ((size_t)entry.size + 511) / 512;
                    offset += 512 + blocks * 512;
                }
                free(decomp_buf);
                if (count > 0) {
                    munmap(mapped, file_size);
                    return 0;
                }
            }
            free(decomp_buf);
        }
    }

    munmap(mapped, file_size);
    return -1;
}

int ttzip_native_extract_archive(const char* archive_path, const char* dest_dir, bool skip_mac_junk, const char* password) {
    if (!archive_path || !dest_dir) return -1;
    ttzip_common_mkdir_p(dest_dir);

    ttzip_native_fmt_t fmt = ttzip_detect_format_from_filename(archive_path);
    if (fmt == TTZIP_NATIVE_FMT_ZIP) {
        return ttzip_extract_zip_c_parallel(archive_path, dest_dir, skip_mac_junk, password);
    } else if (fmt == TTZIP_NATIVE_FMT_7Z) {
        return ttzip_extract_7z_native_c(archive_path, dest_dir, password);
    } else if (fmt == TTZIP_NATIVE_FMT_ZSTD || strstr(archive_path, ".tar.zst") || strstr(archive_path, ".tzst")) {
        return ttzip_extract_tar_zstd_direct_c(archive_path, dest_dir, skip_mac_junk);
    }

    return ttzip_extract_tar_native_c(archive_path, dest_dir, skip_mac_junk);
}
