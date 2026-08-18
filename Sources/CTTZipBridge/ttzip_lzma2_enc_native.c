// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_lzma2_enc_native.c
 * @brief Native in-process multi-core parallel LZMA2 encoder (liblzma + GCD + NEON).
 */

#include "include/ttzip_lzma2_enc_native.h"
#include "include/ttzip_lzma2_fast_encoder.h"
#include "include/ttzip_fl2_lzma2.h"
#include "include/ttzip_7z_header_writer.h"
#include "include/CTTZip7zStoreInternal.h"
#include "include/CTTZipSliceProfiler.h"
#include "include/CTTZipBridge.h"
#include "include/CTTZipCoreArchitecture.h"
#include "include/CTTZipBridge_Archive.h"
#include "include/CTTZipBridge_Crypto.h"
#include "include/ttzip_7z_kdf_arm64.h"
#include "include/CTTZipCommon.h"
#include <lzma.h>
#include <Security/SecRandom.h>

#include <zlib.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <sys/uio.h>
#include <fcntl.h>
#include <unistd.h>
#include <dispatch/dispatch.h>
#include <sys/sysctl.h>
#include <pthread.h>
#include <math.h>

#if defined(__ARM_NEON) || defined(__ARM_NEON__)
#include <arm_neon.h>
#endif

#include <CommonCrypto/CommonDigest.h>

typedef struct {
    ttzip_7z_crypto_session_t* session;
    const char* password;
} ttzip_kdf_worker_args_t;

static void* ttzip_kdf_thread_func(void* arg) {
    ttzip_kdf_worker_args_t* karg = (ttzip_kdf_worker_args_t*)arg;
    ttzip_7z_crypto_session_init(karg->session, karg->password, NULL, 0, 19);
    return NULL;
}

typedef struct {
    size_t unpack_offset;
    size_t unpack_size;
    size_t pack_capacity;
    size_t pack_size;
    uint8_t* pack_buf;
    uint32_t dict_size;
    int status;
    bool is_zero_block;
    uint32_t block_crc32;
    uint64_t encode_time_ns;
} ttzip_lzma2_block_task_t;

static inline void ttzip_lzma2_cleanup_blocks(ttzip_lzma2_block_task_t* blocks, size_t num_blocks, uint8_t* pack_arena) {
    if (pack_arena) {
        free(pack_arena);
    } else if (blocks) {
        for (size_t b = 0; b < num_blocks; b++) {
            if (blocks[b].pack_buf) {
                free(blocks[b].pack_buf);
                blocks[b].pack_buf = NULL;
            }
        }
    }
}

static int get_p_core_count(void) {
    int count = 0;
    size_t size = sizeof(count);
    if (sysctlbyname("hw.perflevel0.physicalcpu", &count, &size, NULL, 0) == 0 && count > 0) {
        return count;
    }
    if (sysctlbyname("hw.physicalcpu", &count, &size, NULL, 0) == 0 && count > 0) {
        return count;
    }
    return 12;
}

static int get_logical_cpu_count(void) {
    int count = 0;
    size_t size = sizeof(count);
    if (sysctlbyname("hw.logicalcpu", &count, &size, NULL, 0) == 0 && count > 0) {
        return count;
    }
    return get_p_core_count();
}

int ttzip_create_7z_lzma2_native_c(
    const char* output_path,
    const char* const* input_paths,
    size_t input_count,
    int level,
    const char* password
) {
    if (!output_path || !input_paths || input_count == 0) {
        return TTZIP_ERR_INVALID_PARAM;
    }
    if (level < 0) level = 0;
    if (level > 9) level = 9;

    pthread_t kdf_thread;
    bool has_kdf_thread = false;
    ttzip_kdf_worker_args_t kdf_args;
    ttzip_7z_crypto_session_t crypto_session;
    memset(&crypto_session, 0, sizeof(crypto_session));
    if (password && password[0] != '\0') {
        kdf_args.session = &crypto_session;
        kdf_args.password = password;
        if (pthread_create(&kdf_thread, NULL, ttzip_kdf_thread_func, &kdf_args) == 0) {
            has_kdf_thread = true;
        } else {
            ttzip_7z_crypto_session_init(&crypto_session, password, NULL, 0, 19);
        }
    }

    ttzip_slice_enable(true);
    ttzip_slice_reset();

    TTZIP_SLICE_SCOPE_BEGIN("1_CollectEntries");
    ttzip_7z_store_list_t list = {NULL, 0, 0};
    for (size_t i = 0; i < input_count; i++) {
        if (!input_paths[i]) continue;
        const char* base = strrchr(input_paths[i], '/');
        base = base ? base + 1 : input_paths[i];
        ttzip_7z_collect_recursive(input_paths[i], base, &list);
    }
    if (list.count == 0) {
        free(list.entries);
        TTZIP_SLICE_SCOPE_END("1_CollectEntries");
        ttzip_secure_zero(&crypto_session, sizeof(crypto_session));
        return TTZIP_ERR_INVALID_PARAM;
    }

    size_t num_files = list.count;
    uint64_t total_uncompressed_bytes = 0;
    size_t num_streams = 0;
    size_t num_empty_streams = 0;
    size_t num_empty_files = 0;

    for (size_t i = 0; i < num_files; i++) {
        if (!list.entries[i].is_directory && list.entries[i].file_size > 0) {
            list.entries[i].payload_buf = (uint8_t*)total_uncompressed_bytes;
            total_uncompressed_bytes += list.entries[i].file_size;
            num_streams++;
        } else {
            num_empty_streams++;
            if (!list.entries[i].is_directory && list.entries[i].file_size == 0) {
                num_empty_files++;
            }
        }
    }
    TTZIP_SLICE_SCOPE_END("1_CollectEntries");

    TTZIP_SLICE_SCOPE_BEGIN("2_SolidBuf_IO_and_CRC32");
    uint8_t* solid_buf = NULL;
    bool is_zero_copy = false;
    int zero_copy_fd = -1;

    int p_cores = get_p_core_count();
    if (p_cores < 1) p_cores = 1;
    dispatch_queue_t user_interactive_q = dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0);

    if (num_streams == 1 && total_uncompressed_bytes >= 1 * 1024 * 1024) {
        size_t single_idx = 0;
        for (size_t i = 0; i < num_files; i++) {
            if (!list.entries[i].is_directory && list.entries[i].file_size > 0) {
                single_idx = i;
                break;
            }
        }
        zero_copy_fd = open(list.entries[single_idx].src_path, O_RDONLY);
        if (zero_copy_fd >= 0) {
            void* mapped = mmap(NULL, (size_t)total_uncompressed_bytes, PROT_READ, MAP_PRIVATE, zero_copy_fd, 0);
            if (mapped != MAP_FAILED) {
                solid_buf = (uint8_t*)mapped;
                madvise(solid_buf, (size_t)total_uncompressed_bytes, MADV_SEQUENTIAL | MADV_WILLNEED);
                is_zero_copy = true;
            } else {
                close(zero_copy_fd);
                zero_copy_fd = -1;
            }
        }
    }

    if (!is_zero_copy && total_uncompressed_bytes > 0) {
        solid_buf = (uint8_t*)malloc((size_t)total_uncompressed_bytes);
        if (!solid_buf) {
            free(list.entries);
            TTZIP_SLICE_SCOPE_END("2_SolidBuf_IO_and_CRC32");
            return TTZIP_ERR_OUT_OF_MEMORY;
        }
        if (total_uncompressed_bytes > 16 * 1024 * 1024) {
            madvise(solid_buf, (size_t)total_uncompressed_bytes, MADV_WILLNEED);
        }
    }
    if (!is_zero_copy) {
        void (^read_entry_task)(size_t) = ^(size_t i) {
            ttzip_7z_store_entry_t* item = &list.entries[i];
            if (item->is_directory || item->file_size == 0) {
                item->crc32 = 0;
                return;
            }
            uint64_t offset = (uint64_t)item->payload_buf;
            uint8_t* dest_ptr = solid_buf + offset;
            size_t fsize = (size_t)item->file_size;

            int in_fd = open(item->src_path, O_RDONLY);
            if (in_fd >= 0) {
                ssize_t rd = pread(in_fd, dest_ptr, fsize, 0);
                close(in_fd);
                item->crc32 = (rd > 0) ? ttzip_compute_buffer_crc32_neon(0, dest_ptr, (size_t)rd) : 0;
            } else {
                item->crc32 = 0;
            }
        };

        if (num_files <= 8) {
            for (size_t i = 0; i < num_files; i++) read_entry_task(i);
        } else {
            size_t num_chunks = (size_t)(p_cores > 0 ? p_cores : 1);
            size_t chunk_len = (num_files + num_chunks - 1) / num_chunks;
            dispatch_apply(num_chunks, user_interactive_q, ^(size_t chunk_idx) {
                size_t start_i = chunk_idx * chunk_len;
                size_t end_i = start_i + chunk_len;
                if (end_i > num_files) end_i = num_files;
                for (size_t i = start_i; i < end_i; i++) {
                    read_entry_task(i);
                }
            });
        }
    }
    TTZIP_SLICE_SCOPE_END("2_SolidBuf_IO_and_CRC32");

    TTZIP_SLICE_SCOPE_BEGIN("3_EntropyCheck");
    double entropy = ttzip_estimate_buffer_entropy_dynamic(solid_buf, (size_t)total_uncompressed_bytes);
    if (entropy > 7.90 && total_uncompressed_bytes > 1024 * 1024) {
        level = 0;
    }
    TTZIP_SLICE_SCOPE_END("3_EntropyCheck");

    TTZIP_SLICE_SCOPE_BEGIN("4_BlockAlloc_and_PreScan");
    size_t block_size = 4 * 1024 * 1024;
    if (level == 1) {
        if (total_uncompressed_bytes >= 64 * 1024 * 1024) {
            int logical_cores = get_logical_cpu_count();
            size_t divisor = (size_t)(logical_cores * 2);
            if (divisor == 0) divisor = 1;
            block_size = (size_t)(total_uncompressed_bytes / divisor);
            if (block_size < 8 * 1024 * 1024) block_size = 8 * 1024 * 1024;
            if (block_size > 32 * 1024 * 1024) block_size = 32 * 1024 * 1024;
        } else if (total_uncompressed_bytes > 1 * 1024 * 1024) {
            size_t divisor = (size_t)(p_cores * 4);
            if (divisor == 0) divisor = 1;
            block_size = (size_t)(total_uncompressed_bytes / divisor);
            if (block_size < 256 * 1024) block_size = 256 * 1024;
            if (block_size > 1024 * 1024) block_size = 1024 * 1024;
        } else {
            block_size = (size_t)total_uncompressed_bytes;
        }
    } else if (total_uncompressed_bytes > 64 * 1024 * 1024) {
        block_size = 8 * 1024 * 1024;
    } else if (total_uncompressed_bytes <= 512 * 1024) {
        block_size = (size_t)total_uncompressed_bytes;
    }

    size_t num_blocks = (level == 0) ? 1 : (total_uncompressed_bytes > 0 ? (size_t)((total_uncompressed_bytes + block_size - 1) / block_size) : 1);
    if (num_blocks == 0) num_blocks = 1;

    ttzip_lzma2_block_task_t* blocks = (ttzip_lzma2_block_task_t*)calloc(num_blocks, sizeof(ttzip_lzma2_block_task_t));
    if (!blocks) {
        if (is_zero_copy) { munmap(solid_buf, (size_t)total_uncompressed_bytes); if (zero_copy_fd >= 0) close(zero_copy_fd); } else { free(solid_buf); }
        free(list.entries);
        TTZIP_SLICE_SCOPE_END("4_BlockAlloc_and_PreScan");
        return TTZIP_ERR_OUT_OF_MEMORY;
    }

    TTZIP_SLICE_SCOPE_BEGIN("5_ParallelLZMA2Encode");
    uint8_t* pack_arena = NULL;
    if (num_blocks > 1 && level > 0) {
        size_t per_block_cap = (size_t)(block_size * 1.02) + 64 * 1024;
        pack_arena = (uint8_t*)malloc(num_blocks * per_block_cap);
        for (size_t b = 0; b < num_blocks; b++) {
            blocks[b].unpack_offset = b * block_size;
            size_t rem = (size_t)total_uncompressed_bytes - blocks[b].unpack_offset;
            blocks[b].unpack_size = rem < block_size ? rem : block_size;
            blocks[b].pack_capacity = per_block_cap;
            blocks[b].pack_buf = pack_arena ? (pack_arena + b * per_block_cap) : (uint8_t*)malloc(per_block_cap);
        }
        dispatch_apply(num_blocks, user_interactive_q, ^(size_t b) {
            ttzip_lzma2_block_task_t* blk = &blocks[b];
            const uint8_t* blk_src = solid_buf + blk->unpack_offset;
            blk->is_zero_block = ttzip_is_block_all_zero_neon(blk_src, blk->unpack_size);
            blk->block_crc32 = (num_streams == 1 && is_zero_copy) ? ttzip_compute_buffer_crc32_neon(0, blk_src, blk->unpack_size) : 0;

            uint64_t t0 = ttzip_slice_now_ns();
            blk->status = ttzip_fl2_compress_block(
                blk_src,
                blk->unpack_size,
                blk->pack_buf,
                blk->pack_capacity,
                &blk->pack_size,
                level,
                blk->is_zero_block,
                &blk->dict_size,
                1
            );
            blk->encode_time_ns = ttzip_slice_now_ns() - t0;
        });
    } else if (level == 0) {
        blocks[0].unpack_offset = 0;
        blocks[0].unpack_size = (size_t)total_uncompressed_bytes;
        blocks[0].pack_size = blocks[0].unpack_size;
        blocks[0].pack_capacity = blocks[0].pack_size > 0 ? blocks[0].pack_size : 1;
        blocks[0].pack_buf = (uint8_t*)malloc(blocks[0].pack_capacity);
        if (blocks[0].pack_buf && blocks[0].pack_size > 0) {
            memcpy(blocks[0].pack_buf, solid_buf, blocks[0].pack_size);
        }
        blocks[0].status = 0;
        blocks[0].dict_size = 0;
    } else {
        blocks[0].unpack_offset = 0;
        blocks[0].unpack_size = (size_t)total_uncompressed_bytes;
        blocks[0].is_zero_block = ttzip_is_block_all_zero_neon(solid_buf, blocks[0].unpack_size);
        blocks[0].block_crc32 = (num_streams == 1 && is_zero_copy) ? ttzip_compute_buffer_crc32_neon(0, solid_buf, blocks[0].unpack_size) : 0;
        blocks[0].pack_capacity = blocks[0].is_zero_block ? (64 * 1024) : ((size_t)(blocks[0].unpack_size * 1.02) + 64 * 1024);
        blocks[0].pack_buf = (uint8_t*)malloc(blocks[0].pack_capacity);
        
        uint64_t t0 = ttzip_slice_now_ns();
        blocks[0].status = ttzip_fl2_compress_block(
            solid_buf,
            blocks[0].unpack_size,
            blocks[0].pack_buf,
            blocks[0].pack_capacity,
            &blocks[0].pack_size,
            level,
            blocks[0].is_zero_block,
            &blocks[0].dict_size,
            p_cores
        );
        blocks[0].encode_time_ns = ttzip_slice_now_ns() - t0;
    }
    TTZIP_SLICE_SCOPE_END("5_ParallelLZMA2Encode");

    if (num_streams == 1 && is_zero_copy) {
        size_t single_idx = 0;
        for (size_t i = 0; i < num_files; i++) {
            if (!list.entries[i].is_directory && list.entries[i].file_size > 0) {
                single_idx = i;
                break;
            }
        }
        uint32_t combined = blocks[0].block_crc32;
        for (size_t b = 1; b < num_blocks; b++) {
            combined = crc32_combine(combined, blocks[b].block_crc32, (off_t)blocks[b].unpack_size);
        }
        list.entries[single_idx].crc32 = combined;
    }

    if (num_blocks > 1 && ttzip_slice_is_enabled()) {
        uint64_t max_ns = 0, sum_ns = 0;
        for (size_t b = 0; b < num_blocks; b++) {
            sum_ns += blocks[b].encode_time_ns;
            if (blocks[b].encode_time_ns > max_ns) {
                max_ns = blocks[b].encode_time_ns;
            }
        }
    }

    bool compress_failed = false;
    uint32_t max_dict_size = 0;
    for (size_t b = 0; b < num_blocks; b++) {
        if (blocks[b].status != 0 || blocks[b].pack_size == 0) {
            compress_failed = true;
            break;
        }
        if (blocks[b].dict_size > max_dict_size) {
            max_dict_size = blocks[b].dict_size;
        }
    }

    if (compress_failed) {
        ttzip_lzma2_cleanup_blocks(blocks, num_blocks, pack_arena);
        free(blocks);
        if (is_zero_copy) { munmap(solid_buf, (size_t)total_uncompressed_bytes); if (zero_copy_fd >= 0) close(zero_copy_fd); } else { free(solid_buf); }
        free(list.entries);
        if (has_kdf_thread) {
            pthread_join(kdf_thread, NULL);
        }
        ttzip_secure_zero(&crypto_session, sizeof(crypto_session));
        if (password && password[0] != '\0') {
            return TTZIP_ERR_ARCHIVE_INIT_FAILED;
        }
        return ttzip_create_7z_store_fast_c(output_path, input_paths, input_count);
    }

    if (is_zero_copy) { munmap(solid_buf, (size_t)total_uncompressed_bytes); if (zero_copy_fd >= 0) close(zero_copy_fd); } else { free(solid_buf); }

    size_t total_compressed_len = 0;
    for (size_t b = 0; b < num_blocks; b++) {
        if (b < num_blocks - 1 && blocks[b].pack_size > 0 && blocks[b].pack_buf[blocks[b].pack_size - 1] == 0x00) {
            blocks[b].pack_size -= 1;
        }
        total_compressed_len += blocks[b].pack_size;
    }

    // AES-256 encryption of compressed data (if password provided)
    if (has_kdf_thread) {
        pthread_join(kdf_thread, NULL);
    }
    bool has_password = crypto_session.is_active;
    uint8_t* encrypted_buf = NULL;
    size_t encrypted_len = 0;
    const uint32_t kNumCyclesPower = crypto_session.num_cycles_power;

    if (!has_password && total_compressed_len >= total_uncompressed_bytes && total_uncompressed_bytes > 0 && level > 1) {
        ttzip_lzma2_cleanup_blocks(blocks, num_blocks, pack_arena);
        free(blocks);
        free(list.entries);
        return ttzip_create_7z_store_fast_c(output_path, input_paths, input_count);
    }

    if (has_password) {
        size_t padded_len = (total_compressed_len + 15) & ~(size_t)15;
        encrypted_buf = (uint8_t*)malloc(padded_len);
        if (!encrypted_buf) {
            ttzip_lzma2_cleanup_blocks(blocks, num_blocks, pack_arena);
            free(blocks); free(list.entries);
            return TTZIP_ERR_OUT_OF_MEMORY;
        }
        if (padded_len > total_compressed_len) {
            memset(encrypted_buf + total_compressed_len, 0, padded_len - total_compressed_len);
        }
        size_t off = 0;
        for (size_t b = 0; b < num_blocks; b++) {
            if (blocks[b].pack_size > 0) {
                memcpy(encrypted_buf + off, blocks[b].pack_buf, blocks[b].pack_size);
                off += blocks[b].pack_size;
            }
        }
        ttzip_aes256_cbc_encrypt(crypto_session.aes_key, crypto_session.aes_iv, encrypted_buf, padded_len, encrypted_buf);
        encrypted_len = padded_len;
    }

    int out_fd = open(output_path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (out_fd < 0) {
        ttzip_lzma2_cleanup_blocks(blocks, num_blocks, pack_arena);
        free(blocks); free(list.entries);
        if (encrypted_buf) free(encrypted_buf);
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

    size_t packed_stream_size = 0;
    if (has_password) {
        ttzip_7z_write_all(out_fd, encrypted_buf, encrypted_len);
        packed_stream_size = encrypted_len;
        free(encrypted_buf);
    } else {
        for (size_t b = 0; b < num_blocks; b++) {
            if (blocks[b].pack_size > 0) {
                if (ttzip_7z_write_all(out_fd, blocks[b].pack_buf, blocks[b].pack_size) < 0) {
                    close(out_fd);
                    ttzip_lzma2_cleanup_blocks(blocks, num_blocks, pack_arena);
                    free(blocks); free(list.entries);
                    return TTZIP_ERR_OPEN_FAILED;
                }
            }
        }
        packed_stream_size = total_compressed_len;
    }
    ttzip_lzma2_cleanup_blocks(blocks, num_blocks, pack_arena);
    free(blocks);

    ttzip_7z_header_params_t params = {
        .level = level,
        .has_password = has_password,
        .num_cycles_power = kNumCyclesPower,
        .aes_iv = crypto_session.aes_iv,
        .packed_stream_size = packed_stream_size,
        .total_uncompressed_bytes = total_uncompressed_bytes,
        .total_compressed_len = total_compressed_len,
        .max_dict_size = max_dict_size,
        .num_streams = num_streams,
        .num_empty_streams = num_empty_streams,
        .num_empty_files = num_empty_files
    };

    int flush_status = ttzip_7z_write_metadata_and_flush(out_fd, &list, &params);
    free(list.entries);
    ttzip_secure_zero(&crypto_session, sizeof(crypto_session));
    if (flush_status != TTZIP_OK) {
        return flush_status;
    }

    ttzip_slice_print_report("7z LZMA2 Compression Pipeline");
    ttzip_slice_reset();

    return TTZIP_OK;
}
