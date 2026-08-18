// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/CTTZip7zStoreInternal.h"
#include "include/CTTZipBridge.h"
#include "include/CTTZipCoreArchitecture.h"
#include "include/CTTZipBridge_Archive.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <arm_neon.h>
#include <dispatch/dispatch.h>

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
        if (posix_memalign((void**)&solid_buf, 64, total_uncompressed_bytes) != 0 || !solid_buf) {
            free(list.entries);
            return TTZIP_ERR_INVALID_PARAM;
        }
    }

    uint64_t* file_offsets = (uint64_t*)malloc(sizeof(uint64_t) * num_files);
    if (!file_offsets) {
        if (solid_buf) free(solid_buf);
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

    if (num_files <= 128 || total_uncompressed_bytes <= 16 * 1024 * 1024) {
        for (size_t i = 0; i < num_files; i++) {
            ttzip_7z_store_entry_t* item = &list.entries[i];
            if (item->is_directory || item->file_size == 0) {
                continue;
            }
            int in_fd = open(item->src_path, O_RDONLY);
            if (in_fd >= 0) {
                size_t bytes_to_read = (size_t)item->file_size;
                uint8_t* dest_ptr = solid_buf + file_offsets[i];
                ssize_t rd = read(in_fd, dest_ptr, bytes_to_read);
                close(in_fd);
                if (rd == (ssize_t)bytes_to_read) {
                    item->crc32 = ttzip_compute_buffer_crc32_neon(0, dest_ptr, bytes_to_read);
                }
            }
        }
    } else {
        dispatch_semaphore_t fd_sem = dispatch_semaphore_create(256);
        dispatch_apply(num_files, dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^(size_t i) {
            ttzip_7z_store_entry_t* item = &list.entries[i];
            if (item->is_directory || item->file_size == 0) {
                return;
            }
            dispatch_semaphore_wait(fd_sem, DISPATCH_TIME_FOREVER);
            int in_fd = open(item->src_path, O_RDONLY);
            if (in_fd >= 0) {
                size_t bytes_to_read = (size_t)item->file_size;
                uint8_t* dest_ptr = solid_buf + file_offsets[i];
                ssize_t rd = pread(in_fd, dest_ptr, bytes_to_read, 0);
                close(in_fd);
                if (rd == (ssize_t)bytes_to_read) {
                    item->crc32 = ttzip_compute_buffer_crc32_neon(0, dest_ptr, bytes_to_read);
                }
            }
            dispatch_semaphore_signal(fd_sem);
        });
    }

    free(file_offsets);

    size_t compressed_capacity = (size_t)(total_uncompressed_bytes * 1.1) + 128 * 1024;
    if (compressed_capacity < 64 * 1024) compressed_capacity = 64 * 1024;
    uint8_t* compressed_buf = NULL;
    if (posix_memalign((void**)&compressed_buf, 64, compressed_capacity) != 0 || !compressed_buf) {
        if (solid_buf) free(solid_buf);
        free(list.entries);
        return TTZIP_ERR_INVALID_PARAM;
    }

    size_t compressed_len = 0;
    int c_res = ttzip_lzma2_compress_mt_c(
        solid_buf,
        (size_t)total_uncompressed_bytes,
        compressed_buf,
        compressed_capacity,
        &compressed_len,
        level
    );

    if (c_res != 0) {
        if (solid_buf) free(solid_buf);
        free(compressed_buf);
        free(list.entries);
        return TTZIP_ERR_OPEN_FAILED;
    }
    if (solid_buf) free(solid_buf);

    unlink(output_path);
    int out_fd = open(output_path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (out_fd < 0) {
        free(compressed_buf);
        free(list.entries);
        return TTZIP_ERR_OPEN_FAILED;
    }

    uint8_t sig_header[32] = {
        0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C,
        0x00, 0x04,
        0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0
    };
    ttzip_7z_write_all(out_fd, sig_header, 32);
    if (compressed_len > 0) {
        ttzip_7z_write_all(out_fd, compressed_buf, compressed_len);
    }
    free(compressed_buf);

    size_t total_names_len = 0;
    for (size_t i = 0; i < list.count; i++) {
        if (list.entries[i].rel_path[0] != '\0') total_names_len += strlen(list.entries[i].rel_path);
    }
    size_t header_cap = 1024 * 1024 + num_files * 512 + total_names_len * 4;
    uint8_t* header_buf = (uint8_t*)malloc(header_cap);
    if (!header_buf) {
        close(out_fd);
        free(list.entries);
        return TTZIP_ERR_INVALID_PARAM;
    }
    size_t h_idx = 0;

    header_buf[h_idx++] = 0x01; // kHeader
    header_buf[h_idx++] = 0x04; // kMainStreamsInfo
    header_buf[h_idx++] = 0x06; // kPackInfo
    h_idx += ttzip_7z_write_varint(header_buf + h_idx, 0); // PackPos = 0
    h_idx += ttzip_7z_write_varint(header_buf + h_idx, 1); // NumPackStreams = 1
    header_buf[h_idx++] = 0x09; // kSize
    h_idx += ttzip_7z_write_varint(header_buf + h_idx, compressed_len);
    header_buf[h_idx++] = 0x00; // End PackInfo

    header_buf[h_idx++] = 0x07; // kUnpackInfo
    header_buf[h_idx++] = 0x0B; // kFolder
    h_idx += ttzip_7z_write_varint(header_buf + h_idx, 1); // NumFolders = 1
    header_buf[h_idx++] = 0x00; // External = 0

    header_buf[h_idx++] = 0x01; // NumCoders = 1
    header_buf[h_idx++] = 0x21; // Coder flags: ID size 1, Complex = 0, Attributes = 1
    header_buf[h_idx++] = 0x21; // LZMA2 Method ID (0x21)
    header_buf[h_idx++] = 0x01; // Attributes size = 1
    header_buf[h_idx++] = 0x1C; // Dictionary size prop (16MB)

    header_buf[h_idx++] = 0x0C; // kCodersUnpackSize
    h_idx += ttzip_7z_write_varint(header_buf + h_idx, total_uncompressed_bytes);
    header_buf[h_idx++] = 0x00; // End UnpackInfo

    if (num_streams > 1) {
        header_buf[h_idx++] = 0x0A; // kSubStreamsInfo
        header_buf[h_idx++] = 0x08; // kNumUnpackStream
        h_idx += ttzip_7z_write_varint(header_buf + h_idx, num_streams);

        header_buf[h_idx++] = 0x09; // kSize
        size_t written_stream_count = 0;
        for (size_t i = 0; i < num_files; i++) {
            if (!list.entries[i].is_directory && list.entries[i].file_size > 0) {
                written_stream_count++;
                if (written_stream_count < num_streams) {
                    h_idx += ttzip_7z_write_varint(header_buf + h_idx, list.entries[i].file_size);
                }
            }
        }

        header_buf[h_idx++] = 0x0A; // kCRC
        header_buf[h_idx++] = 0x01; // AllAreDefined = 1
        for (size_t i = 0; i < num_files; i++) {
            if (!list.entries[i].is_directory && list.entries[i].file_size > 0) {
                uint32_t c = list.entries[i].crc32;
                memcpy(header_buf + h_idx, &c, 4);
                h_idx += 4;
            }
        }
        header_buf[h_idx++] = 0x00; // End SubStreamsInfo
    } else if (num_streams == 1) {
        header_buf[h_idx++] = 0x0A; // kSubStreamsInfo
        header_buf[h_idx++] = 0x0A; // kCRC
        header_buf[h_idx++] = 0x01; // AllAreDefined = 1
        for (size_t i = 0; i < num_files; i++) {
            if (!list.entries[i].is_directory && list.entries[i].file_size > 0) {
                uint32_t c = list.entries[i].crc32;
                memcpy(header_buf + h_idx, &c, 4);
                h_idx += 4;
            }
        }
        header_buf[h_idx++] = 0x00; // End SubStreamsInfo
    }
    header_buf[h_idx++] = 0x00; // End MainStreamsInfo

    header_buf[h_idx++] = 0x05; // kFilesInfo
    h_idx += ttzip_7z_write_varint(header_buf + h_idx, num_files);

    if (num_empty_streams > 0) {
        header_buf[h_idx++] = 0x0E; // kEmptyStream
        size_t empty_stream_bytes = (num_files + 7) / 8;
        h_idx += ttzip_7z_write_varint(header_buf + h_idx, empty_stream_bytes);
        memset(header_buf + h_idx, 0, empty_stream_bytes);
        size_t empty_idx = 0;
        for (size_t i = 0; i < num_files; i++) {
            if (list.entries[i].is_directory || list.entries[i].file_size == 0) {
                header_buf[h_idx + empty_idx / 8] |= (1 << (7 - (empty_idx % 8)));
            }
            empty_idx++;
        }
        h_idx += empty_stream_bytes;

        if (num_empty_files > 0) {
            header_buf[h_idx++] = 0x0F; // kEmptyFile
            size_t empty_file_bytes = (num_empty_streams + 7) / 8;
            h_idx += ttzip_7z_write_varint(header_buf + h_idx, empty_file_bytes);
            memset(header_buf + h_idx, 0, empty_file_bytes);
            size_t empty_idx = 0;
            for (size_t i = 0; i < num_files; i++) {
                if (list.entries[i].is_directory || list.entries[i].file_size == 0) {
                    if (!list.entries[i].is_directory && list.entries[i].file_size == 0) {
                        header_buf[h_idx + empty_idx / 8] |= (1 << (7 - (empty_idx % 8)));
                    }
                    empty_idx++;
                }
            }
            h_idx += empty_file_bytes;
        }
    }

    header_buf[h_idx++] = 0x11; // kName
    size_t name_data_len = 1;
    for (size_t i = 0; i < list.count; i++) {
        name_data_len += (strlen(list.entries[i].rel_path) + 1) * 2;
    }
    h_idx += ttzip_7z_write_varint(header_buf + h_idx, name_data_len);
    header_buf[h_idx++] = 0x00;
    for (size_t i = 0; i < list.count; i++) {
        const char* rpath = list.entries[i].rel_path;
        size_t rlen = strlen(rpath);
        for (size_t j = 0; j < rlen; j++) {
            uint16_t u16 = (uint16_t)(uint8_t)rpath[j];
            memcpy(header_buf + h_idx, &u16, 2);
            h_idx += 2;
        }
        uint16_t zero = 0;
        memcpy(header_buf + h_idx, &zero, 2);
        h_idx += 2;
    }

    header_buf[h_idx++] = 0x00; // End FilesInfo
    header_buf[h_idx++] = 0x00; // End Header

    uint32_t header_crc = ttzip_compute_buffer_crc32_neon(0, header_buf, h_idx);
    ttzip_7z_write_all(out_fd, header_buf, h_idx);
    free(header_buf);
    free(list.entries);

    uint64_t header_size = h_idx;
    uint64_t next_header_offset = compressed_len;

    uint8_t updated_header[32] = {
        0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C,
        0x00, 0x04,
        0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0
    };

    uint32_t sig_crc = ttzip_compute_buffer_crc32_neon(0, updated_header + 12, 20);
    memcpy(updated_header + 8, &sig_crc, 4);

    memcpy(updated_header + 12, &next_header_offset, 8);
    memcpy(updated_header + 20, &header_size, 8);
    memcpy(updated_header + 28, &header_crc, 4);

    sig_crc = ttzip_compute_buffer_crc32_neon(0, updated_header + 12, 20);
    memcpy(updated_header + 8, &sig_crc, 4);

    lseek(out_fd, 0, SEEK_SET);
    ttzip_7z_write_all(out_fd, updated_header, 32);
    close(out_fd);

    return TTZIP_OK;
}
