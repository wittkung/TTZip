// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine.

#include "include/CTTZip7zStoreInternal.h"
#include "include/ttzip_7z_header_writer.h"
#include "include/CTTZipBridge.h"
#include "include/CTTZipCoreArchitecture.h"
#include "include/CTTZipBridge_Archive.h"
#include "include/ttzip_threadpool.h"
#include "include/ttzip_platform.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <fcntl.h>

#if defined(TTZIP_OS_WINDOWS)
#include <io.h>
#else
#include <unistd.h>
#endif

typedef struct {
    ttzip_7z_store_list_t* list;
    uint8_t*               solid_buf;
    uint64_t*              file_offsets;
} solid_read_ctx_t;

static void solid_file_read_worker(size_t i, void* user_data) {
    solid_read_ctx_t* ctx = (solid_read_ctx_t*)user_data;
    ttzip_7z_store_entry_t* item = &ctx->list->entries[i];
    if (item->is_directory || item->file_size == 0) {
        return;
    }
    
    int in_fd = open(item->src_path, O_RDONLY);
    if (in_fd >= 0) {
        size_t bytes_to_read = (size_t)item->file_size;
        uint8_t* dest_ptr = ctx->solid_buf + ctx->file_offsets[i];
#if defined(TTZIP_OS_WINDOWS)
        int rd = _read(in_fd, dest_ptr, (unsigned int)bytes_to_read);
#else
        ssize_t rd = pread(in_fd, dest_ptr, bytes_to_read, 0);
#endif
        close(in_fd);
        if (rd == (ssize_t)bytes_to_read) {
            item->crc32 = ttzip_compute_buffer_crc32_neon(0, dest_ptr, bytes_to_read);
        }
    }
}

int ttzip_create_7z_solid_fast_c(
    const char* output_path,
    const char* const* input_paths,
    size_t input_count,
    int level
) {
    if (!output_path || !input_paths || input_count == 0) {
        return TTZIP_ERR_INVALID_PARAM;
    }

    ttzip_7z_store_list_t list = {NULL, 0, 0};
    for (size_t i = 0; i < input_count; i++) {
        if (!input_paths[i]) continue;
        const char* base = strrchr(input_paths[i], '/');
        base = base ? base + 1 : input_paths[i];
        ttzip_7z_collect_recursive(input_paths[i], base, &list);
    }
    if (list.count == 0) {
        free(list.entries);
        return TTZIP_ERR_INVALID_PARAM;
    }

    size_t num_files = list.count;
    uint64_t total_uncompressed_bytes = 0;
    size_t num_streams = 0;
    size_t num_empty_streams = 0;
    size_t num_empty_files = 0;

    for (size_t i = 0; i < num_files; i++) {
        if (!list.entries[i].is_directory && list.entries[i].file_size > 0) {
            total_uncompressed_bytes += list.entries[i].file_size;
            num_streams++;
        } else {
            num_empty_streams++;
            if (!list.entries[i].is_directory && list.entries[i].file_size == 0) {
                num_empty_files++;
            }
        }
    }

    uint8_t* solid_buf = NULL;
    if (total_uncompressed_bytes > 0) {
        solid_buf = (uint8_t*)ttzip_platform_aligned_alloc(64, total_uncompressed_bytes);
        if (!solid_buf) {
            free(list.entries);
            return TTZIP_ERR_INVALID_PARAM;
        }
    }

    uint64_t* file_offsets = (uint64_t*)malloc(sizeof(uint64_t) * num_files);
    if (!file_offsets) {
        if (solid_buf) ttzip_platform_aligned_free(solid_buf);
        free(list.entries);
        return TTZIP_ERR_OUT_OF_MEMORY;
    }

    uint64_t running_offset = 0;
    for (size_t i = 0; i < num_files; i++) {
        ttzip_7z_store_entry_t* item = &list.entries[i];
        if (item->is_directory || item->file_size == 0) {
            item->crc32 = 0;
            file_offsets[i] = running_offset;
        } else {
            file_offsets[i] = running_offset;
            running_offset += (uint64_t)item->file_size;
        }
    }

    solid_read_ctx_t read_ctx = {
        .list = &list,
        .solid_buf = solid_buf,
        .file_offsets = file_offsets
    };

    if (num_files <= 128 || total_uncompressed_bytes <= 16 * 1024 * 1024) {
        for (size_t i = 0; i < num_files; i++) {
            solid_file_read_worker(i, &read_ctx);
        }
    } else {
        ttzip_parallel_for(ttzip_threadpool_shared(), num_files, solid_file_read_worker, &read_ctx);
    }

    free(file_offsets);

    size_t compressed_capacity = (size_t)(total_uncompressed_bytes * 1.1) + 128 * 1024;
    if (compressed_capacity < 64 * 1024) compressed_capacity = 64 * 1024;
    uint8_t* compressed_buf = (uint8_t*)ttzip_platform_aligned_alloc(64, compressed_capacity);
    if (!compressed_buf) {
        if (solid_buf) ttzip_platform_aligned_free(solid_buf);
        free(list.entries);
        return TTZIP_ERR_INVALID_PARAM;
    }

    size_t compressed_len = 0;
    int c_res = ttzip_lzma2_compress_mt_c(
        solid_buf,
        total_uncompressed_bytes,
        compressed_buf,
        compressed_capacity,
        &compressed_len,
        level
    );

    if (solid_buf) {
        ttzip_platform_aligned_free(solid_buf);
        solid_buf = NULL;
    }

    if (c_res != 0 || compressed_len == 0) {
        ttzip_platform_aligned_free(compressed_buf);
        free(list.entries);
        return TTZIP_ERR_ARCHIVE_INIT_FAILED;
    }

    int out_fd = open(output_path, O_CREAT | O_TRUNC | O_RDWR, 0644);
    if (out_fd < 0) {
        ttzip_platform_aligned_free(compressed_buf);
        free(list.entries);
        return TTZIP_ERR_OPEN_FAILED;
    }

    uint8_t sig_header[32] = {0};
    sig_header[0] = 0x37; sig_header[1] = 0x7A; sig_header[2] = 0xBC; sig_header[3] = 0xAF;
    sig_header[4] = 0x27; sig_header[5] = 0x1C;
    sig_header[6] = 0x00; sig_header[7] = 0x04;
    ttzip_7z_write_all(out_fd, sig_header, 32);

    ttzip_7z_write_all(out_fd, compressed_buf, compressed_len);
    ttzip_platform_aligned_free(compressed_buf);

    ttzip_7z_header_params_t params = {
        .level = level,
        .has_password = false,
        .num_cycles_power = 0,
        .aes_iv = NULL,
        .packed_stream_size = compressed_len,
        .total_uncompressed_bytes = total_uncompressed_bytes,
        .total_compressed_len = compressed_len,
        .max_dict_size = 64 * 1024 * 1024,
        .num_streams = num_streams,
        .num_empty_streams = num_empty_streams,
        .num_empty_files = num_empty_files
    };

    int res = ttzip_7z_write_metadata_and_flush(out_fd, &list, &params);
    free(list.entries);
    return res;
}
