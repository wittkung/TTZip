// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_7z_header_parser.c
 * @brief TTZip native 7Z archive header and metadata zero-copy parser.
 */

#include "include/ttzip_7z_header_parser.h"
#include "include/CTTZipCommon.h"
#include "include/CTTZipDiagnostics.h"
#include <stdlib.h>
#include <string.h>

static const uint64_t k7zVarintPayloadMask[9] = {
    0x0000000000000000ULL, // k = 0
    0x00000000000000FFULL, // k = 1
    0x000000000000FFFFULL, // k = 2
    0x0000000000FFFFFFULL, // k = 3
    0x00000000FFFFFFFFULL, // k = 4
    0x000000FFFFFFFFFFULL, // k = 5
    0x0000FFFFFFFFFFFFULL, // k = 6
    0x00FFFFFFFFFFFFFFULL, // k = 7
    0xFFFFFFFFFFFFFFFFULL  // k = 8
};

size_t ttzip_7z_read_varint(const uint8_t* buf, size_t len, uint64_t* val) {
    if (__builtin_expect(len == 0 || !val, 0)) return 0;
    uint8_t first = buf[0];
    unsigned k = (unsigned)__builtin_clz((~(uint32_t)first << 24) | 0x00800000);

    if (__builtin_expect(len >= 9, 1)) {
        uint64_t raw_payload;
        memcpy(&raw_payload, buf + 1, sizeof(uint64_t));
        uint64_t high_part = ((uint64_t)(first & (0xFF >> (k + 1)))) << ((k & 7) * 8);
        uint64_t low_part = raw_payload & k7zVarintPayloadMask[k];
        *val = high_part | low_part;
        return 1 + k;
    } else {
        if (1 + k > len) return 0;
        uint64_t raw_payload = 0;
        memcpy(&raw_payload, buf + 1, k);
        uint64_t high_part = ((uint64_t)(first & (0xFF >> (k + 1)))) << ((k & 7) * 8);
        *val = high_part | raw_payload;
        return 1 + k;
    }
}

int ttzip_7z_parse_header_metadata(
    const uint8_t* mapped_data,
    size_t file_size,
    ttzip_7z_header_info_t* out_info
) {
    if (!mapped_data || file_size < 32 || !out_info) return TTZIP_ERR_INVALID_PARAM;
    memset(out_info, 0, sizeof(ttzip_7z_header_info_t));
    out_info->primary_method_id = 0x21; // Default LZMA2
    out_info->aes_num_cycles_power = 19;

    const uint8_t* sig = mapped_data;
    if (sig[0] != 0x37 || sig[1] != 0x7A || sig[2] != 0xBC || sig[3] != 0xAF || sig[4] != 0x27 || sig[5] != 0x1C) {
        return TTZIP_ERR_INVALID_PARAM;
    }

    uint64_t next_header_offset = 0;
    uint64_t header_size = 0;
    memcpy(&next_header_offset, sig + 12, 8);
    memcpy(&header_size, sig + 20, 8);

    size_t header_pos = 32 + (size_t)next_header_offset;
    if (header_pos + header_size > file_size) {
        return TTZIP_ERR_CORRUPT_HEADER;
    }

    out_info->payload_offset = 32;
    out_info->payload_len = (size_t)next_header_offset;

    const uint8_t* hp = sig + header_pos;
    size_t hlen = (size_t)header_size;

    size_t files_cap = 1024;
    out_info->files = (ttzip_7z_file_meta_t*)calloc(files_cap, sizeof(ttzip_7z_file_meta_t));
    if (!out_info->files) return TTZIP_ERR_OUT_OF_MEMORY;

    size_t stream_sizes_cap = 1024;
    out_info->stream_sizes = (uint64_t*)calloc(stream_sizes_cap, sizeof(uint64_t));
    if (!out_info->stream_sizes) {
        ttzip_7z_free_header_info(out_info);
        return TTZIP_ERR_OUT_OF_MEMORY;
    }

    size_t coder_unpack_sizes_cap = 1024;
    out_info->coder_unpack_sizes = (uint64_t*)calloc(coder_unpack_sizes_cap, sizeof(uint64_t));
    if (!out_info->coder_unpack_sizes) {
        ttzip_7z_free_header_info(out_info);
        return TTZIP_ERR_OUT_OF_MEMORY;
    }

    size_t hpos = 0;
    while (hpos < hlen) {
        uint8_t tag = hp[hpos++];
        if (tag == 0x00) continue;
        if (tag == 0x01 || tag == 0x04) continue; // kHeader, kMainStreamsInfo

        if (tag == 0x06) { // kPackInfo
            uint64_t packPos = 0, numPackStreams = 0;
            hpos += ttzip_7z_read_varint(hp + hpos, hlen - hpos, &packPos);
            hpos += ttzip_7z_read_varint(hp + hpos, hlen - hpos, &numPackStreams);
            while (hpos < hlen) {
                uint8_t ptag = hp[hpos++];
                if (ptag == 0x00) break;
                if (ptag == 0x09) { // kSize
                    for (size_t i = 0; i < numPackStreams; i++) {
                        uint64_t dummy = 0;
                        hpos += ttzip_7z_read_varint(hp + hpos, hlen - hpos, &dummy);
                    }
                } else if (ptag == 0x0A) { // kCRC
                    uint8_t allDefined = hp[hpos++];
                    if (allDefined) hpos += numPackStreams * 4;
                } else {
                    uint64_t sz = 0;
                    hpos += ttzip_7z_read_varint(hp + hpos, hlen - hpos, &sz);
                    hpos += (size_t)sz;
                }
            }
        } else if (tag == 0x07) { // kUnpackInfo
            uint64_t total_coders = 0;
            while (hpos < hlen) {
                uint8_t utag = hp[hpos++];
                if (utag == 0x00) break;
                if (utag == 0x0B) { // kFolder
                    uint64_t numFolders = 0;
                    hpos += ttzip_7z_read_varint(hp + hpos, hlen - hpos, &numFolders);
                    out_info->total_folders = numFolders;
                    uint8_t external = hp[hpos++];
                    if (external == 0) {
                        for (size_t i = 0; i < numFolders; i++) {
                            uint64_t numCoders = 0;
                            hpos += ttzip_7z_read_varint(hp + hpos, hlen - hpos, &numCoders);
                            total_coders += numCoders;
                            for (size_t j = 0; j < numCoders; j++) {
                                uint8_t flags = hp[hpos++];
                                uint8_t method_size = flags & 0x0F;
                                uint64_t mid = 0;
                                for (uint8_t m = 0; m < method_size && m < 8; m++) {
                                    mid = (mid << 8) | hp[hpos + m];
                                }
                                hpos += method_size;
                                if (mid == 0x06F10701) {
                                    out_info->is_encrypted = true;
                                } else {
                                    out_info->primary_method_id = mid;
                                }
                                if (flags & 0x10) {
                                    uint64_t in_streams = 0, out_streams = 0;
                                    hpos += ttzip_7z_read_varint(hp + hpos, hlen - hpos, &in_streams);
                                    hpos += ttzip_7z_read_varint(hp + hpos, hlen - hpos, &out_streams);
                                }
                                if (flags & 0x20) {
                                    uint64_t props_sz = 0;
                                    hpos += ttzip_7z_read_varint(hp + hpos, hlen - hpos, &props_sz);
                                    if (mid == 0x06F10701 && props_sz >= 1) {
                                        const uint8_t* p = hp + hpos;
                                        uint8_t b0 = p[0];
                                        out_info->aes_num_cycles_power = b0 & 0x3F;
                                        size_t p_off = 1;
                                        if ((b0 & 0xC0) != 0 && props_sz >= 2) {
                                            uint8_t b1 = p[1];
                                            p_off = 2;
                                            uint8_t s_len = b1 & 0x0F;
                                            uint8_t iv_len_enc = (b1 >> 4) & 0x0F;
                                            uint8_t iv_len = (iv_len_enc > 0) ? (iv_len_enc + 1) : 0;
                                            if (s_len > 0 && p_off + s_len <= props_sz) {
                                                memcpy(out_info->aes_salt, p + p_off, s_len < 16 ? s_len : 16);
                                                out_info->aes_salt_len = s_len;
                                                p_off += s_len;
                                            }
                                            if (iv_len > 0 && p_off + iv_len <= props_sz) {
                                                memcpy(out_info->aes_iv, p + p_off, iv_len < 16 ? iv_len : 16);
                                                out_info->aes_iv_len = iv_len;
                                                p_off += iv_len;
                                            }
                                        }
                                    } else if (mid != 0x06F10701 && props_sz > 0 && props_sz <= 32) {
                                        memcpy(out_info->coder_props, hp + hpos, props_sz);
                                        out_info->coder_props_len = (size_t)props_sz;
                                    }
                                    hpos += (size_t)props_sz;
                                }
                            }
                            if (numCoders > 1) {
                                uint64_t numBindPairs = numCoders - 1;
                                for (uint64_t b = 0; b < numBindPairs; b++) {
                                    uint64_t in_idx = 0, out_idx = 0;
                                    hpos += ttzip_7z_read_varint(hp + hpos, hlen - hpos, &in_idx);
                                    hpos += ttzip_7z_read_varint(hp + hpos, hlen - hpos, &out_idx);
                                }
                                uint64_t numPackedStreams = numCoders - numBindPairs;
                                if (numPackedStreams > 1) {
                                    for (uint64_t p = 0; p < numPackedStreams; p++) {
                                        uint64_t stream_idx = 0;
                                        hpos += ttzip_7z_read_varint(hp + hpos, hlen - hpos, &stream_idx);
                                    }
                                }
                            }
                        }
                    }
                } else if (utag == 0x0C) { // kCodersUnpackSize
                    size_t read_limit = total_coders > 0 ? (size_t)total_coders : (out_info->total_folders > 0 ? (size_t)out_info->total_folders : 1);
                    for (size_t i = 0; i < read_limit && hpos < hlen; i++) {
                        uint64_t folder_unpack_sz = 0;
                        size_t rd = ttzip_7z_read_varint(hp + hpos, hlen - hpos, &folder_unpack_sz);
                        if (rd == 0) break;
                        hpos += rd;
                        if (out_info->num_coder_unpack_sizes >= coder_unpack_sizes_cap) {
                            size_t new_cap = (coder_unpack_sizes_cap * 2) + 64;
                            size_t alloc_bytes = 0;
                            if (ttzip_mul_overflow(sizeof(uint64_t), new_cap, &alloc_bytes)) {
                                return TTZIP_ERR_OUT_OF_MEMORY;
                            }
                            uint64_t* new_arr = (uint64_t*)realloc(out_info->coder_unpack_sizes, alloc_bytes);
                            if (!new_arr) return TTZIP_ERR_OUT_OF_MEMORY;
                            out_info->coder_unpack_sizes = new_arr;
                            coder_unpack_sizes_cap = new_cap;
                        }
                        out_info->coder_unpack_sizes[out_info->num_coder_unpack_sizes++] = folder_unpack_sz;
                    }
                } else if (utag == 0x0A) { // kCRC
                    uint8_t allDefined = hp[hpos++];
                    size_t folders_count = out_info->total_folders > 0 ? (size_t)out_info->total_folders : 1;
                    if (allDefined) {
                        hpos += folders_count * 4;
                    }
                } else {
                    uint64_t sz = 0;
                    hpos += ttzip_7z_read_varint(hp + hpos, hlen - hpos, &sz);
                    hpos += (size_t)sz;
                }
            }
        } else if (tag == 0x08) { // kSubStreamsInfo
            uint64_t num_streams_val = 1;
            while (hpos < hlen) {
                uint8_t stag = hp[hpos++];
                if (stag == 0x00) break;
                if (stag == 0x0D) { // kNumUnPackStream
                    hpos += ttzip_7z_read_varint(hp + hpos, hlen - hpos, &num_streams_val);
                } else if (stag == 0x09) { // kSize
                    for (size_t i = 0; i < num_streams_val - 1; i++) {
                        uint64_t sval = 0;
                        size_t rd = ttzip_7z_read_varint(hp + hpos, hlen - hpos, &sval);
                        if (rd == 0) break;
                        hpos += rd;
                        if (out_info->num_stream_sizes >= stream_sizes_cap) {
                            size_t new_cap = (stream_sizes_cap * 2) + (size_t)num_streams_val + 64;
                            size_t alloc_bytes = 0;
                            if (ttzip_mul_overflow(sizeof(uint64_t), new_cap, &alloc_bytes)) {
                                return TTZIP_ERR_OUT_OF_MEMORY;
                            }
                            uint64_t* new_stream_sizes = (uint64_t*)realloc(out_info->stream_sizes, alloc_bytes);
                            if (!new_stream_sizes) return TTZIP_ERR_OUT_OF_MEMORY;
                            out_info->stream_sizes = new_stream_sizes;
                            stream_sizes_cap = new_cap;
                        }
                        out_info->stream_sizes[out_info->num_stream_sizes++] = sval;
                    }
                } else if (stag == 0x0A) { // kCRC
                    uint8_t allDefined = hp[hpos++];
                    if (allDefined) {
                        if (!out_info->stream_crcs) {
                            out_info->stream_crcs = (uint32_t*)calloc((size_t)num_streams_val + 64, sizeof(uint32_t));
                        }
                        for (size_t i = 0; i < num_streams_val && hpos + 4 <= hlen; i++) {
                            uint32_t c = 0;
                            memcpy(&c, hp + hpos, 4);
                            hpos += 4;
                            if (out_info->stream_crcs) {
                                out_info->stream_crcs[out_info->num_stream_crcs++] = c;
                            }
                        }
                    }
                } else {
                    uint64_t sz = 0;
                    hpos += ttzip_7z_read_varint(hp + hpos, hlen - hpos, &sz);
                    hpos += (size_t)sz;
                }
            }
        } else if (tag == 0x05) { // kFilesInfo
            uint64_t numFilesVal = 0;
            size_t rd = ttzip_7z_read_varint(hp + hpos, hlen - hpos, &numFilesVal);
            if (rd == 0) {
                ttzip_7z_free_header_info(out_info);
                return TTZIP_ERR_CORRUPT_HEADER;
            }
            hpos += rd;

            size_t remaining_bytes = (hlen > hpos) ? (hlen - hpos) : 0;
            if (numFilesVal > (remaining_bytes / 2) || numFilesVal > (SIZE_MAX / sizeof(ttzip_7z_file_meta_t)) || numFilesVal > 10000000) {
                ttzip_7z_free_header_info(out_info);
                return TTZIP_ERR_CORRUPT_HEADER;
            }

            if (numFilesVal > files_cap) {
                size_t new_cap = (size_t)numFilesVal + 64;
                ttzip_7z_file_meta_t* new_files = (ttzip_7z_file_meta_t*)realloc(out_info->files, new_cap * sizeof(ttzip_7z_file_meta_t));
                if (!new_files) {
                    ttzip_7z_free_header_info(out_info);
                    return TTZIP_ERR_OUT_OF_MEMORY;
                }
                out_info->files = new_files;
                files_cap = new_cap;
            }
            out_info->num_files = (size_t)numFilesVal;
            while (hpos < hlen) {
                uint8_t ftag = hp[hpos++];
                if (ftag == 0x00) break;
                uint64_t prop_size = 0;
                hpos += ttzip_7z_read_varint(hp + hpos, hlen - hpos, &prop_size);
                if (ftag == 0x0E) { // kEmptyStream
                    for (size_t i = 0; i < out_info->num_files; i++) {
                        size_t byte_idx = i / 8;
                        size_t bit_idx = 7 - (i % 8);
                        if (byte_idx < (size_t)prop_size) {
                            uint8_t b = hp[hpos + byte_idx];
                            if ((b >> bit_idx) & 1) {
                                out_info->files[i].is_empty_stream = true;
                            }
                        }
                    }
                    hpos += (size_t)prop_size;
                } else if (ftag == 0x0F) { // kEmptyFile
                    hpos += (size_t)prop_size;
                } else if (ftag == 0x10) { // kAnti
                    hpos += (size_t)prop_size;
                } else if (ftag == 0x11) { // kName
                    uint8_t ext = hp[hpos++];
                    (void)ext;
                    size_t name_bytes_left = (size_t)prop_size - 1;
                    size_t name_pos = hpos;
                    for (size_t f = 0; f < out_info->num_files; f++) {
                        char utf8_name[1024] = {0};
                        size_t u8_idx = 0;
                        while (name_bytes_left >= 2) {
                            uint16_t ch = hp[name_pos] | ((uint16_t)hp[name_pos + 1] << 8);
                            name_pos += 2;
                            name_bytes_left -= 2;
                            if (ch == 0) break;
                            if (ch < 0x80 && u8_idx < sizeof(utf8_name) - 1) {
                                utf8_name[u8_idx++] = (char)ch;
                            } else if (ch < 0x800 && u8_idx < sizeof(utf8_name) - 2) {
                                utf8_name[u8_idx++] = (char)(0xC0 | (ch >> 6));
                                utf8_name[u8_idx++] = (char)(0x80 | (ch & 0x3F));
                            } else if (u8_idx < sizeof(utf8_name) - 3) {
                                utf8_name[u8_idx++] = (char)(0xE0 | (ch >> 12));
                                utf8_name[u8_idx++] = (char)(0x80 | ((ch >> 6) & 0x3F));
                                utf8_name[u8_idx++] = (char)(0x80 | (ch & 0x3F));
                            }
                        }
                        utf8_name[u8_idx] = '\0';
                        snprintf(out_info->files[f].rel_path, sizeof(out_info->files[f].rel_path), "%s", utf8_name);
                    }
                    hpos += (size_t)prop_size - 1;
                } else if (ftag == 0x15) { // kAttributes
                    size_t prop_end = hpos + (size_t)prop_size;
                    if (hpos < prop_end) {
                        uint8_t allDefined = hp[hpos++];
                        if (allDefined == 1 && hpos < prop_end) {
                            uint8_t external = hp[hpos++];
                            if (external == 0) {
                                for (size_t f = 0; f < out_info->num_files && hpos + 4 <= prop_end; f++) {
                                    uint32_t attr = 0;
                                    memcpy(&attr, hp + hpos, 4);
                                    hpos += 4;
                                    if (attr & 0x10) { // FILE_ATTRIBUTE_DIRECTORY
                                        out_info->files[f].is_dir = true;
                                    }
                                }
                            }
                        }
                    }
                    hpos = prop_end;
                } else {
                    hpos += (size_t)prop_size;
                }
            }
        } else {
            uint64_t sz = 0;
            hpos += ttzip_7z_read_varint(hp + hpos, hlen - hpos, &sz);
            hpos += (size_t)sz;
        }
    }

    if (out_info->num_stream_sizes > 0 && out_info->num_coder_unpack_sizes > 0) {
        uint64_t folder_unpack = out_info->coder_unpack_sizes[0];
        uint64_t sum_streams = 0;
        for (size_t i = 0; i < out_info->num_stream_sizes; i++) {
            sum_streams += out_info->stream_sizes[i];
        }
        if (folder_unpack > sum_streams) {
            if (out_info->num_stream_sizes >= stream_sizes_cap) {
                size_t new_cap = stream_sizes_cap + 64;
                size_t alloc_bytes = 0;
                if (ttzip_mul_overflow(sizeof(uint64_t), new_cap, &alloc_bytes)) {
                    return TTZIP_ERR_OUT_OF_MEMORY;
                }
                uint64_t* new_arr = (uint64_t*)realloc(out_info->stream_sizes, alloc_bytes);
                if (!new_arr) return TTZIP_ERR_OUT_OF_MEMORY;
                out_info->stream_sizes = new_arr;
                stream_sizes_cap = new_cap;
            }
            out_info->stream_sizes[out_info->num_stream_sizes++] = folder_unpack - sum_streams;
        }
    } else if (out_info->num_stream_sizes == 0 && out_info->num_coder_unpack_sizes > 0) {
        if (out_info->is_encrypted && out_info->total_folders == 1) {
            if (out_info->num_stream_sizes < stream_sizes_cap) {
                out_info->stream_sizes[out_info->num_stream_sizes++] = out_info->coder_unpack_sizes[0];
            }
        } else {
            for (size_t i = 0; i < out_info->num_coder_unpack_sizes; i++) {
                if (out_info->num_stream_sizes >= stream_sizes_cap) {
                    size_t new_cap = stream_sizes_cap + 64;
                    size_t alloc_bytes = 0;
                    if (ttzip_mul_overflow(sizeof(uint64_t), new_cap, &alloc_bytes)) {
                        return TTZIP_ERR_OUT_OF_MEMORY;
                    }
                    uint64_t* new_arr = (uint64_t*)realloc(out_info->stream_sizes, alloc_bytes);
                    if (!new_arr) return TTZIP_ERR_OUT_OF_MEMORY;
                    out_info->stream_sizes = new_arr;
                    stream_sizes_cap = new_cap;
                }
                out_info->stream_sizes[out_info->num_stream_sizes++] = out_info->coder_unpack_sizes[i];
            }
        }
    }
    ttzip_log(0, "[7zHeaderParser] num_files=%zu, num_streams=%zu, is_enc=%d", out_info->num_files, out_info->num_stream_sizes, (int)out_info->is_encrypted);

    return TTZIP_OK;
}

void ttzip_7z_free_header_info(ttzip_7z_header_info_t* info) {
    if (!info) return;
    if (info->files) { free(info->files); info->files = NULL; }
    if (info->stream_sizes) { free(info->stream_sizes); info->stream_sizes = NULL; }
    if (info->coder_unpack_sizes) { free(info->coder_unpack_sizes); info->coder_unpack_sizes = NULL; }
    if (info->stream_crcs) { free(info->stream_crcs); info->stream_crcs = NULL; }
}
