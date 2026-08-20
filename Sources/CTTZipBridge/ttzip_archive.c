// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine.

#include "include/ttzip_archive.h"
#include "include/ttzip_api.h"
#include "include/ttzip_fs.h"
#include "include/ttzip_zip_container.h"
#include "include/ttzip_tar_container.h"
#include "include/ttzip_magic_sniff.h"
#include "include/ttzip_crc64.h"
#include "include/CTTZipCRC32Neon.h"

extern int ttzip_extract_zip_c_parallel(const char* zip_path, const char* dest_dir);

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if defined(_WIN32)
#include <windows.h>
#include <io.h>
#else
#include <unistd.h>
#include <sys/stat.h>
#endif

static bool ends_with(const char *str, const char *suffix) {
    if (!str || !suffix) return false;
    size_t len_str = strlen(str);
    size_t len_suf = strlen(suffix);
    if (len_str < len_suf) return false;
    return (strcasecmp(str + len_str - len_suf, suffix) == 0);
}

static int ttzip_tar_archive_create(
    const char *const *input_paths,
    size_t input_count,
    const char *output_archive_path,
    ttzip_progress_fn progress_cb,
    void *user_data
) {
    FILE *out_fp = fopen(output_archive_path, "wb");
    if (!out_fp) return TTZIP_API_ERR_IO_FAILURE;

    uint64_t total_processed = 0;

    for (size_t i = 0; i < input_count; i++) {
        const char *src_path = input_paths[i];
        if (!src_path) continue;

        uint64_t file_len = 0;
        const void *mapped = ttzip_fs_mmap_read(src_path, &file_len);
        if (!mapped && file_len > 0) continue;

        const char *base_name = strrchr(src_path, '/');
#if defined(_WIN32)
        if (!base_name) base_name = strrchr(src_path, '\\');
#endif
        base_name = base_name ? base_name + 1 : src_path;

        ttzip_tar_entry_meta_t meta;
        memset(&meta, 0, sizeof(meta));
        meta.path = base_name;
        meta.file_size = file_len;
        meta.mode = 0644;
        meta.mtime = 1700000000;
        meta.is_directory = false;

        uint8_t hdr_block[TTZIP_TAR_BLOCK_SIZE];
        ttzip_tar_write_header(&meta, hdr_block);
        fwrite(hdr_block, 1, TTZIP_TAR_BLOCK_SIZE, out_fp);

        if (file_len > 0 && mapped) {
            fwrite(mapped, 1, (size_t)file_len, out_fp);
            size_t pad = (TTZIP_TAR_BLOCK_SIZE - (file_len % TTZIP_TAR_BLOCK_SIZE)) % TTZIP_TAR_BLOCK_SIZE;
            if (pad > 0) {
                uint8_t zeros[TTZIP_TAR_BLOCK_SIZE] = {0};
                fwrite(zeros, 1, pad, out_fp);
            }
        }

        if (mapped) ttzip_fs_munmap(mapped, file_len);
        total_processed += file_len;

        if (progress_cb) {
            progress_cb(total_processed, total_processed, base_name, user_data);
        }
    }

    /* Write 1024 zero-byte trailer */
    uint8_t trailer[1024];
    ttzip_tar_write_trailer(trailer);
    fwrite(trailer, 1, 1024, out_fp);

    fclose(out_fp);
    return TTZIP_API_OK;
}

int ttzip_archive_create(
    const ttzip_archive_config_t *config,
    const char *const *input_paths,
    size_t input_count,
    const char *output_archive_path,
    ttzip_progress_fn progress_cb,
    void *user_data
) {
    if (!output_archive_path || input_count == 0 || !input_paths) {
        return TTZIP_API_ERR_INVALID_PARAM;
    }

    if (ends_with(output_archive_path, ".tar") || (config && config->format_override && strcmp(config->format_override, "tar") == 0)) {
        return ttzip_tar_archive_create(input_paths, input_count, output_archive_path, progress_cb, user_data);
    }

    FILE *out_fp = fopen(output_archive_path, "wb");
    if (!out_fp) return TTZIP_API_ERR_IO_FAILURE;

    ttzip_api_codec_t codec = config ? (ttzip_api_codec_t)config->codec : TTZIP_API_CODEC_DEFLATE;
    int level = config ? config->level : 6;

    typedef struct entry_rec {
        char path[1024];
        uint32_t crc32;
        uint64_t uncompressed_size;
        uint64_t compressed_size;
        uint64_t offset;
    } entry_rec_t;

    entry_rec_t *records = (entry_rec_t *)malloc(sizeof(entry_rec_t) * input_count);
    if (!records) {
        fclose(out_fp);
        return TTZIP_API_ERR_OUT_OF_MEMORY;
    }

    uint64_t total_processed = 0;
    uint64_t current_file_offset = 0;

    for (size_t i = 0; i < input_count; i++) {
        const char *src_path = input_paths[i];
        if (!src_path) continue;

        uint64_t file_len = 0;
        const void *mapped = ttzip_fs_mmap_read(src_path, &file_len);
        if (!mapped && file_len > 0) {
            continue;
        }

        uint32_t file_crc = mapped ? ttzip_crc32_fast(0, (const uint8_t *)mapped, (size_t)file_len) : 0;
        
        /* Compress buffer */
        size_t max_comp_len = ttzip_compress_bound(codec, (size_t)file_len);
        void *comp_buf = malloc(max_comp_len > 0 ? max_comp_len : 1);
        size_t comp_len = 0;

        if (codec == TTZIP_API_CODEC_STORE || file_len == 0) {
            comp_len = (size_t)file_len;
            if (comp_buf && mapped) memcpy(comp_buf, mapped, (size_t)file_len);
        } else if (comp_buf && mapped) {
            comp_len = ttzip_compress_buffer(codec, mapped, (size_t)file_len, comp_buf, max_comp_len, level);
            if (comp_len == 0 || comp_len >= file_len) {
                /* Fallback to store if compression expanded */
                memcpy(comp_buf, mapped, (size_t)file_len);
                comp_len = (size_t)file_len;
            }
        }

        /* Write Local File Header */
        const char *base_name = strrchr(src_path, '/');
#if defined(_WIN32)
        if (!base_name) base_name = strrchr(src_path, '\\');
#endif
        base_name = base_name ? base_name + 1 : src_path;

        ttzip_zip_entry_meta_t meta;
        memset(&meta, 0, sizeof(meta));
        meta.file_name = base_name;
        meta.file_name_len = (uint16_t)strlen(base_name);
        meta.crc32 = file_crc;
        meta.compressed_size = comp_len;
        meta.uncompressed_size = file_len;
        meta.local_header_offset = current_file_offset;
        meta.compression_method = (comp_len == file_len && codec != TTZIP_API_CODEC_STORE) ? 0 : (codec == TTZIP_API_CODEC_DEFLATE ? 8 : 0);
        meta.dos_datetime = 0x58210000;
        meta.external_attributes = 0x81a40000;
        meta.is_utf8 = true;

        uint8_t local_hdr[1024];
        size_t local_hdr_len = ttzip_zip_write_local_header(&meta, local_hdr, sizeof(local_hdr));
        fwrite(local_hdr, 1, local_hdr_len, out_fp);

        if (comp_len > 0 && comp_buf) {
            fwrite(comp_buf, 1, comp_len, out_fp);
        }

        records[i].offset = current_file_offset;
        records[i].crc32 = file_crc;
        records[i].compressed_size = comp_len;
        records[i].uncompressed_size = file_len;
        strncpy(records[i].path, base_name, sizeof(records[i].path) - 1);
        records[i].path[sizeof(records[i].path) - 1] = '\0';

        current_file_offset += local_hdr_len + comp_len;
        total_processed += file_len;

        if (mapped) ttzip_fs_munmap(mapped, file_len);
        if (comp_buf) free(comp_buf);

        if (progress_cb) {
            progress_cb(total_processed, total_processed, base_name, user_data);
        }
    }

    /* Write Central Directory */
    uint64_t cd_start_offset = current_file_offset;
    uint32_t cd_size = 0;

    for (size_t i = 0; i < input_count; i++) {
        ttzip_zip_entry_meta_t meta;
        memset(&meta, 0, sizeof(meta));
        meta.file_name = records[i].path;
        meta.file_name_len = (uint16_t)strlen(records[i].path);
        meta.crc32 = records[i].crc32;
        meta.compressed_size = records[i].compressed_size;
        meta.uncompressed_size = records[i].uncompressed_size;
        meta.local_header_offset = records[i].offset;
        meta.compression_method = (records[i].compressed_size == records[i].uncompressed_size && codec != TTZIP_API_CODEC_STORE) ? 0 : (codec == TTZIP_API_CODEC_DEFLATE ? 8 : 0);
        meta.dos_datetime = 0x58210000;
        meta.external_attributes = 0x81a40000;
        meta.is_utf8 = true;

        uint8_t cd_hdr[1024];
        size_t cd_hdr_len = ttzip_zip_write_cd_header(&meta, cd_hdr, sizeof(cd_hdr));
        fwrite(cd_hdr, 1, cd_hdr_len, out_fp);
        cd_size += (uint32_t)cd_hdr_len;
    }

    /* Write EOCD */
    uint8_t eocd_buf[64];
    size_t eocd_len = ttzip_zip_write_eocd((uint16_t)input_count, cd_size, (uint32_t)cd_start_offset, eocd_buf, sizeof(eocd_buf));
    fwrite(eocd_buf, 1, eocd_len, out_fp);

    free(records);
    fclose(out_fp);
    return TTZIP_API_OK;
}

int ttzip_archive_extract(
    const char *archive_path,
    const char *destination_dir,
    const char *password,
    ttzip_progress_fn progress_cb,
    void *user_data
) {
    if (!archive_path || !destination_dir) return TTZIP_API_ERR_INVALID_PARAM;
    (void)password;
    (void)progress_cb;
    (void)user_data;
    return ttzip_extract_zip_c_parallel(archive_path, destination_dir);
}

int ttzip_archive_extract_entry_mem(
    const char *archive_path,
    size_t entry_index,
    void *out_buf,
    size_t out_cap,
    size_t *out_decomp_size
) {
    if (!archive_path || !out_buf || out_cap == 0) return TTZIP_API_ERR_INVALID_PARAM;

    uint64_t len = 0;
    const void *mapped = ttzip_fs_mmap_read(archive_path, &len);
    if (!mapped) return TTZIP_API_ERR_IO_FAILURE;

    if (len < 30) {
        ttzip_fs_munmap(mapped, len);
        return TTZIP_API_ERR_CORRUPT_DATA;
    }

    const uint8_t *p = (const uint8_t *)mapped;
    size_t curr_idx = 0;
    size_t offset = 0;

    while (offset + 30 <= len) {
        if (p[offset] != 'P' || p[offset + 1] != 'K' || p[offset + 2] != 0x03 || p[offset + 3] != 0x04) {
            break;
        }

        uint16_t method = p[offset + 8] | (p[offset + 9] << 8);
        uint32_t comp_size = p[offset + 18] | (p[offset + 19] << 8) | (p[offset + 20] << 16) | (p[offset + 21] << 24);
        uint32_t uncomp_size = p[offset + 22] | (p[offset + 23] << 8) | (p[offset + 24] << 16) | (p[offset + 25] << 24);
        uint16_t name_len = p[offset + 26] | (p[offset + 27] << 8);
        uint16_t extra_len = p[offset + 28] | (p[offset + 29] << 8);

        size_t data_offset = offset + 30 + name_len + extra_len;
        if (data_offset + comp_size > len) break;

        if (curr_idx == entry_index) {
            size_t written = 0;
            if (method == 0) { // Store
                written = comp_size > out_cap ? out_cap : comp_size;
                memcpy(out_buf, p + data_offset, written);
            } else if (method == 8) { // Deflate
                written = ttzip_decompress_buffer(TTZIP_API_CODEC_DEFLATE, p + data_offset, comp_size, out_buf, out_cap);
            }
            if (out_decomp_size) *out_decomp_size = written;
            ttzip_fs_munmap(mapped, len);
            return (written > 0 || uncomp_size == 0) ? TTZIP_API_OK : TTZIP_API_ERR_CORRUPT_DATA;
        }

        curr_idx++;
        offset = data_offset + comp_size;
    }

    ttzip_fs_munmap(mapped, len);
    return TTZIP_API_ERR_INVALID_PARAM;
}

int ttzip_archive_list(
    const char *archive_path,
    const char *password,
    ttzip_entry_fn entry_cb,
    void *user_data
) {
    if (!archive_path) return TTZIP_API_ERR_INVALID_PARAM;
    (void)password;
    (void)entry_cb;
    (void)user_data;
    return TTZIP_API_OK;
}

int ttzip_archive_test(
    const char *archive_path,
    const char *password
) {
    if (!archive_path) return TTZIP_API_ERR_INVALID_PARAM;
    (void)password;
    uint64_t len = 0;
    const void *mapped = ttzip_fs_mmap_read(archive_path, &len);
    if (!mapped && len > 0) return TTZIP_API_ERR_IO_FAILURE;
    if (len < 22) {
        if (mapped) ttzip_fs_munmap(mapped, len);
        return TTZIP_API_ERR_CORRUPT_DATA;
    }
    if (mapped) ttzip_fs_munmap(mapped, len);
    return TTZIP_API_OK;
}

int ttzip_archive_inspect(
    const char *archive_path,
    const char *password,
    ttzip_archive_report_t *out_report
) {
    if (!archive_path || !out_report) return TTZIP_API_ERR_INVALID_PARAM;
    (void)password;

    memset(out_report, 0, sizeof(ttzip_archive_report_t));

    uint64_t len = 0;
    const void *mapped = ttzip_fs_mmap_read(archive_path, &len);
    if (!mapped) return TTZIP_API_ERR_IO_FAILURE;

    ttzip_magic_info_t magic = ttzip_magic_sniff_buffer(mapped, (size_t)len);
    strncpy(out_report->detected_format, magic.format_name, sizeof(out_report->detected_format) - 1);

    out_report->total_compressed_bytes = len;
    out_report->total_uncompressed_bytes = len; /* Default fallback */

    /* Quick scan for ZIP Local File Headers */
    const uint8_t *p = (const uint8_t *)mapped;
    size_t offset = 0;
    uint64_t total_uncomp = 0;
    uint64_t total_comp = 0;
    uint64_t count = 0;

    while (offset + 30 <= len) {
        if (p[offset] == 'P' && p[offset + 1] == 'K' && p[offset + 2] == 0x03 && p[offset + 3] == 0x04) {
            uint32_t csz = p[offset + 18] | (p[offset + 19] << 8) | (p[offset + 20] << 16) | (p[offset + 21] << 24);
            uint32_t usz = p[offset + 22] | (p[offset + 23] << 8) | (p[offset + 24] << 16) | (p[offset + 25] << 24);
            uint16_t nlen = p[offset + 26] | (p[offset + 27] << 8);
            uint16_t xlen = p[offset + 28] | (p[offset + 29] << 8);

            total_comp += csz;
            total_uncomp += usz;
            count++;

            offset += 30 + nlen + xlen + csz;
        } else {
            break;
        }
    }

    if (count > 0) {
        out_report->total_entries = count;
        out_report->total_uncompressed_bytes = total_uncomp;
        out_report->total_compressed_bytes = total_comp;
        out_report->compression_ratio = total_uncomp > 0 ? ((double)total_comp / (double)total_uncomp * 100.0) : 100.0;
    }

    ttzip_fs_munmap(mapped, len);
    return TTZIP_API_OK;
}
