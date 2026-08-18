// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/CTTZipBridge.h"
#include "include/CTTZipCommon.h"
#include "include/CTTZipParser.h"
#include "include/CTTZipBridge_Crypto.h"
#include "include/CTTZipBridge_Archive.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>
#include <libgen.h>
#include <dirent.h>
#include <libdeflate.h>
#include <dispatch/dispatch.h>
#include <stdatomic.h>

static dispatch_semaphore_t g_fd_sem = NULL;
static dispatch_once_t g_fd_once;

static ssize_t write_all(int fd, const void* buf, size_t count) {
    size_t written = 0;
    const char* ptr = (const char*)buf;
    while (written < count) {
        ssize_t res = write(fd, ptr + written, count - written);
        if (res <= 0) {
            if (res < 0 && (errno == EINTR || errno == EAGAIN)) continue;
            return -1;
        }
        written += (size_t)res;
    }
    return (ssize_t)written;
}

int ttzip_extract_zip_c_parallel(
    const char* archive_path,
    const char* destination_dir,
    bool skip_mac_junk,
    const char* password
) {
    if (!archive_path || !destination_dir) return TTZIP_ERR_INVALID_PARAM;
    
    int fd = open(archive_path, O_RDONLY);
    if (fd < 0) {
        return TTZIP_ERR_OPEN_FAILED;
    }

    struct stat st;
    if (fstat(fd, &st) != 0 || st.st_size < 22) {
        close(fd);
        return TTZIP_ERR_CORRUPT_HEADER;
    }
    size_t file_size = (size_t)st.st_size;

    const uint8_t* mapped = (const uint8_t*)mmap(NULL, file_size, PROT_READ, MAP_SHARED, fd, 0);
    close(fd);
    if (mapped == MAP_FAILED) {
        return TTZIP_ERR_MMAP_FAILED;
    }

    size_t max_search = (file_size > 65557) ? 65557 : file_size;
    size_t search_start = file_size - max_search;
    ssize_t eocd_pos = -1;

    for (ssize_t i = (ssize_t)file_size - 22; i >= (ssize_t)search_start; i--) {
        if (mapped[i] == 0x50 && mapped[i+1] == 0x4b && mapped[i+2] == 0x05 && mapped[i+3] == 0x06) {
            eocd_pos = i;
            break;
        }
    }

    if (eocd_pos < 0) {
        munmap((void*)mapped, file_size);
        return TTZIP_ERR_CORRUPT_HEADER;
    }

    const uint8_t* eocd = mapped + eocd_pos;
    uint16_t total_entries = read_u16_le(eocd + 10);
    uint32_t cd_size = read_u32_le(eocd + 12);
    uint32_t cd_offset_32 = read_u32_le(eocd + 16);

    uint64_t cd_offset = cd_offset_32;

    if (eocd_pos >= 20) {
        const uint8_t* locator = eocd - 20;
        if (read_u32_le(locator) == 0x07064b50) {
            uint64_t z64_eocd_offset = read_u64_le(locator + 8);
            if (z64_eocd_offset + 56 <= file_size) {
                const uint8_t* z64_eocd = mapped + z64_eocd_offset;
                if (read_u32_le(z64_eocd) == 0x06064b50) {
                    uint64_t total_entries_64 = read_u64_le(z64_eocd + 32);
                    uint64_t cd_offset_64 = read_u64_le(z64_eocd + 48);
                    total_entries = (uint16_t)total_entries_64;
                    cd_offset = cd_offset_64;
                }
            }
        }
    }

    if (cd_offset >= file_size) {
        munmap((void*)mapped, file_size);
        return TTZIP_ERR_CORRUPT_HEADER;
    }

    dispatch_once(&g_fd_once, ^{
        g_fd_sem = dispatch_semaphore_create(256);
    });

    ttzip_parsed_entry_t* entries = (ttzip_parsed_entry_t*)malloc(sizeof(ttzip_parsed_entry_t) * (total_entries > 0 ? total_entries : 1));
    if (!entries) {
        munmap((void*)mapped, file_size);
        return TTZIP_ERR_OUT_OF_MEMORY;
    }
    size_t valid_entry_count = 0;
    size_t curr_pos = (size_t)cd_offset;

    while (curr_pos + 46 <= file_size && valid_entry_count < total_entries) {
        if (read_u32_le(mapped + curr_pos) != 0x02014b50) break;

        uint16_t flag = read_u16_le(mapped + curr_pos + 8);
        uint16_t method = read_u16_le(mapped + curr_pos + 10);
        uint32_t crc32_val = read_u32_le(mapped + curr_pos + 16);
        uint32_t comp_size32 = read_u32_le(mapped + curr_pos + 20);
        uint32_t uncomp_size32 = read_u32_le(mapped + curr_pos + 24);
        uint16_t fn_len = read_u16_le(mapped + curr_pos + 28);
        uint16_t extra_len = read_u16_le(mapped + curr_pos + 30);
        uint16_t comment_len = read_u16_le(mapped + curr_pos + 32);
        uint32_t lfh_offset32 = read_u32_le(mapped + curr_pos + 42);

        ttzip_parsed_entry_t* e = &entries[valid_entry_count];
        memset(e, 0, sizeof(ttzip_parsed_entry_t));

        e->compressed_size = comp_size32;
        e->uncompressed_size = uncomp_size32;
        e->lfh_offset = lfh_offset32;
        e->crc32 = crc32_val;
        e->compression_method = method;
        e->actual_method = method;
        e->flag = flag;
        e->is_encrypted = (flag & 0x0001) != 0;

        size_t path_copy_len = (fn_len < sizeof(e->rel_path) - 1) ? fn_len : (sizeof(e->rel_path) - 1);
        memcpy(e->rel_path, mapped + curr_pos + 46, path_copy_len);
        e->rel_path[path_copy_len] = '\0';

        uint32_t ext_attr = read_u32_le(mapped + curr_pos + 38);
        if ((fn_len > 0 && e->rel_path[fn_len - 1] == '/') || (ext_attr & 0x10) != 0 || ((ext_attr >> 16) & 0170000) == 0040000) {
            e->is_directory = true;
        }

        size_t extra_start = curr_pos + 46 + fn_len;
        size_t extra_pos = extra_start;
        while (extra_pos + 4 <= extra_start + extra_len) {
            uint16_t tag = read_u16_le(mapped + extra_pos);
            uint16_t size = read_u16_le(mapped + extra_pos + 2);
            if (extra_pos + 4 + size > extra_start + extra_len) break;

            if (tag == 0x0001) {
                size_t p = extra_pos + 4;
                if (e->uncompressed_size == 0xFFFFFFFF && p + 8 <= extra_pos + 4 + size) {
                    e->uncompressed_size = read_u64_le(mapped + p);
                    p += 8;
                }
                if (e->compressed_size == 0xFFFFFFFF && p + 8 <= extra_pos + 4 + size) {
                    e->compressed_size = read_u64_le(mapped + p);
                    p += 8;
                }
                if (e->lfh_offset == 0xFFFFFFFF && p + 8 <= extra_pos + 4 + size) {
                    e->lfh_offset = read_u64_le(mapped + p);
                    p += 8;
                }
            } else if (tag == 0x9901) {
                if (size >= 7) {
                    e->actual_method = read_u16_le(mapped + extra_pos + 4 + 5);
                    e->aes_strength = mapped[extra_pos + 4 + 4];
                    e->is_encrypted = true;
                }
            }
            extra_pos += 4 + size;
        }

        if (skip_mac_junk && (strstr(e->rel_path, "__MACOSX/") == e->rel_path || strstr(e->rel_path, "/.DS_Store") != NULL || strcmp(e->rel_path, ".DS_Store") == 0)) {
            curr_pos += 46 + fn_len + extra_len + comment_len;
            continue;
        }

        valid_entry_count++;
        curr_pos += 46 + fn_len + extra_len + comment_len;
    }

    dispatch_queue_t concurrent_q = dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0);
    dispatch_group_t group = dispatch_group_create();

    __block atomic_int global_error = 0;

    for (size_t i = 0; i < valid_entry_count; i++) {
        ttzip_parsed_entry_t* e = &entries[i];

        char out_path[4096];
        if (ttzip_common_join_path(out_path, sizeof(out_path), destination_dir, e->rel_path) != 0) {
            continue;
        }

        if (e->is_directory) {
            ttzip_common_mkdir_p(out_path);
            continue;
        }

        char dir_buf[4096];
        strncpy(dir_buf, out_path, sizeof(dir_buf));
        char* parent_dir = dirname(dir_buf);
        ttzip_common_mkdir_p(parent_dir);

        if (e->uncompressed_size == 0) {
            int out_fd = open(out_path, O_WRONLY | O_CREAT | O_TRUNC | O_NOFOLLOW, 0644);
            if (out_fd >= 0) close(out_fd);
            continue;
        }

        char* entry_out_path = strdup(out_path);

        dispatch_group_async(group, concurrent_q, ^{
            dispatch_semaphore_wait(g_fd_sem, DISPATCH_TIME_FOREVER);

            size_t lfh_pos = (size_t)e->lfh_offset;
            if (lfh_pos + 30 > file_size) {
                atomic_store(&global_error, TTZIP_ERR_CORRUPT_HEADER);
                free(entry_out_path);
                dispatch_semaphore_signal(g_fd_sem);
                return;
            }

            uint32_t lfh_sig = read_u32_le(mapped + lfh_pos);
            if (lfh_sig != 0x04034b50) {
                atomic_store(&global_error, TTZIP_ERR_CORRUPT_HEADER);
                free(entry_out_path);
                dispatch_semaphore_signal(g_fd_sem);
                return;
            }

            uint16_t lfh_fn_len = read_u16_le(mapped + lfh_pos + 26);
            uint16_t lfh_extra_len = read_u16_le(mapped + lfh_pos + 28);
            size_t payload_offset = lfh_pos + 30 + lfh_fn_len + lfh_extra_len;

            if (payload_offset + e->compressed_size > file_size) {
                atomic_store(&global_error, TTZIP_ERR_CORRUPT_HEADER);
                free(entry_out_path);
                dispatch_semaphore_signal(g_fd_sem);
                return;
            }

            const uint8_t* raw_payload = mapped + payload_offset;
            size_t raw_payload_len = e->compressed_size;
            uint8_t* decrypted_buf = NULL;
            size_t cipher_len = 0;

            if (e->is_encrypted) {
                if (!password || strlen(password) == 0) {
                    atomic_store(&global_error, TTZIP_ERR_INVALID_PASSWORD);
                    free(entry_out_path);
                    dispatch_semaphore_signal(g_fd_sem);
                    return;
                }
                cipher_len = (e->compressed_size > 28) ? (e->compressed_size - 28) : 0;
                decrypted_buf = (uint8_t*)malloc(cipher_len > 0 ? cipher_len : 1);
                size_t actual_plain_len = 0;
                int dec_res = ttzip_aes256_decrypt_and_verify(password, raw_payload, raw_payload_len, decrypted_buf, &actual_plain_len);
                if (dec_res != TTZIP_OK) {
                    atomic_store(&global_error, dec_res);
                    free(decrypted_buf);
                    free(entry_out_path);
                    dispatch_semaphore_signal(g_fd_sem);
                    return;
                }
                raw_payload = decrypted_buf;
                raw_payload_len = actual_plain_len;
            }

            if (e->actual_method == 0) { // Store Method
                int out_fd = -1;
                for (int retry = 0; retry < 10; retry++) {
                    out_fd = open(entry_out_path, O_WRONLY | O_CREAT | O_TRUNC | O_NOFOLLOW, 0644);
                    if (out_fd >= 0) break;
                    if (errno == EMFILE || errno == ENFILE || errno == EAGAIN) usleep(1000);
                    else break;
                }
                if (out_fd >= 0) {
                    write_all(out_fd, raw_payload, raw_payload_len);
                    close(out_fd);
                }
            } else if (e->actual_method == 8) { // Deflate Method
                static __thread struct libdeflate_decompressor* tls_decompressor = NULL;
                if (!tls_decompressor) {
                    tls_decompressor = libdeflate_alloc_decompressor();
                }
                struct libdeflate_decompressor* decompressor = tls_decompressor;
                if (decompressor) {
                    uint8_t local_stack_buf[65536];
                    uint8_t* decomp_buf = (e->uncompressed_size <= sizeof(local_stack_buf))
                        ? local_stack_buf
                        : (uint8_t*)malloc(e->uncompressed_size > 0 ? e->uncompressed_size : 1);
                    if (decomp_buf) {
                        size_t actual_out = 0;
                        enum libdeflate_result res = libdeflate_deflate_decompress(
                            decompressor,
                            raw_payload,
                            raw_payload_len,
                            decomp_buf,
                            e->uncompressed_size,
                            &actual_out
                        );

                        if (res == LIBDEFLATE_SUCCESS) {
                            int out_fd = -1;
                            for (int retry = 0; retry < 10; retry++) {
                                out_fd = open(entry_out_path, O_WRONLY | O_CREAT | O_TRUNC | O_NOFOLLOW, 0644);
                                if (out_fd >= 0) break;
                                if (errno == EMFILE || errno == ENFILE || errno == EAGAIN) usleep(1000);
                                else break;
                            }
                            if (out_fd >= 0) {
                                write_all(out_fd, decomp_buf, actual_out);
                                close(out_fd);
                            }
                        }
                        if (decomp_buf != local_stack_buf) {
                            free(decomp_buf);
                        }
                    }
                }
            }

            if (decrypted_buf) {
                ttzip_secure_zero(decrypted_buf, cipher_len > 0 ? cipher_len : 1);
                free(decrypted_buf);
            }

            free(entry_out_path);
            dispatch_semaphore_signal(g_fd_sem);
        });
    }

    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);

    free(entries);
    munmap((void*)mapped, file_size);
    return global_error;
}
