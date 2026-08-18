// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/CTTZipBridge_Mmap.h"
#include "include/CTTZipBridge.h"
#include "include/CTTZipCommon.h"
#include "include/CTTZipParser.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

#if defined(__ARM_NEON) || defined(__ARM_NEON__)
#include <arm_neon.h>
#endif

static const char* sanitize_relative_path(const char* raw_path) {
    if (!raw_path) return "unnamed";
    while (*raw_path == '/' || (raw_path[0] == '.' && raw_path[1] == '/')) {
        raw_path++;
    }
    if (strlen(raw_path) == 0) {
        return "unnamed";
    }
    return raw_path;
}

int ttzip_mmap_zip_inspect(const char* archive_path, void* context, ttzip_entry_callback callback) {
    if (!archive_path || !callback) return TTZIP_ERR_INVALID_PARAM;
    
    int ret_val = TTZIP_ERR_INVALID_PARAM;
    const uint8_t* mapped = MAP_FAILED;
    size_t file_size = 0;
    
    int fd = open(archive_path, O_RDONLY);
    if (fd < 0) return TTZIP_ERR_OPEN_FAILED;
    
    struct stat st;
    if (fstat(fd, &st) != 0 || st.st_size < 22) {
        close(fd);
        return TTZIP_ERR_CORRUPT_HEADER;
    }
    
    file_size = ttzip_clamp_size((uint64_t)st.st_size);
    mapped = (const uint8_t*)mmap(NULL, file_size, PROT_READ, MAP_SHARED, fd, 0);
    close(fd);
    
    if (mapped == MAP_FAILED) {
        return TTZIP_ERR_MMAP_FAILED;
    }
    
    size_t max_search = (file_size > 65557) ? 65557 : file_size;
    size_t search_start = file_size - max_search;
    ssize_t eocd_pos = -1;
    
#if defined(__ARM_NEON) || defined(__ARM_NEON__)
    uint32_t target_sig = 0x06054b50;
    uint32x4_t sig_vec = vdupq_n_u32(target_sig);
    
    ssize_t i = (ssize_t)file_size - 22;
    for (; i >= (ssize_t)search_start + 16; i -= 16) {
        uint32x4_t chunk_vec = vld1q_u32((const uint32_t*)(mapped + i - 12));
        uint32x4_t cmp = vceqq_u32(chunk_vec, sig_vec);
        if (vmaxvq_u32(cmp) != 0) {
            for (ssize_t j = i; j >= i - 15 && j >= (ssize_t)search_start; j--) {
                if (read_u32_le(mapped + j) == target_sig) {
                    eocd_pos = j;
                    break;
                }
            }
            if (eocd_pos >= 0) break;
        }
    }
    if (eocd_pos < 0) {
        for (; i >= (ssize_t)search_start; i--) {
            if (read_u32_le(mapped + i) == target_sig) {
                eocd_pos = i;
                break;
            }
        }
    }
#else
    for (ssize_t i = (ssize_t)file_size - 22; i >= (ssize_t)search_start; i--) {
        if (mapped[i] == 0x50 && mapped[i+1] == 0x4b && mapped[i+2] == 0x05 && mapped[i+3] == 0x06) {
            eocd_pos = i;
            break;
        }
    }
#endif
    
    if (eocd_pos < 0) {
        ret_val = TTZIP_ERR_CORRUPT_HEADER;
        goto cleanup;
    }
    
    uint64_t cd_offset = read_u32_le(mapped + eocd_pos + 16);
    uint64_t total_entries = read_u16_le(mapped + eocd_pos + 10);
    
    if (cd_offset == 0xFFFFFFFF || total_entries == 0xFFFF) {
        if (eocd_pos >= 20) {
            size_t locator_pos = eocd_pos - 20;
            if (mapped[locator_pos] == 0x50 && mapped[locator_pos+1] == 0x4b && mapped[locator_pos+2] == 0x06 && mapped[locator_pos+3] == 0x07) {
                uint64_t zip64_eocd_offset = read_u64_le(mapped + locator_pos + 8);
                if (zip64_eocd_offset + 56 <= file_size && mapped[zip64_eocd_offset] == 0x50 && mapped[zip64_eocd_offset+1] == 0x4b && mapped[zip64_eocd_offset+2] == 0x06 && mapped[zip64_eocd_offset+3] == 0x06) {
                    total_entries = read_u64_le(mapped + zip64_eocd_offset + 32);
                    cd_offset = read_u64_le(mapped + zip64_eocd_offset + 48);
                }
            }
        }
    }
    
    if (cd_offset >= file_size) {
        ret_val = TTZIP_ERR_INVALID_OFFSET;
        goto cleanup;
    }
    
    size_t curr_pos = (size_t)cd_offset;
    for (uint64_t i = 0; i < total_entries && curr_pos + 46 <= file_size; i++) {
        uint32_t sig = read_u32_le(mapped + curr_pos);
        if (sig != 0x02014b50) break;
        
        uint16_t fn_len = read_u16_le(mapped + curr_pos + 28);
        uint16_t extra_len = read_u16_le(mapped + curr_pos + 30);
        uint16_t comment_len = read_u16_le(mapped + curr_pos + 32);
        uint32_t ext_attr = read_u32_le(mapped + curr_pos + 38);
        
        size_t record_len = 46 + fn_len + extra_len + comment_len;
        if (curr_pos + record_len > file_size) break;
        
        const char* raw_filename = (const char*)(mapped + curr_pos + 46);
        char name_buf[4096];
        size_t copy_len = (fn_len < sizeof(name_buf) - 1) ? fn_len : (sizeof(name_buf) - 1);
        memcpy(name_buf, raw_filename, copy_len);
        name_buf[copy_len] = '\0';
        
        uint64_t uncomp_size = read_u32_le(mapped + curr_pos + 24);
        if (uncomp_size == 0xFFFFFFFF && extra_len >= 4) {
            const uint8_t* extra_ptr = mapped + curr_pos + 46 + fn_len;
            size_t extra_bytes = extra_len;
            while (extra_bytes >= 4) {
                uint16_t header_id = read_u16_le(extra_ptr);
                uint16_t data_size = read_u16_le(extra_ptr + 2);
                if (header_id == 0x0001 && data_size >= 8) {
                    uncomp_size = read_u64_le(extra_ptr + 4);
                    break;
                }
                extra_ptr += 4 + data_size;
                if (extra_bytes >= 4 + data_size) {
                    extra_bytes -= (4 + data_size);
                } else break;
            }
        }
        
        bool is_dir = (copy_len > 0 && name_buf[copy_len - 1] == '/') || ((ext_attr & 0x10) != 0);
        const char* clean_path = sanitize_relative_path(name_buf);
        callback(context, clean_path, (int64_t)uncomp_size, is_dir);
        
        curr_pos += record_len;
    }
    
    ret_val = TTZIP_OK;

cleanup:
    if (mapped != MAP_FAILED) {
        munmap((void*)mapped, file_size);
    }
    return ret_val;
}
