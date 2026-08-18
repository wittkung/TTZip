// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/CTTZipZipWriteInternal.h"
#include "include/CTTZipCoreArchitecture.h"

#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/stat.h>

static ssize_t pwrite_all(int fd, const void* buf, size_t count, off_t offset) {
    size_t written = 0;
    const char* ptr = (const char*)buf;
    while (written < count) {
        ssize_t res = pwrite(fd, ptr + written, count - written, offset + (off_t)written);
        if (res <= 0) {
            if (res < 0 && (errno == EINTR || errno == EAGAIN)) continue;
            return -1;
        }
        written += (size_t)res;
    }
    return (ssize_t)written;
}

int ttzip_write_zip_archive_disk(const char* output_zip_path, ttzip_c_item_list_t* list_ptr, bool has_password) {
    ttzip_c_item_list_t list = *list_ptr;
    int out_fd = open(output_zip_path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (out_fd < 0) {
        return TTZIP_ERR_OPEN_FAILED;
    }

    uint64_t total_payload_bytes = 0;
    for (size_t i = 0; i < list.count; i++) {
        total_payload_bytes += (uint64_t)list.items[i].compressed_size + 30 + strlen(list.items[i].rel_path);
    }

    if (total_payload_bytes >= 64 * 1024 * 1024) {
        fcntl(out_fd, F_NOCACHE, 1);
    }

    size_t alloc_cap = (size_t)(total_payload_bytes + list.count * 128 + 4096);
    uint8_t stack_out_mem[131072];
    uint8_t* out_mem = (alloc_cap <= sizeof(stack_out_mem)) ? stack_out_mem : ((alloc_cap <= 16 * 1024 * 1024) ? (uint8_t*)malloc(alloc_cap) : NULL);

    if (out_mem) {
        uint64_t stack_offsets[64];
        uint64_t* offsets = (list.count <= 64) ? stack_offsets : (uint64_t*)malloc(list.count * sizeof(uint64_t));
        if (!offsets) {
            if (out_mem != stack_out_mem) free(out_mem);
            close(out_fd);
            return TTZIP_ERR_OUT_OF_MEMORY;
        }
        uint64_t current_offset = 0;

        for (size_t i = 0; i < list.count; i++) {
            ttzip_c_item_t* item = &list.items[i];
            offsets[i] = current_offset;

            uint16_t filename_len = (uint16_t)strlen(item->rel_path);
            bool needs_z64 = (item->uncompressed_size >= 0xFFFFFFFF || item->compressed_size >= 0xFFFFFFFF || current_offset >= 0xFFFFFFFF);
            uint16_t extra_field_len = (has_password ? 11 : 0) + (needs_z64 ? 20 : 0);
            uint8_t* ptr = out_mem + current_offset;

            write_u32_le(ptr + 0, 0x04034b50);
            write_u16_le(ptr + 4, needs_z64 ? 45 : (has_password ? 51 : 20));
            write_u16_le(ptr + 6, (has_password ? 0x0001 : 0x0000) | 0x0800); // Bit 11 UTF-8
            write_u16_le(ptr + 8, has_password ? 99 : item->actual_method);
            write_u16_le(ptr + 10, 0);
            write_u16_le(ptr + 12, 0x5421);
            write_u32_le(ptr + 14, item->crc32);
            write_u32_le(ptr + 18, needs_z64 ? 0xFFFFFFFF : (uint32_t)item->compressed_size);
            write_u32_le(ptr + 22, needs_z64 ? 0xFFFFFFFF : (uint32_t)item->uncompressed_size);
            write_u16_le(ptr + 26, filename_len);
            write_u16_le(ptr + 28, extra_field_len);
            current_offset += 30;

            memcpy(out_mem + current_offset, item->rel_path, filename_len);
            current_offset += filename_len;

            if (needs_z64) {
                uint8_t* z64_ptr = out_mem + current_offset;
                write_u16_le(z64_ptr + 0, 0x0001);
                write_u16_le(z64_ptr + 2, 16);
                write_u64_le(z64_ptr + 4, (uint64_t)item->uncompressed_size);
                write_u64_le(z64_ptr + 12, (uint64_t)item->compressed_size);
                current_offset += 20;
            }

            if (has_password) {
                uint8_t* aes_ptr = out_mem + current_offset;
                write_u16_le(aes_ptr + 0, 0x9901);
                write_u16_le(aes_ptr + 2, 7);
                write_u16_le(aes_ptr + 4, 0x0002);
                aes_ptr[6] = 'A'; aes_ptr[7] = 'E'; aes_ptr[8] = 0x03;
                write_u16_le(aes_ptr + 9, item->actual_method);
                current_offset += 11;
            }

            if (item->compressed_payload && item->compressed_size > 0) {
                memcpy(out_mem + current_offset, item->compressed_payload, (size_t)item->compressed_size);
                current_offset += (uint64_t)item->compressed_size;
            } else if (item->uncompressed_size > 0 && !item->is_directory) {
                int in_fd = open(item->src_path, O_RDONLY);
                if (in_fd >= 0) {
                    pread(in_fd, out_mem + current_offset, (size_t)item->uncompressed_size, 0);
                    close(in_fd);
                }
                current_offset += (uint64_t)item->uncompressed_size;
            }
        }

        uint64_t cd_start_offset = current_offset;
        for (size_t i = 0; i < list.count; i++) {
            ttzip_c_item_t* item = &list.items[i];
            uint16_t filename_len = (uint16_t)strlen(item->rel_path);
            bool needs_z64 = (item->uncompressed_size >= 0xFFFFFFFF || item->compressed_size >= 0xFFFFFFFF || offsets[i] >= 0xFFFFFFFF);
            uint16_t extra_field_len = (has_password ? 11 : 0) + (needs_z64 ? 28 : 0);
            uint8_t* cd_ptr = out_mem + current_offset;

            write_u32_le(cd_ptr + 0, 0x02014b50);
            write_u16_le(cd_ptr + 4, needs_z64 ? 45 : 63);
            write_u16_le(cd_ptr + 6, needs_z64 ? 45 : (has_password ? 51 : 20));
            write_u16_le(cd_ptr + 8, (has_password ? 0x0001 : 0x0000) | 0x0800); // Bit 11 UTF-8
            write_u16_le(cd_ptr + 10, has_password ? 99 : item->actual_method);
            write_u16_le(cd_ptr + 12, 0);
            write_u16_le(cd_ptr + 14, 0x5421);
            write_u32_le(cd_ptr + 16, item->crc32);
            write_u32_le(cd_ptr + 20, needs_z64 ? 0xFFFFFFFF : (uint32_t)item->compressed_size);
            write_u32_le(cd_ptr + 24, needs_z64 ? 0xFFFFFFFF : (uint32_t)item->uncompressed_size);
            write_u16_le(cd_ptr + 28, filename_len);
            write_u16_le(cd_ptr + 30, extra_field_len);
            write_u16_le(cd_ptr + 32, 0);
            write_u16_le(cd_ptr + 34, 0);
            write_u16_le(cd_ptr + 36, 0);
            write_u32_le(cd_ptr + 38, item->is_directory ? (0040755u << 16 | 0x10u) : (0100644u << 16 | 0x20u));
            write_u32_le(cd_ptr + 42, needs_z64 ? 0xFFFFFFFF : (uint32_t)offsets[i]);
            current_offset += 46;

            memcpy(out_mem + current_offset, item->rel_path, filename_len);
            current_offset += filename_len;

            if (needs_z64) {
                uint8_t* z64_ptr = out_mem + current_offset;
                write_u16_le(z64_ptr + 0, 0x0001);
                write_u16_le(z64_ptr + 2, 24);
                write_u64_le(z64_ptr + 4, (uint64_t)item->uncompressed_size);
                write_u64_le(z64_ptr + 12, (uint64_t)item->compressed_size);
                write_u64_le(z64_ptr + 20, (uint64_t)offsets[i]);
                current_offset += 28;
            }

            if (has_password) {
                uint8_t* aes_ptr = out_mem + current_offset;
                write_u16_le(aes_ptr + 0, 0x9901);
                write_u16_le(aes_ptr + 2, 7);
                write_u16_le(aes_ptr + 4, 0x0002);
                aes_ptr[6] = 'A'; aes_ptr[7] = 'E'; aes_ptr[8] = 0x03;
                write_u16_le(aes_ptr + 9, item->actual_method);
                current_offset += 11;
            }
        }

        uint64_t cd_size = current_offset - cd_start_offset;
        bool global_z64 = (cd_start_offset >= 0xFFFFFFFF || cd_size >= 0xFFFFFFFF || list.count >= 0xFFFF);

        if (global_z64) {
            uint64_t z64_eocd_off = current_offset;
            uint8_t* z64_eocd = out_mem + current_offset;
            write_u32_le(z64_eocd + 0, 0x06064b50);
            write_u64_le(z64_eocd + 4, 44);
            write_u16_le(z64_eocd + 12, 45);
            write_u16_le(z64_eocd + 14, 45);
            write_u32_le(z64_eocd + 16, 0);
            write_u32_le(z64_eocd + 20, 0);
            write_u64_le(z64_eocd + 24, (uint64_t)list.count);
            write_u64_le(z64_eocd + 32, (uint64_t)list.count);
            write_u64_le(z64_eocd + 40, cd_size);
            write_u64_le(z64_eocd + 48, cd_start_offset);
            current_offset += 56;

            uint8_t* z64_loc = out_mem + current_offset;
            write_u32_le(z64_loc + 0, 0x07064b50);
            write_u32_le(z64_loc + 4, 0);
            write_u64_le(z64_loc + 8, z64_eocd_off);
            write_u32_le(z64_loc + 16, 1);
            current_offset += 20;
        }

        uint8_t* eocd_ptr = out_mem + current_offset;
        write_u32_le(eocd_ptr + 0, 0x06054b50);
        write_u16_le(eocd_ptr + 4, 0);
        write_u16_le(eocd_ptr + 6, 0);
        write_u16_le(eocd_ptr + 8, global_z64 ? 0xFFFF : (uint16_t)list.count);
        write_u16_le(eocd_ptr + 10, global_z64 ? 0xFFFF : (uint16_t)list.count);
        write_u32_le(eocd_ptr + 12, global_z64 ? 0xFFFFFFFF : (uint32_t)cd_size);
        write_u32_le(eocd_ptr + 16, global_z64 ? 0xFFFFFFFF : (uint32_t)cd_start_offset);
        write_u16_le(eocd_ptr + 20, 0);
        current_offset += 22;

        pwrite_all(out_fd, out_mem, (size_t)current_offset, 0);

        if (out_mem != stack_out_mem) free(out_mem);
        if (offsets != stack_offsets) free(offsets);
        close(out_fd);
        return TTZIP_OK;
    }

    if (total_payload_bytes >= 10 * 1024 * 1024) {
        ttzip_common_apfs_preallocate(out_fd, (int64_t)(total_payload_bytes + list.count * 128));
    }

    uint64_t* offsets = (uint64_t*)malloc(list.count * sizeof(uint64_t));
    if (!offsets) {
        close(out_fd);
        return TTZIP_ERR_OUT_OF_MEMORY;
    }
    uint64_t current_offset = 0;

    for (size_t i = 0; i < list.count; i++) {
        ttzip_c_item_t* item = &list.items[i];
        offsets[i] = current_offset;

        uint16_t filename_len = (uint16_t)strlen(item->rel_path);
        bool needs_z64 = (item->uncompressed_size >= 0xFFFFFFFF || item->compressed_size >= 0xFFFFFFFF || current_offset >= 0xFFFFFFFF);
        uint16_t extra_field_len = (has_password ? 11 : 0) + (needs_z64 ? 20 : 0);
        uint8_t local_header[30];

        write_u32_le(local_header + 0, 0x04034b50);
        write_u16_le(local_header + 4, needs_z64 ? 45 : (has_password ? 51 : 20));
        write_u16_le(local_header + 6, (has_password ? 0x0001 : 0x0000) | 0x0800); // Bit 11 UTF-8
        write_u16_le(local_header + 8, has_password ? 99 : item->actual_method);
        write_u16_le(local_header + 10, 0);
        write_u16_le(local_header + 12, 0x5421);
        write_u32_le(local_header + 14, item->crc32);
        write_u32_le(local_header + 18, needs_z64 ? 0xFFFFFFFF : (uint32_t)item->compressed_size);
        write_u32_le(local_header + 22, needs_z64 ? 0xFFFFFFFF : (uint32_t)item->uncompressed_size);
        write_u16_le(local_header + 26, filename_len);
        write_u16_le(local_header + 28, extra_field_len);

        pwrite_all(out_fd, local_header, 30, (off_t)current_offset);
        current_offset += 30;

        pwrite_all(out_fd, item->rel_path, filename_len, (off_t)current_offset);
        current_offset += filename_len;

        if (needs_z64) {
            uint8_t z64_extra[20];
            write_u16_le(z64_extra + 0, 0x0001);
            write_u16_le(z64_extra + 2, 16);
            write_u64_le(z64_extra + 4, (uint64_t)item->uncompressed_size);
            write_u64_le(z64_extra + 12, (uint64_t)item->compressed_size);
            pwrite_all(out_fd, z64_extra, 20, (off_t)current_offset);
            current_offset += 20;
        }

        if (has_password) {
            uint8_t aes_extra[11];
            write_u16_le(aes_extra + 0, 0x9901);
            write_u16_le(aes_extra + 2, 7);
            write_u16_le(aes_extra + 4, 0x0002);
            aes_extra[6] = 'A'; aes_extra[7] = 'E'; aes_extra[8] = 0x03;
            write_u16_le(aes_extra + 9, item->actual_method);
            pwrite_all(out_fd, aes_extra, 11, (off_t)current_offset);
            current_offset += 11;
        }

        if (item->compressed_payload && item->compressed_size > 0) {
            if (item->is_mmapped) {
                madvise(item->compressed_payload, (size_t)item->compressed_size, MADV_WILLNEED);
            }
            pwrite_all(out_fd, item->compressed_payload, (size_t)item->compressed_size, (off_t)current_offset);
            current_offset += (uint64_t)item->compressed_size;
        } else if (item->uncompressed_size > 0 && !item->is_directory) {
            int in_fd = open(item->src_path, O_RDONLY);
            if (in_fd >= 0) {
                void* mptr = mmap(NULL, (size_t)item->uncompressed_size, PROT_READ, MAP_SHARED, in_fd, 0);
                if (mptr != MAP_FAILED) {
                    pwrite_all(out_fd, mptr, (size_t)item->uncompressed_size, (off_t)current_offset);
                    munmap(mptr, (size_t)item->uncompressed_size);
                } else {
                    char stream_buf[256 * 1024];
                    ssize_t rbytes = 0;
                    off_t dst_off = (off_t)current_offset;
                    while ((rbytes = read(in_fd, stream_buf, sizeof(stream_buf))) > 0) {
                        pwrite_all(out_fd, stream_buf, (size_t)rbytes, dst_off);
                        dst_off += rbytes;
                    }
                }
                close(in_fd);
            }
            current_offset += (uint64_t)item->uncompressed_size;
        }
    }

    uint64_t cd_start_offset = current_offset;
    for (size_t i = 0; i < list.count; i++) {
        ttzip_c_item_t* item = &list.items[i];
        uint16_t filename_len = (uint16_t)strlen(item->rel_path);
        bool needs_z64 = (item->uncompressed_size >= 0xFFFFFFFF || item->compressed_size >= 0xFFFFFFFF || offsets[i] >= 0xFFFFFFFF);
        uint16_t extra_field_len = (has_password ? 11 : 0) + (needs_z64 ? 28 : 0);
        uint8_t cd_header[46];

        write_u32_le(cd_header + 0, 0x02014b50);
        write_u16_le(cd_header + 4, needs_z64 ? 45 : 63);
        write_u16_le(cd_header + 6, needs_z64 ? 45 : (has_password ? 51 : 20));
        write_u16_le(cd_header + 8, (has_password ? 0x0001 : 0x0000) | 0x0800); // Bit 11 UTF-8
        write_u16_le(cd_header + 10, has_password ? 99 : item->actual_method);
        write_u16_le(cd_header + 12, 0);
        write_u16_le(cd_header + 14, 0x5421);
        write_u32_le(cd_header + 16, item->crc32);
        write_u32_le(cd_header + 20, needs_z64 ? 0xFFFFFFFF : (uint32_t)item->compressed_size);
        write_u32_le(cd_header + 24, needs_z64 ? 0xFFFFFFFF : (uint32_t)item->uncompressed_size);
        write_u16_le(cd_header + 28, filename_len);
        write_u16_le(cd_header + 30, extra_field_len);
        write_u16_le(cd_header + 32, 0);
        write_u16_le(cd_header + 34, 0);
        write_u16_le(cd_header + 36, 0);
        write_u32_le(cd_header + 38, item->is_directory ? (0040755u << 16 | 0x10u) : (0100644u << 16 | 0x20u));
        write_u32_le(cd_header + 42, needs_z64 ? 0xFFFFFFFF : (uint32_t)offsets[i]);

        pwrite_all(out_fd, cd_header, 46, (off_t)current_offset);
        current_offset += 46;

        pwrite_all(out_fd, item->rel_path, filename_len, (off_t)current_offset);
        current_offset += filename_len;

        if (needs_z64) {
            uint8_t z64_extra[28];
            write_u16_le(z64_extra + 0, 0x0001);
            write_u16_le(z64_extra + 2, 24);
            write_u64_le(z64_extra + 4, (uint64_t)item->uncompressed_size);
            write_u64_le(z64_extra + 12, (uint64_t)item->compressed_size);
            write_u64_le(z64_extra + 20, (uint64_t)offsets[i]);
            pwrite_all(out_fd, z64_extra, 28, (off_t)current_offset);
            current_offset += 28;
        }

        if (has_password) {
            uint8_t aes_extra[11];
            write_u16_le(aes_extra + 0, 0x9901);
            write_u16_le(aes_extra + 2, 7);
            write_u16_le(aes_extra + 4, 0x0002);
            aes_extra[6] = 'A'; aes_extra[7] = 'E'; aes_extra[8] = 0x03;
            write_u16_le(aes_extra + 9, item->actual_method);
            pwrite_all(out_fd, aes_extra, 11, (off_t)current_offset);
            current_offset += 11;
        }
    }

    uint64_t cd_size = current_offset - cd_start_offset;
    bool global_z64 = (cd_start_offset >= 0xFFFFFFFF || cd_size >= 0xFFFFFFFF || list.count >= 0xFFFF);

    if (global_z64) {
        uint64_t z64_eocd_off = current_offset;
        uint8_t z64_eocd[56];
        write_u32_le(z64_eocd + 0, 0x06064b50);
        write_u64_le(z64_eocd + 4, 44);
        write_u16_le(z64_eocd + 12, 45);
        write_u16_le(z64_eocd + 14, 45);
        write_u32_le(z64_eocd + 16, 0);
        write_u32_le(z64_eocd + 20, 0);
        write_u64_le(z64_eocd + 24, (uint64_t)list.count);
        write_u64_le(z64_eocd + 32, (uint64_t)list.count);
        write_u64_le(z64_eocd + 40, cd_size);
        write_u64_le(z64_eocd + 48, cd_start_offset);
        pwrite_all(out_fd, z64_eocd, 56, (off_t)current_offset);
        current_offset += 56;

        uint8_t z64_loc[20];
        write_u32_le(z64_loc + 0, 0x07064b50);
        write_u32_le(z64_loc + 4, 0);
        write_u64_le(z64_loc + 8, z64_eocd_off);
        write_u32_le(z64_loc + 16, 1);
        pwrite_all(out_fd, z64_loc, 20, (off_t)current_offset);
        current_offset += 20;
    }

    uint8_t eocd[22];
    write_u32_le(eocd + 0, 0x06054b50);
    write_u16_le(eocd + 4, 0);
    write_u16_le(eocd + 6, 0);
    write_u16_le(eocd + 8, global_z64 ? 0xFFFF : (uint16_t)list.count);
    write_u16_le(eocd + 10, global_z64 ? 0xFFFF : (uint16_t)list.count);
    write_u32_le(eocd + 12, global_z64 ? 0xFFFFFFFF : (uint32_t)cd_size);
    write_u32_le(eocd + 16, global_z64 ? 0xFFFFFFFF : (uint32_t)cd_start_offset);
    write_u16_le(eocd + 20, 0);

    pwrite_all(out_fd, eocd, 22, (off_t)current_offset);
    current_offset += 22;

    ftruncate(out_fd, (off_t)current_offset);
    close(out_fd);
    free(offsets);

    return TTZIP_OK;
}
