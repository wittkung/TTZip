// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/CTTZipParser.h"
#include <stdio.h>
#include <string.h>

#if defined(__ARM_NEON) || defined(__ARM_NEON__) || defined(__aarch64__)
#include <arm_neon.h>
#endif

bool ttzip_find_eocd(const uint8_t* mapped, size_t file_size, ttzip_eocd_info_t* out_eocd) {
    if (!mapped || file_size < 22 || !out_eocd) return false;

    memset(out_eocd, 0, sizeof(ttzip_eocd_info_t));
    size_t search_back = (file_size > 65557) ? 65557 : file_size;
    size_t search_start = file_size - search_back;

    ssize_t eocd_pos = -1;
    uint32_t target_sig = 0x06054b50;

#if defined(__ARM_NEON) || defined(__ARM_NEON__) || defined(__aarch64__)
    uint32x4_t sig_vec = vdupq_n_u32(target_sig);
    ssize_t pos = (ssize_t)file_size - 22;
    for (; pos >= (ssize_t)search_start + 16; pos -= 16) {
        uint32x4_t chunk_vec = vld1q_u32((const uint32_t*)(mapped + pos - 12));
        uint32x4_t cmp = vceqq_u32(chunk_vec, sig_vec);
        if (vmaxvq_u32(cmp) != 0) {
            for (ssize_t j = pos; j >= pos - 15 && j >= (ssize_t)search_start; j--) {
                if (read_u32_le(mapped + j) == target_sig) {
                    eocd_pos = j;
                    break;
                }
            }
            if (eocd_pos >= 0) break;
        }
    }
    if (eocd_pos < 0) {
        for (; pos >= (ssize_t)search_start; pos--) {
            if (read_u32_le(mapped + pos) == target_sig) {
                eocd_pos = pos;
                break;
            }
        }
    }
#else
    for (ssize_t pos = (ssize_t)file_size - 22; pos >= (ssize_t)search_start; pos--) {
        if (read_u32_le(mapped + pos) == target_sig) {
            eocd_pos = pos;
            break;
        }
    }
#endif

    if (eocd_pos >= 0) {
        size_t p = (size_t)eocd_pos;
        uint16_t entries16 = read_u16_le(mapped + p + 10);
        uint32_t cd_size32 = read_u32_le(mapped + p + 12);
        uint32_t cd_off32 = read_u32_le(mapped + p + 16);

        out_eocd->total_entries = entries16;
        out_eocd->cd_size = cd_size32;
        out_eocd->cd_offset = cd_off32;

        // Check Zip64 EOCD Locator (20 bytes before EOCD)
        if (p >= 20 && read_u32_le(mapped + p - 20) == 0x07064b50) {
            uint64_t z64_eocd_off = read_u64_le(mapped + p - 20 + 8);
            if (z64_eocd_off + 56 <= file_size && read_u32_le(mapped + z64_eocd_off) == 0x06064b50) {
                out_eocd->total_entries = read_u64_le(mapped + z64_eocd_off + 32);
                out_eocd->cd_size = read_u64_le(mapped + z64_eocd_off + 40);
                out_eocd->cd_offset = read_u64_le(mapped + z64_eocd_off + 48);
            }
        }
        return true;
    }
    return false;
}

bool ttzip_parse_cdfh_entry(const uint8_t* mapped, size_t file_size, size_t curr_pos, ttzip_parsed_entry_t* out_entry, size_t* out_next_pos) {
    if (!mapped || curr_pos + 46 > file_size || !out_entry) return false;
    if (read_u32_le(mapped + curr_pos) != 0x02014b50) return false;

    memset(out_entry, 0, sizeof(ttzip_parsed_entry_t));

    uint16_t flag = read_u16_le(mapped + curr_pos + 8);
    uint16_t method = read_u16_le(mapped + curr_pos + 10);
    uint32_t crc32 = read_u32_le(mapped + curr_pos + 16);
    uint32_t comp_size32 = read_u32_le(mapped + curr_pos + 20);
    uint32_t uncomp_size32 = read_u32_le(mapped + curr_pos + 24);
    uint16_t fn_len = read_u16_le(mapped + curr_pos + 28);
    uint16_t extra_len = read_u16_le(mapped + curr_pos + 30);
    uint16_t comment_len = read_u16_le(mapped + curr_pos + 32);
    uint32_t ext_attr = read_u32_le(mapped + curr_pos + 38);
    uint32_t lfh_offset32 = read_u32_le(mapped + curr_pos + 42);

    size_t rec_len = 46 + fn_len + extra_len + comment_len;
    if (curr_pos + rec_len > file_size) return false;

    if (out_next_pos) *out_next_pos = curr_pos + rec_len;

    size_t copy_fn_len = (fn_len < sizeof(out_entry->rel_path) - 1) ? fn_len : (sizeof(out_entry->rel_path) - 1);
    memcpy(out_entry->rel_path, mapped + curr_pos + 46, copy_fn_len);
    out_entry->rel_path[copy_fn_len] = '\0';
    for (char *p = out_entry->rel_path; *p; p++) {
        if (*p == '\\') *p = '/';
    }

    out_entry->flag = flag;
    out_entry->compression_method = method;
    out_entry->actual_method = method;
    out_entry->crc32 = crc32;
    out_entry->uncompressed_size = uncomp_size32;
    out_entry->compressed_size = comp_size32;
    out_entry->lfh_offset = lfh_offset32;
    out_entry->is_encrypted = (flag & 0x0001) != 0;

    // Parse Extra Fields (Zip64 0x0001 & WinZip AES 0x9901)
    if (extra_len >= 4) {
        size_t extra_pos = curr_pos + 46 + fn_len;
        size_t extra_end = extra_pos + extra_len;

        while (extra_pos + 4 <= extra_end) {
            uint16_t h_id = read_u16_le(mapped + extra_pos);
            uint16_t d_sz = read_u16_le(mapped + extra_pos + 2);
            size_t block_end = extra_pos + 4 + d_sz;
            if (block_end > extra_end) break;

            if (h_id == 0x0001) { // Zip64 Extra Field
                size_t p = extra_pos + 4;
                if (uncomp_size32 == 0xffffffff && p + 8 <= block_end) {
                    out_entry->uncompressed_size = read_u64_le(mapped + p);
                    p += 8;
                }
                if (comp_size32 == 0xffffffff && p + 8 <= block_end) {
                    out_entry->compressed_size = read_u64_le(mapped + p);
                    p += 8;
                }
                if (lfh_offset32 == 0xffffffff && p + 8 <= block_end) {
                    out_entry->lfh_offset = read_u64_le(mapped + p);
                }
            } else if (h_id == 0x9901 && d_sz >= 7) { // WinZip AES Extra Field
                out_entry->aes_strength = mapped[extra_pos + 8];
                out_entry->actual_method = read_u16_le(mapped + extra_pos + 9);
            }
            extra_pos = block_end;
        }
    }

    // Directory Classification
    if (copy_fn_len > 0 && out_entry->rel_path[copy_fn_len - 1] == '/') {
        out_entry->is_directory = true;
    } else if ((ext_attr >> 16) != 0) {
        uint32_t posix_mode = ext_attr >> 16;
        if ((posix_mode & 0170000) == 0040000) out_entry->is_directory = true;
    } else if ((ext_attr & 0x10) != 0) {
        out_entry->is_directory = true;
    }

    return true;
}
