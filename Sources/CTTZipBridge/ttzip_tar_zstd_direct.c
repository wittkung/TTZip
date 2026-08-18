// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_tar_zstd_direct.c
 * @brief High-speed zero-copy Direct TAR.ZST pipeline and state-machine extractor.
 */

#include "include/ttzip_tar_zstd_direct.h"
#include "include/CTTZipBridge.h"
#include "include/CTTZipBridge_Archive.h"
#include "include/CTTZipCommon.h"
#include "include/CTTZipCoreArchitecture.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>
#include <dirent.h>
#include <zstd.h>
#include <archive.h>
#include <archive_entry.h>
#include <dispatch/dispatch.h>

static void format_ustar_header(
    uint8_t header[512],
    const char* rel_path,
    const struct stat* st
) {
    memset(header, 0, 512);
    
    // name (0..99)
    strncpy((char*)header, rel_path, 100);
    
    // mode (100..107)
    snprintf((char*)header + 100, 8, "%07o", st->st_mode & 07777);
    // uid (108..115)
    snprintf((char*)header + 108, 8, "%07o", (unsigned int)st->st_uid);
    // gid (116..123)
    snprintf((char*)header + 116, 8, "%07o", (unsigned int)st->st_gid);
    // size (124..135)
    uint64_t size_val = S_ISREG(st->st_mode) ? (uint64_t)st->st_size : 0;
    snprintf((char*)header + 124, 12, "%011llo", (unsigned long long)size_val);
    // mtime (136..147)
    snprintf((char*)header + 136, 12, "%011lo", (unsigned long)st->st_mtime);
    
    // typeflag (156)
    if (S_ISDIR(st->st_mode)) {
        header[156] = '5'; // Directory
    } else if (S_ISLNK(st->st_mode)) {
        header[156] = '2'; // Symlink
    } else {
        header[156] = '0'; // Regular file
    }
    
    // magic & version (257..264)
    memcpy(header + 257, "ustar\0", 6);
    memcpy(header + 263, "00", 2);
    
    // Checksum calculation (148..155 treated as 8 spaces)
    memset(header + 148, ' ', 8);
    unsigned int sum = 0;
    for (int i = 0; i < 512; i++) {
        sum += header[i];
    }
    snprintf((char*)header + 148, 8, "%06o", sum);
}

static inline int flush_zstd_out(ZSTD_outBuffer* out, int out_fd) {
    if (out->pos > 0) {
        ssize_t written = write(out_fd, out->dst, out->pos);
        if (written < (ssize_t)out->pos) {
            return TTZIP_ERR_OPEN_FAILED;
        }
        out->pos = 0;
    }
    return TTZIP_OK;
}

static int add_item_to_zstd_stream(
    ZSTD_CCtx* cctx,
    ZSTD_outBuffer* out,
    int out_fd,
    const char* full_path,
    const char* rel_path,
    bool skip_mac_junk
) {
    if (!full_path || !rel_path || rel_path[0] == '\0') return TTZIP_OK;
    if (skip_mac_junk && ttzip_is_mac_junk(rel_path)) return TTZIP_OK;
    
    struct stat st;
    if (lstat(full_path, &st) != 0) return TTZIP_ERR_FILE_NOT_FOUND;
    
    char* formatted_rel = NULL;
    size_t rel_len = strlen(rel_path);
    if (S_ISDIR(st.st_mode) && rel_len > 0 && rel_path[rel_len - 1] != '/') {
        if (asprintf(&formatted_rel, "%s/", rel_path) <= 0) return TTZIP_ERR_OUT_OF_MEMORY;
    } else {
        formatted_rel = strdup(rel_path);
        if (!formatted_rel) return TTZIP_ERR_OUT_OF_MEMORY;
    }
    
    // 0. If path > 100 bytes, write standard Pax LongLink header
    size_t fmt_len = strlen(formatted_rel);
    if (fmt_len > 100) {
        size_t name_len = fmt_len + 1;
        uint8_t ll_hdr[512] = {0};
        strcpy((char*)ll_hdr, "././@LongLink");
        snprintf((char*)ll_hdr + 100, 8, "%07o", 0644);
        snprintf((char*)ll_hdr + 108, 8, "%07o", 0);
        snprintf((char*)ll_hdr + 116, 8, "%07o", 0);
        snprintf((char*)ll_hdr + 124, 12, "%011llo", (unsigned long long)name_len);
        snprintf((char*)ll_hdr + 136, 12, "%011o", 0);
        ll_hdr[156] = 'L';
        memcpy(ll_hdr + 257, "ustar\0", 6);
        memcpy(ll_hdr + 263, "00", 2);
        memset(ll_hdr + 148, ' ', 8);
        unsigned int sum = 0;
        for (int i = 0; i < 512; i++) sum += ll_hdr[i];
        snprintf((char*)ll_hdr + 148, 8, "%06o", sum);

        ZSTD_inBuffer in_ll = { ll_hdr, 512, 0 };
        while (in_ll.pos < in_ll.size) {
            ZSTD_compressStream2(cctx, out, &in_ll, ZSTD_e_continue);
            if (out->pos >= out->size - 65536) flush_zstd_out(out, out_fd);
        }

        size_t total_payload = (name_len + 511) & ~(size_t)511;
        uint8_t* name_buf = (uint8_t*)calloc(1, total_payload);
        if (name_buf) {
            memcpy(name_buf, formatted_rel, fmt_len);
            ZSTD_inBuffer in_name = { name_buf, total_payload, 0 };
            while (in_name.pos < in_name.size) {
                ZSTD_compressStream2(cctx, out, &in_name, ZSTD_e_continue);
                if (out->pos >= out->size - 65536) flush_zstd_out(out, out_fd);
            }
            free(name_buf);
        }
    }

    uint8_t tar_hdr[512];
    format_ustar_header(tar_hdr, formatted_rel, &st);
    
    // 1. Write Tar Header 512B
    ZSTD_inBuffer in_hdr = { tar_hdr, 512, 0 };
    while (in_hdr.pos < in_hdr.size) {
        ZSTD_compressStream2(cctx, out, &in_hdr, ZSTD_e_continue);
        if (out->pos >= out->size - 65536) {
            int ret = flush_zstd_out(out, out_fd);
            if (ret != TTZIP_OK) {
                free(formatted_rel);
                return ret;
            }
        }
    }
    
    // 2. Regular file zero-copy direct write
    if (S_ISREG(st.st_mode) && st.st_size > 0) {
        int in_fd = open(full_path, O_RDONLY);
        if (in_fd >= 0) {
            size_t file_bytes = ttzip_clamp_size((uint64_t)st.st_size);
            void* mapped = mmap(NULL, file_bytes, PROT_READ, MAP_SHARED, in_fd, 0);
            if (mapped != MAP_FAILED) {
                madvise(mapped, file_bytes, MADV_SEQUENTIAL | MADV_WILLNEED);
                
                ZSTD_inBuffer in_file = { mapped, file_bytes, 0 };
                while (in_file.pos < in_file.size) {
                    ZSTD_compressStream2(cctx, out, &in_file, ZSTD_e_continue);
                    if (out->pos >= out->size - 131072) {
                        int ret = flush_zstd_out(out, out_fd);
                        if (ret != TTZIP_OK) {
                            munmap(mapped, file_bytes);
                            close(in_fd);
                            free(formatted_rel);
                            return ret;
                        }
                    }
                }
                munmap(mapped, file_bytes);
            } else {
                uint8_t read_chunk[4096];
                ssize_t rd = 0;
                while ((rd = read(in_fd, read_chunk, sizeof(read_chunk))) > 0) {
                    ZSTD_inBuffer in_file = { read_chunk, (size_t)rd, 0 };
                    while (in_file.pos < in_file.size) {
                        ZSTD_compressStream2(cctx, out, &in_file, ZSTD_e_continue);
                        if (out->pos >= out->size - 131072) {
                            int ret = flush_zstd_out(out, out_fd);
                            if (ret != TTZIP_OK) {
                                close(in_fd);
                                free(formatted_rel);
                                return ret;
                            }
                        }
                    }
                }
            }
            close(in_fd);
        }
        
        // Tar 512-byte alignment padding
        size_t rem = (size_t)(st.st_size % 512);
        if (rem > 0) {
            size_t pad = 512 - rem;
            uint8_t zero_pad[512] = {0};
            ZSTD_inBuffer in_pad = { zero_pad, pad, 0 };
            while (in_pad.pos < in_pad.size) {
                ZSTD_compressStream2(cctx, out, &in_pad, ZSTD_e_continue);
                if (out->pos >= out->size - 65536) {
                    int ret = flush_zstd_out(out, out_fd);
                    if (ret != TTZIP_OK) {
                        free(formatted_rel);
                        return ret;
                    }
                }
            }
        }
    }
    
    // 3. Directory recursion
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
                if (asprintf(&sub_full, "%s/%s", full_path, de->d_name) > 0) {
                    if (formatted_rel[strlen(formatted_rel) - 1] == '/') {
                        asprintf(&sub_rel, "%s%s", formatted_rel, de->d_name);
                    } else {
                        asprintf(&sub_rel, "%s/%s", formatted_rel, de->d_name);
                    }
                    if (sub_rel) {
                        int r = add_item_to_zstd_stream(cctx, out, out_fd, sub_full, sub_rel, skip_mac_junk);
                        free(sub_full);
                        free(sub_rel);
                        if (r != TTZIP_OK) {
                            closedir(dir);
                            free(formatted_rel);
                            return r;
                        }
                    } else {
                        if (sub_full) free(sub_full);
                    }
                }
            }
            closedir(dir);
        }
    }
    free(formatted_rel);
    return TTZIP_OK;
}

static int ttzip_create_tar_zstd_raw_direct_c(const char* output_path, const char* in_file_path) {
    struct stat st;
    if (lstat(in_file_path, &st) != 0 || !S_ISREG(st.st_mode)) return TTZIP_ERR_FILE_NOT_FOUND;
    
    int in_fd = open(in_file_path, O_RDONLY);
    if (in_fd < 0) return TTZIP_ERR_OPEN_FAILED;
    
    size_t fsize = (size_t)st.st_size;
    size_t pad = (fsize % 512) > 0 ? (512 - (fsize % 512)) : 0;
    uint64_t total_tar = 512 + fsize + pad + 1024;
    
    const size_t kMaxBlock = 128 * 1024;
    size_t num_chunks = (size_t)((total_tar + kMaxBlock - 1) / kMaxBlock);
    if (num_chunks == 0) num_chunks = 1;
    
    size_t total_zstd_size = 4 + 5 + num_chunks * 3 + (size_t)total_tar;
    
    unlink(output_path);
    int out_fd = open(output_path, O_RDWR | O_CREAT | O_TRUNC, 0644);
    if (out_fd < 0) { close(in_fd); return TTZIP_ERR_OPEN_FAILED; }
    
    if (ftruncate(out_fd, (off_t)total_zstd_size) != 0) {
        close(in_fd); close(out_fd); return TTZIP_ERR_OPEN_FAILED;
    }
    
    uint8_t* out_map = (uint8_t*)mmap(NULL, total_zstd_size, PROT_READ | PROT_WRITE, MAP_SHARED, out_fd, 0);
    if (out_map == MAP_FAILED) {
        close(in_fd); close(out_fd); return TTZIP_ERR_OUT_OF_MEMORY;
    }
    madvise(out_map, total_zstd_size, MADV_SEQUENTIAL | MADV_WILLNEED);
    
    // 1. Zstd Magic Number
    uint32_t magic = 0xFD2FB528;
    memcpy(out_map, &magic, 4);
    
    // 2. Frame Header: Single Segment, 4-byte FCS
    out_map[4] = 0xA0;
    uint32_t fcs32 = (uint32_t)total_tar;
    memcpy(out_map + 5, &fcs32, 4);
    
    // 3. USTAR Header
    uint8_t ustar[512];
    const char* rel = strrchr(in_file_path, '/');
    rel = rel ? rel + 1 : in_file_path;
    format_ustar_header(ustar, rel, &st);
    const uint8_t* ustar_ptr = ustar;
    
    void* mapped_in = mmap(NULL, fsize, PROT_READ, MAP_SHARED, in_fd, 0);
    if (mapped_in != MAP_FAILED) {
        madvise(mapped_in, fsize, MADV_SEQUENTIAL | MADV_WILLNEED);
    }
    
    dispatch_queue_t q = dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0);
    dispatch_apply(num_chunks, q, ^(size_t chunk_idx) {
        uint64_t tar_pos = chunk_idx * kMaxBlock;
        size_t chunk_len = (total_tar - tar_pos) > kMaxBlock ? kMaxBlock : (size_t)(total_tar - tar_pos);
        bool is_last = (tar_pos + chunk_len == total_tar);
        
        size_t out_chunk_offset = 9 + chunk_idx * (3 + kMaxBlock);
        
        uint32_t b_hdr_val = (uint32_t)((chunk_len << 3) | (0 << 1) | (is_last ? 1 : 0));
        out_map[out_chunk_offset] = (uint8_t)(b_hdr_val & 0xFF);
        out_map[out_chunk_offset + 1] = (uint8_t)((b_hdr_val >> 8) & 0xFF);
        out_map[out_chunk_offset + 2] = (uint8_t)((b_hdr_val >> 16) & 0xFF);
        
        uint8_t* payload_dst = out_map + out_chunk_offset + 3;
        
        size_t filled = 0;
        while (filled < chunk_len) {
            uint64_t cur = tar_pos + filled;
            if (cur < 512) {
                size_t c = (512 - cur) < (chunk_len - filled) ? (512 - cur) : (chunk_len - filled);
                memcpy(payload_dst + filled, ustar_ptr + cur, c);
                filled += c;
            } else if (cur < 512 + fsize) {
                uint64_t f_off = cur - 512;
                size_t c = (fsize - f_off) < (chunk_len - filled) ? (fsize - f_off) : (chunk_len - filled);
                if (mapped_in != MAP_FAILED) {
                    memcpy(payload_dst + filled, (const uint8_t*)mapped_in + f_off, c);
                } else {
                    pread(in_fd, payload_dst + filled, c, (off_t)f_off);
                }
                filled += c;
            } else {
                size_t c = chunk_len - filled;
                memset(payload_dst + filled, 0, c);
                filled += c;
            }
        }
    });
    
    if (mapped_in != MAP_FAILED) munmap(mapped_in, fsize);
    munmap(out_map, total_zstd_size);
    close(in_fd);
    close(out_fd);
    return TTZIP_OK;
}

int ttzip_create_tar_zstd_direct_c(
    const char* output_path,
    const char* const* input_paths,
    size_t input_count,
    int level,
    bool skip_mac_junk
) {
    if (!output_path || !input_paths || input_count == 0) return TTZIP_ERR_INVALID_PARAM;
    
    uint64_t total_in_bytes = 0;
    double initial_entropy = 0.0;
    bool is_single_reg_file = false;
    if (input_count == 1 && input_paths[0]) {
        struct stat st_probe;
        if (lstat(input_paths[0], &st_probe) == 0) {
            if (S_ISREG(st_probe.st_mode)) {
                is_single_reg_file = true;
                total_in_bytes = (uint64_t)st_probe.st_size;
                if (st_probe.st_size >= 16 * 1024 * 1024) {
                    int test_fd = open(input_paths[0], O_RDONLY);
                    if (test_fd >= 0) {
                        uint8_t sample[65536];
                        ssize_t rd = read(test_fd, sample, sizeof(sample));
                        close(test_fd);
                        if (rd > 1024) {
                            initial_entropy = ttzip_estimate_buffer_entropy_dynamic(sample, (size_t)rd);
                        }
                    }
                }
            }
        }
    }
    
    if (is_single_reg_file && initial_entropy > 7.45) {
        return ttzip_create_tar_zstd_raw_direct_c(output_path, input_paths[0]);
    }
    
    int out_fd;
    if (strcmp(output_path, "-") == 0) {
        out_fd = STDOUT_FILENO;
    } else {
        unlink(output_path);
        out_fd = open(output_path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
        if (out_fd < 0) return TTZIP_ERR_OPEN_FAILED;
    }
    
    ZSTD_CCtx* cctx = ZSTD_createCCtx();
    if (!cctx) {
        if (out_fd != STDOUT_FILENO) close(out_fd);
        return TTZIP_ERR_OUT_OF_MEMORY;
    }
    
    int cores = (int)sysconf(_SC_NPROCESSORS_ONLN);
    if (cores <= 0) cores = 8;
    int zstd_lvl = (level <= 0) ? 3 : level;
    
    ZSTD_CCtx_setParameter(cctx, ZSTD_c_compressionLevel, zstd_lvl);
    ZSTD_CCtx_setParameter(cctx, ZSTD_c_nbWorkers, cores);
    size_t adaptive_job_sz = (total_in_bytes > 0 && (total_in_bytes / (size_t)(cores * 2)) >= 2 * 1024 * 1024) ? (size_t)(total_in_bytes / (size_t)(cores * 2)) : (4 * 1024 * 1024);
    if (adaptive_job_sz > 8 * 1024 * 1024) adaptive_job_sz = 8 * 1024 * 1024;
    ZSTD_CCtx_setParameter(cctx, ZSTD_c_jobSize, (int)adaptive_job_sz);
    if (initial_entropy > 7.75 && zstd_lvl <= 3) {
        ZSTD_CCtx_setParameter(cctx, ZSTD_c_compressionLevel, 1);
        ZSTD_CCtx_setParameter(cctx, ZSTD_c_strategy, (int)ZSTD_fast);
        ZSTD_CCtx_setParameter(cctx, ZSTD_c_targetLength, 0);
        ZSTD_CCtx_setParameter(cctx, ZSTD_c_overlapLog, 0);
    } else if (zstd_lvl <= 3) {
        ZSTD_CCtx_setParameter(cctx, ZSTD_c_overlapLog, 0);
    } else {
        ZSTD_CCtx_setParameter(cctx, ZSTD_c_overlapLog, 3);
    }
    
    size_t out_cap = (total_in_bytes >= 128 * 1024 * 1024) ? (128 * 1024 * 1024) : (total_in_bytes > 0 ? (size_t)total_in_bytes + 1048576 : 16 * 1024 * 1024);
    void* out_buf = malloc(out_cap);
    if (!out_buf) {
        ZSTD_freeCCtx(cctx);
        if (out_fd != STDOUT_FILENO) close(out_fd);
        return TTZIP_ERR_OUT_OF_MEMORY;
    }
    ZSTD_outBuffer out = { out_buf, out_cap, 0 };
    
    for (size_t i = 0; i < input_count; i++) {
        const char* in_path = input_paths[i];
        if (!in_path || in_path[0] == '\0') continue;
        const char* slash = strrchr(in_path, '/');
        const char* rel = slash ? (slash + 1) : in_path;
        if (rel[0] == '\0') rel = in_path;
        
        int r = add_item_to_zstd_stream(cctx, &out, out_fd, in_path, rel, skip_mac_junk);
        if (r != TTZIP_OK) {
            free(out_buf);
            ZSTD_freeCCtx(cctx);
            if (out_fd != STDOUT_FILENO) close(out_fd);
            return r;
        }
    }
    
    uint8_t end_tar[1024] = {0};
    ZSTD_inBuffer in_end = { end_tar, 1024, 0 };
    while (in_end.pos < in_end.size) {
        ZSTD_compressStream2(cctx, &out, &in_end, ZSTD_e_continue);
        if (out.pos >= out.size - 65536) {
            flush_zstd_out(&out, out_fd);
        }
    }
    
    size_t remaining;
    do {
        remaining = ZSTD_compressStream2(cctx, &out, &(ZSTD_inBuffer){NULL, 0, 0}, ZSTD_e_end);
        flush_zstd_out(&out, out_fd);
    } while (remaining > 0);
    
    flush_zstd_out(&out, out_fd);
    
    free(out_buf);
    ZSTD_freeCCtx(cctx);
    if (out_fd != STDOUT_FILENO) close(out_fd);
    return TTZIP_OK;
}

static inline uint64_t parse_octal(const char* p, size_t len) {
    uint64_t val = 0;
    while (len > 0 && (*p == ' ' || *p == '\0')) { p++; len--; }
    while (len > 0 && *p >= '0' && *p <= '7') {
        val = (val << 3) + (*p - '0');
        p++; len--;
    }
    return val;
}

int ttzip_extract_tar_zstd_direct_c(
    const char* archive_path,
    const char* dest_dir,
    bool skip_mac_junk
) {
    if (!archive_path || !dest_dir) return TTZIP_ERR_INVALID_PARAM;
    
    ttzip_common_mkdir_p(dest_dir);

    int in_fd;
    if (strcmp(archive_path, "-") == 0) {
        in_fd = STDIN_FILENO;
    } else {
        in_fd = open(archive_path, O_RDONLY);
        if (in_fd < 0) return TTZIP_ERR_OPEN_FAILED;
    }

    struct stat in_st;
    if (in_fd != STDIN_FILENO && (fstat(in_fd, &in_st) != 0 || in_st.st_size == 0)) {
        close(in_fd);
        return TTZIP_ERR_FILE_NOT_FOUND;
    }

    ZSTD_DCtx* dctx = ZSTD_createDCtx();
    if (!dctx) {
        if (in_fd != STDIN_FILENO) close(in_fd);
        return TTZIP_ERR_OUT_OF_MEMORY;
    }

    size_t in_cap = 8 * 1024 * 1024;
    size_t out_cap = 16 * 1024 * 1024;
    void* in_buf = ttzip_aligned_alloc_16k(in_cap);
    void* out_buf = ttzip_aligned_alloc_16k(out_cap);
    if (!in_buf || !out_buf) {
        if (in_buf) ttzip_aligned_free_16k(in_buf);
        if (out_buf) ttzip_aligned_free_16k(out_buf);
        ZSTD_freeDCtx(dctx);
        if (in_fd != STDIN_FILENO) close(in_fd);
        return TTZIP_ERR_OUT_OF_MEMORY;
    }

    ZSTD_inBuffer in = { in_buf, 0, 0 };
    ZSTD_outBuffer out = { out_buf, out_cap, 0 };

    uint8_t tar_hdr[512];
    size_t hdr_pos = 0;
    char current_filename[1024] = {0};
    uint64_t current_file_remaining = 0;
    uint64_t current_pad_remaining = 0;
    int current_out_fd = -1;
    uint8_t* current_mmap_ptr = NULL;
    uint64_t current_mmap_size = 0;
    uint64_t current_file_written = 0;
    bool in_file_payload = false;
    bool in_long_name = false;
    char long_name_buf[4096] = {0};
    size_t long_name_pos = 0;
    uint64_t long_name_len = 0;
    int zero_block_count = 0;

    bool stream_ended = false;
    int ret_code = TTZIP_OK;

    while (!stream_ended) {
        if (in.pos >= in.size) {
            ssize_t rd = read(in_fd, in_buf, in_cap);
            if (rd < 0) { ret_code = TTZIP_ERR_OPEN_FAILED; break; }
            if (rd == 0) {
                if (out.pos == 0) break;
            }
            in.src = in_buf;
            in.size = (size_t)rd;
            in.pos = 0;
        }

        out.pos = 0;
        size_t d_res = ZSTD_decompressStream(dctx, &out, &in);
        if (ZSTD_isError(d_res)) {
            ret_code = TTZIP_ERR_CORRUPT_HEADER;
            break;
        }
        if (d_res == 0 && in.pos >= in.size) {
            stream_ended = true;
        }

        size_t chunk_avail = out.pos;
        size_t chunk_pos = 0;
        const uint8_t* p = (const uint8_t*)out.dst;

        while (chunk_pos < chunk_avail) {
            // 1. Write file payload
            if (in_file_payload) {
                size_t needed = (size_t)(current_file_remaining < (uint64_t)(chunk_avail - chunk_pos) ? current_file_remaining : (uint64_t)(chunk_avail - chunk_pos));
                if (needed > 0) {
                    if (current_mmap_ptr) {
                        memcpy(current_mmap_ptr + current_file_written, p + chunk_pos, needed);
                    } else if (current_out_fd >= 0) {
                        write(current_out_fd, p + chunk_pos, needed);
                    }
                    current_file_written += needed;
                    chunk_pos += needed;
                    current_file_remaining -= needed;
                }
                if (current_file_remaining == 0) {
                    if (current_mmap_ptr) {
                        munmap(current_mmap_ptr, (size_t)current_mmap_size);
                        current_mmap_ptr = NULL;
                        current_mmap_size = 0;
                    }
                    if (current_out_fd >= 0) {
                        close(current_out_fd);
                        current_out_fd = -1;
                    }
                    in_file_payload = false;
                    current_pad_remaining = ((current_file_written + 511) & ~(uint64_t)511) - current_file_written;
                }
                continue;
            }

            // 2. Skip alignment padding
            if (current_pad_remaining > 0) {
                size_t skip = (size_t)(current_pad_remaining < (uint64_t)(chunk_avail - chunk_pos) ? current_pad_remaining : (uint64_t)(chunk_avail - chunk_pos));
                chunk_pos += skip;
                current_pad_remaining -= skip;
                continue;
            }

            // 3. Read LongLink variable-length filename
            if (in_long_name) {
                size_t needed = (size_t)(long_name_len < (uint64_t)(chunk_avail - chunk_pos) ? long_name_len : (uint64_t)(chunk_avail - chunk_pos));
                if (needed > 0) {
                    if (long_name_pos + needed < sizeof(long_name_buf) - 1) {
                        memcpy(long_name_buf + long_name_pos, p + chunk_pos, needed);
                        long_name_pos += needed;
                    }
                    chunk_pos += needed;
                    long_name_len -= needed;
                }
                if (long_name_len == 0) {
                    long_name_buf[long_name_pos] = '\0';
                    in_long_name = false;
                    current_pad_remaining = ((long_name_pos + 511) & ~(uint64_t)511) - long_name_pos;
                }
                continue;
            }

            // 4. Assemble 512-byte Tar Header
            size_t needed_hdr = 512 - hdr_pos;
            size_t take = needed_hdr < (chunk_avail - chunk_pos) ? needed_hdr : (chunk_avail - chunk_pos);
            memcpy(tar_hdr + hdr_pos, p + chunk_pos, take);
            hdr_pos += take;
            chunk_pos += take;

            if (hdr_pos == 512) {
                hdr_pos = 0;
                bool is_all_zero = true;
                for (int i = 0; i < 512; i++) {
                    if (tar_hdr[i] != 0) { is_all_zero = false; break; }
                }
                if (is_all_zero) {
                    zero_block_count++;
                    if (zero_block_count >= 2) {
                        stream_ended = true;
                        break;
                    }
                    continue;
                }
                zero_block_count = 0;

                char typeflag = (char)tar_hdr[156];
                uint64_t fsize = parse_octal((const char*)tar_hdr + 124, 12);

                if (typeflag == 'L') { // GNU LongLink filename
                    in_long_name = true;
                    long_name_len = fsize;
                    long_name_pos = 0;
                    current_pad_remaining = 0;
                    continue;
                }

                char resolved_name[1024];
                if (long_name_buf[0] != '\0') {
                    strncpy(resolved_name, long_name_buf, sizeof(resolved_name) - 1);
                    resolved_name[sizeof(resolved_name) - 1] = '\0';
                    long_name_buf[0] = '\0';
                } else {
                    strncpy(resolved_name, (const char*)tar_hdr, 100);
                    resolved_name[100] = '\0';
                }

                if (skip_mac_junk && ttzip_is_mac_junk(resolved_name)) {
                    current_file_remaining = fsize;
                    current_pad_remaining = ((fsize + 511) & ~(uint64_t)511) - fsize;
                    continue;
                }

                char full_dest_path[4096];
                int r_join = ttzip_common_join_path(full_dest_path, sizeof(full_dest_path), dest_dir, resolved_name);
                if (r_join != TTZIP_OK) {
                    current_file_remaining = fsize;
                    current_pad_remaining = ((fsize + 511) & ~(uint64_t)511) - fsize;
                    continue;
                }

                if (typeflag == '5' || resolved_name[strlen(resolved_name) - 1] == '/') {
                    ttzip_common_mkdir_p(full_dest_path);
                } else {
                    char parent_dir[4096];
                    strncpy(parent_dir, full_dest_path, sizeof(parent_dir) - 1);
                    parent_dir[sizeof(parent_dir) - 1] = '\0';
                    char* ls = strrchr(parent_dir, '/');
                    if (ls && ls != parent_dir) {
                        *ls = '\0';
                        ttzip_common_mkdir_p(parent_dir);
                    }

                    if (fsize > 0) {
                        current_out_fd = open(full_dest_path, O_RDWR | O_CREAT | O_TRUNC | O_NOFOLLOW, 0644);
                        current_mmap_ptr = NULL;
                        current_mmap_size = 0;
                        current_file_written = 0;
                        if (current_out_fd >= 0 && fsize >= 1024 * 1024) {
                            if (ftruncate(current_out_fd, (off_t)fsize) == 0) {
                                void* map = mmap(NULL, (size_t)fsize, PROT_READ | PROT_WRITE, MAP_SHARED, current_out_fd, 0);
                                if (map != MAP_FAILED) {
                                    current_mmap_ptr = (uint8_t*)map;
                                    current_mmap_size = fsize;
                                    madvise(current_mmap_ptr, (size_t)fsize, MADV_SEQUENTIAL);
                                }
                            }
                        }
                        in_file_payload = true;
                        current_file_remaining = fsize;
                        current_pad_remaining = 0;
                    } else {
                        int empty_fd = open(full_dest_path, O_WRONLY | O_CREAT | O_TRUNC | O_NOFOLLOW, 0644);
                        if (empty_fd >= 0) close(empty_fd);
                    }
                }
            }
        }
    }

    if (current_mmap_ptr) {
        munmap(current_mmap_ptr, (size_t)current_mmap_size);
        current_mmap_ptr = NULL;
    }
    if (current_out_fd >= 0) close(current_out_fd);
    ttzip_aligned_free_16k(in_buf);
    ttzip_aligned_free_16k(out_buf);
    ZSTD_freeDCtx(dctx);
    if (in_fd >= 0 && in_fd != STDIN_FILENO) close(in_fd);
    return ret_code;
}
