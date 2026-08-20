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
#include "include/ttzip_threadpool.h"

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
#include <stdatomic.h>
#include <errno.h>

static ttzip_semaphore_t* g_fd_sem = NULL;
static ttzip_once_t g_fd_once = TTZIP_ONCE_INIT;

static void init_fd_sem(void) {
    g_fd_sem = ttzip_semaphore_create(256);
}

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

typedef struct {
    ttzip_parsed_entry_t* entries;
    const uint8_t* mapped;
    size_t file_size;
    const char* destination_dir;
    const char* password;
    _Atomic int global_error;
} zip_extract_parallel_ctx_t;

static void zip_extract_entry_worker(size_t i, void* arg) {
    zip_extract_parallel_ctx_t* ctx = (zip_extract_parallel_ctx_t*)arg;
    ttzip_parsed_entry_t* e = &ctx->entries[i];

    char out_path[4096];
    if (ttzip_common_join_path(out_path, sizeof(out_path), ctx->destination_dir, e->rel_path) != 0) {
        return;
    }

    if (e->is_directory) {
        ttzip_common_mkdir_p(out_path);
        return;
    }

    char dir_buf[4096];
    strncpy(dir_buf, out_path, sizeof(dir_buf));
    char* parent_dir = dirname(dir_buf);
    ttzip_common_mkdir_p(parent_dir);

    if (e->uncompressed_size == 0) {
        int out_fd = open(out_path, O_WRONLY | O_CREAT | O_TRUNC | O_NOFOLLOW, 0644);
        if (out_fd >= 0) close(out_fd);
        return;
    }

    ttzip_semaphore_wait(g_fd_sem);

    size_t lfh_pos = (size_t)e->lfh_offset;
    if (lfh_pos + 30 > ctx->file_size) {
        atomic_store(&ctx->global_error, TTZIP_ERR_CORRUPT_HEADER);
        ttzip_semaphore_signal(g_fd_sem);
        return;
    }

    uint32_t lfh_sig = read_u32_le(ctx->mapped + lfh_pos);
    if (lfh_sig != 0x04034b50) {
        atomic_store(&ctx->global_error, TTZIP_ERR_CORRUPT_HEADER);
        ttzip_semaphore_signal(g_fd_sem);
        return;
    }

    uint16_t lfh_fn_len = read_u16_le(ctx->mapped + lfh_pos + 26);
    uint16_t lfh_extra_len = read_u16_le(ctx->mapped + lfh_pos + 28);
    size_t payload_offset = lfh_pos + 30 + lfh_fn_len + lfh_extra_len;

    if (payload_offset + e->compressed_size > ctx->file_size) {
        atomic_store(&ctx->global_error, TTZIP_ERR_CORRUPT_HEADER);
        ttzip_semaphore_signal(g_fd_sem);
        return;
    }

    const uint8_t* raw_payload = ctx->mapped + payload_offset;
    size_t raw_payload_len = e->compressed_size;
    uint8_t* decrypted_buf = NULL;
    size_t cipher_len = 0;

    if (e->is_encrypted) {
        if (!ctx->password || strlen(ctx->password) == 0) {
            atomic_store(&ctx->global_error, TTZIP_ERR_INVALID_PASSWORD);
            ttzip_semaphore_signal(g_fd_sem);
            return;
        }
        cipher_len = (e->compressed_size > 28) ? (e->compressed_size - 28) : 0;
        decrypted_buf = (uint8_t*)malloc(cipher_len > 0 ? cipher_len : 1);
        size_t actual_plain_len = 0;
        int dec_res = ttzip_aes256_decrypt_and_verify(ctx->password, raw_payload, raw_payload_len, decrypted_buf, &actual_plain_len);
        if (dec_res != TTZIP_OK) {
            atomic_store(&ctx->global_error, dec_res);
            ttzip_secure_zero(decrypted_buf, cipher_len > 0 ? cipher_len : 1);
            free(decrypted_buf);
            ttzip_semaphore_signal(g_fd_sem);
            return;
        }
        raw_payload = decrypted_buf;
        raw_payload_len = actual_plain_len;
    }

    if (e->actual_method == 0) { // Store Method
        int out_fd = -1;
        for (int retry = 0; retry < 10; retry++) {
            out_fd = open(out_path, O_WRONLY | O_CREAT | O_TRUNC | O_NOFOLLOW, 0644);
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
                        out_fd = open(out_path, O_WRONLY | O_CREAT | O_TRUNC | O_NOFOLLOW, 0644);
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

    ttzip_semaphore_signal(g_fd_sem);
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
        if (read_u32_le(mapped + i) == 0x06054b50) {
            eocd_pos = i;
            break;
        }
    }

    if (eocd_pos < 0) {
        munmap((void*)mapped, file_size);
        return TTZIP_ERR_CORRUPT_HEADER;
    }

    const uint8_t* eocd = mapped + eocd_pos;
    uint64_t total_entries = read_u16_le(eocd + 10);
    uint32_t cd_size = read_u32_le(eocd + 12);
    (void)cd_size;
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
                    total_entries = total_entries_64;
                    cd_offset = cd_offset_64;
                }
            }
        }
    }

    if (cd_offset >= file_size) {
        munmap((void*)mapped, file_size);
        return TTZIP_ERR_CORRUPT_HEADER;
    }

    ttzip_once(&g_fd_once, init_fd_sem);

    size_t alloc_entries = total_entries > 0 ? (size_t)total_entries : 1;
    size_t alloc_bytes = 0;
    if (ttzip_mul_overflow(sizeof(ttzip_parsed_entry_t), alloc_entries, &alloc_bytes)) {
        munmap((void*)mapped, file_size);
        return TTZIP_ERR_OUT_OF_MEMORY;
    }

    ttzip_parsed_entry_t* entries = (ttzip_parsed_entry_t*)malloc(alloc_bytes);
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
        uint32_t crc = read_u32_le(mapped + curr_pos + 16);
        uint64_t comp_size = read_u32_le(mapped + curr_pos + 20);
        uint64_t uncomp_size = read_u32_le(mapped + curr_pos + 24);
        uint16_t fn_len = read_u16_le(mapped + curr_pos + 28);
        uint16_t extra_len = read_u16_le(mapped + curr_pos + 30);
        uint16_t comment_len = read_u16_le(mapped + curr_pos + 32);
        uint64_t lfh_offset = read_u32_le(mapped + curr_pos + 42);

        if (curr_pos + 46 + fn_len + extra_len + comment_len > file_size) break;

        const uint8_t* fn_ptr = mapped + curr_pos + 46;
        const uint8_t* extra_ptr = fn_ptr + fn_len;

        // Parse Zip64 Extra Field (Header ID 0x0001)
        size_t extra_offset = 0;
        while (extra_offset + 4 <= extra_len) {
            uint16_t header_id = read_u16_le(extra_ptr + extra_offset);
            uint16_t data_size = read_u16_le(extra_ptr + extra_offset + 2);
            if (extra_offset + 4 + data_size > extra_len) break;

            if (header_id == 0x0001) {
                size_t field_pos = extra_offset + 4;
                if (uncomp_size == 0xFFFFFFFF && field_pos + 8 <= extra_offset + 4 + data_size) {
                    uncomp_size = read_u64_le(extra_ptr + field_pos);
                    field_pos += 8;
                }
                if (comp_size == 0xFFFFFFFF && field_pos + 8 <= extra_offset + 4 + data_size) {
                    comp_size = read_u64_le(extra_ptr + field_pos);
                    field_pos += 8;
                }
                if (lfh_offset == 0xFFFFFFFF && field_pos + 8 <= extra_offset + 4 + data_size) {
                    lfh_offset = read_u64_le(extra_ptr + field_pos);
                    field_pos += 8;
                }
            }
            extra_offset += 4 + data_size;
        }

        ttzip_parsed_entry_t* e = &entries[valid_entry_count];
        memset(e, 0, sizeof(ttzip_parsed_entry_t));

        size_t copy_fn_len = (fn_len < sizeof(e->rel_path) - 1) ? fn_len : (sizeof(e->rel_path) - 1);
        memcpy(e->rel_path, fn_ptr, copy_fn_len);
        e->rel_path[copy_fn_len] = '\0';

        e->compressed_size = comp_size;
        e->uncompressed_size = uncomp_size;
        e->crc32 = crc;
        e->lfh_offset = lfh_offset;
        e->compression_method = method;
        e->actual_method = method;
        e->is_directory = (copy_fn_len > 0 && e->rel_path[copy_fn_len - 1] == '/');
        e->is_encrypted = (flag & 0x0001) != 0;

        // AES Extra Field check (0x9901)
        if (method == 99) {
            size_t ef_pos = 0;
            while (ef_pos + 4 <= extra_len) {
                uint16_t hid = read_u16_le(extra_ptr + ef_pos);
                uint16_t hsz = read_u16_le(extra_ptr + ef_pos + 2);
                if (ef_pos + 4 + hsz > extra_len) break;
                if (hid == 0x9901 && hsz >= 7) {
                    e->actual_method = read_u16_le(extra_ptr + ef_pos + 4 + 5);
                    e->is_encrypted = true;
                    break;
                }
                ef_pos += 4 + hsz;
            }
        }

        if (skip_mac_junk && (strstr(e->rel_path, "__MACOSX/") == e->rel_path || strstr(e->rel_path, "/.DS_Store") != NULL || strcmp(e->rel_path, ".DS_Store") == 0)) {
            curr_pos += 46 + fn_len + extra_len + comment_len;
            continue;
        }

        valid_entry_count++;
        curr_pos += 46 + fn_len + extra_len + comment_len;
    }

    zip_extract_parallel_ctx_t extract_ctx = {
        .entries = entries,
        .mapped = mapped,
        .file_size = file_size,
        .destination_dir = destination_dir,
        .password = password,
        .global_error = 0
    };

    ttzip_parallel_for(ttzip_threadpool_shared(), valid_entry_count, zip_extract_entry_worker, &extract_ctx);

    free(entries);
    munmap((void*)mapped, file_size);
    return atomic_load(&extract_ctx.global_error);
}
