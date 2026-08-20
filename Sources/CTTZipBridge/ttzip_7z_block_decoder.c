// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_7z_block_decoder.c
 * @brief TTZip native 7Z parallel multi-block payload decoder (LZMA2, Zstd, Direct Store).
 */

#include "include/ttzip_7z_block_decoder.h"
#include "include/CTTZipCommon.h"
#include "include/CTTZipDiagnostics.h"
#include "include/CTTZipSliceProfiler.h"
#include "include/ttzip_lzma2_dec_native.h"
#include "include/CTTZipBridge_Zstd.h"
#include "include/CTTZipStreamCoder.h"
#include "include/ttzip_platform.h"
#include "include/ttzip_threadpool.h"
#include <stdlib.h>
#include <string.h>
#include <stdatomic.h>

typedef struct {
    ttzip_7z_dec_chunk_t* blocks;
    uint8_t* unpack_buf;
    size_t total_unpack_bytes;
    _Atomic int decode_error;
} lzma2_block_decode_arg_t;

static void lzma2_block_decode_worker(size_t b, void* arg) {
    lzma2_block_decode_arg_t* ctx = (lzma2_block_decode_arg_t*)arg;
    size_t actual_block_unpacked = 0;
    size_t cap = ctx->blocks[b].unpack_size > 0 ? ctx->blocks[b].unpack_size : (ctx->total_unpack_bytes - ctx->blocks[b].unpack_offset);
    int dec_res = ttzip_lzma2_decode_block_native(
        ctx->blocks[b].pack_ptr,
        ctx->blocks[b].pack_size,
        ctx->unpack_buf + ctx->blocks[b].unpack_offset,
        cap,
        &actual_block_unpacked
    );
    if (dec_res != 0) {
        atomic_store(&ctx->decode_error, dec_res);
    }
}

int ttzip_7z_decode_payload_parallel(
    const uint8_t* payload_start,
    size_t payload_len,
    uint64_t primary_method_id,
    const uint8_t* coder_props,
    size_t coder_props_len,
    const uint64_t* stream_sizes,
    size_t num_stream_sizes,
    const uint64_t* coder_unpack_sizes,
    size_t num_coder_unpack_sizes,
    uint8_t** out_unpack_buf,
    size_t* out_total_unpacked
) {
    if (!payload_start || payload_len == 0 || !out_unpack_buf || !out_total_unpacked) {
        return TTZIP_ERR_INVALID_PARAM;
    }

    *out_unpack_buf = NULL;
    *out_total_unpacked = 0;

    ttzip_7z_dec_chunk_t* blocks = (ttzip_7z_dec_chunk_t*)malloc(sizeof(ttzip_7z_dec_chunk_t) * 4096);
    if (!blocks) return TTZIP_ERR_OUT_OF_MEMORY;

    size_t block_count = 0;
    size_t pos = 0;
    size_t current_block_start = 0;
    size_t current_unpack_offset = 0;
    size_t current_block_unpack_size = 0;

    while (pos < payload_len && block_count < 4096) {
        uint8_t control = payload_start[pos];
        if (control == 0) {
            pos++;
            continue;
        }

        bool is_dict_reset = (control == 1) || (control >= 0xE0);
        if (is_dict_reset && pos > current_block_start) {
            blocks[block_count].pack_ptr = payload_start + current_block_start;
            blocks[block_count].pack_size = pos - current_block_start;
            blocks[block_count].unpack_offset = current_unpack_offset;
            blocks[block_count].unpack_size = current_block_unpack_size;
            
            current_unpack_offset += current_block_unpack_size;
            current_block_unpack_size = 0;
            current_block_start = pos;
            block_count++;
        }

        if (control == 1 || control == 2) {
            if (pos + 3 > payload_len) break;
            size_t chunk_size = (((size_t)payload_start[pos + 1] << 8) | payload_start[pos + 2]) + 1;
            pos += 3 + chunk_size;
            current_block_unpack_size += chunk_size;
        } else if (control >= 0x80) {
            size_t header_len = (control >= 0xC0) ? 6 : 5;
            if (pos + header_len > payload_len) break;
            size_t unpack_size = ((((size_t)(control & 0x1F)) << 16) | ((size_t)payload_start[pos + 1] << 8) | payload_start[pos + 2]) + 1;
            size_t pack_size = (((size_t)payload_start[pos + 3] << 8) | payload_start[pos + 4]) + 1;
            pos += header_len + pack_size;
            current_block_unpack_size += unpack_size;
        } else {
            break;
        }
    }

    if (pos > current_block_start && block_count < 4096) {
        blocks[block_count].pack_ptr = payload_start + current_block_start;
        blocks[block_count].pack_size = pos - current_block_start;
        blocks[block_count].unpack_offset = current_unpack_offset;
        blocks[block_count].unpack_size = current_block_unpack_size;
        current_unpack_offset += current_block_unpack_size;
        block_count++;
    }

    size_t total_unpack_bytes = 0;
    if (coder_unpack_sizes && num_coder_unpack_sizes > 0 && coder_unpack_sizes[0] > 0) {
        total_unpack_bytes = (size_t)coder_unpack_sizes[0];
    } else if (stream_sizes && num_stream_sizes > 0) {
        for (size_t i = 0; i < num_stream_sizes; i++) {
            total_unpack_bytes += (size_t)stream_sizes[i];
        }
    }
    if (total_unpack_bytes == 0) {
        total_unpack_bytes = current_unpack_offset;
    }
    if (total_unpack_bytes == 0) {
        total_unpack_bytes = payload_len * 4 + 1024 * 1024;
    }

    uint8_t* unpack_buf = (uint8_t*)ttzip_platform_aligned_alloc(64, total_unpack_bytes);
    if (!unpack_buf) {
        free(blocks);
        return TTZIP_ERR_OUT_OF_MEMORY;
    }

    TTZIP_SLICE_SCOPE_BEGIN("2_7zDec_ParallelLZMA2Decode");
    if (primary_method_id == 0x00 || primary_method_id == 0x06F10701 || primary_method_id == 0x6F10701) {
        // 7z Copy / Store / Raw AES direct pass-through
        size_t cpy_len = payload_len < total_unpack_bytes ? payload_len : total_unpack_bytes;
        memcpy(unpack_buf, payload_start, cpy_len);
        total_unpack_bytes = cpy_len;
    } else if (primary_method_id == 0x04F71101 || primary_method_id == 0x4F71101) {
        // 7z-Zstandard native decoding
        size_t zstd_dec = ttzip_zstd_decompress(payload_start, payload_len, unpack_buf, total_unpack_bytes);
        if (zstd_dec > 0) {
            total_unpack_bytes = zstd_dec;
        } else {
            TTZIP_SLICE_SCOPE_END("2_7zDec_ParallelLZMA2Decode");
            free(blocks);
            ttzip_platform_aligned_free(unpack_buf);
            return TTZIP_ERR_CORRUPT_HEADER;
        }
    } else if (primary_method_id == 0x040108 || primary_method_id == 0x40108) {
        // 7z-Deflate libdeflate NEON pass-through (Method ID 0x040108)
        size_t def_dec = ttzip_libdeflate_decompress(payload_start, payload_len, unpack_buf, total_unpack_bytes);
        if (def_dec > 0) {
            total_unpack_bytes = def_dec;
        } else {
            TTZIP_SLICE_SCOPE_END("2_7zDec_ParallelLZMA2Decode");
            free(blocks);
            ttzip_platform_aligned_free(unpack_buf);
            return TTZIP_ERR_CORRUPT_HEADER;
        }
    } else if (primary_method_id == 0x030101 || primary_method_id == 0x30101) {
        // 7z-LZMA1 native decoding (Method ID 0x030101)
        size_t actual_unpacked = 0;
        int dec_res = ttzip_lzma1_decode_block_native(
            payload_start,
            payload_len,
            coder_props,
            coder_props_len,
            unpack_buf,
            total_unpack_bytes,
            &actual_unpacked
        );
        if (dec_res == 0 && actual_unpacked > 0) {
            total_unpack_bytes = actual_unpacked;
        } else {
            TTZIP_SLICE_SCOPE_END("2_7zDec_ParallelLZMA2Decode");
            free(blocks);
            ttzip_platform_aligned_free(unpack_buf);
            return TTZIP_ERR_CORRUPT_HEADER;
        }
    } else if (block_count > 1) {
        lzma2_block_decode_arg_t decode_arg = {
            .blocks = blocks,
            .unpack_buf = unpack_buf,
            .total_unpack_bytes = total_unpack_bytes,
            .decode_error = 0
        };
        ttzip_parallel_for(ttzip_threadpool_shared(), block_count, lzma2_block_decode_worker, &decode_arg);
        if (atomic_load(&decode_arg.decode_error) != 0) {
            TTZIP_SLICE_SCOPE_END("2_7zDec_ParallelLZMA2Decode");
            free(blocks);
            ttzip_platform_aligned_free(unpack_buf);
            return TTZIP_ERR_CORRUPT_HEADER;
        }
    } else {
        size_t actual_unpacked = 0;
        int dec_res = ttzip_lzma2_decode_block_native(
            payload_start,
            payload_len,
            unpack_buf,
            total_unpack_bytes,
            &actual_unpacked
        );
        if (dec_res == 0 && actual_unpacked > 0) {
            total_unpack_bytes = actual_unpacked;
        }
    }
    TTZIP_SLICE_SCOPE_END("2_7zDec_ParallelLZMA2Decode");

    free(blocks);
    *out_unpack_buf = unpack_buf;
    *out_total_unpacked = total_unpack_bytes;
    return TTZIP_OK;
}

#include <lzma.h>
#include <unistd.h>

int ttzip_7z_decode_solid_entry_stream(
    const uint8_t* payload_start,
    size_t payload_len,
    uint64_t primary_method_id,
    const uint8_t* coder_props,
    size_t coder_props_len,
    uint64_t pre_entry_skip_bytes,
    uint64_t target_entry_size,
    uint8_t* out_buffer,
    int out_fd,
    uint32_t* out_crc32
) {
    if (!payload_start || payload_len == 0) return TTZIP_ERR_INVALID_PARAM;
    if (!out_buffer && out_fd < 0) return TTZIP_ERR_INVALID_PARAM;
    (void)primary_method_id;
    (void)coder_props;
    (void)coder_props_len;

    lzma_stream strm = LZMA_STREAM_INIT;
    lzma_ret ret = lzma_auto_decoder(&strm, UINT64_MAX, 0);
    if (ret != LZMA_OK) return TTZIP_ERR_CORRUPT_HEADER;

    strm.next_in = payload_start;
    strm.avail_in = payload_len;

    uint8_t discard_buf[65536];
    uint64_t discarded = 0;

    // Phase 1: Fast-forward and discard prior bytes in solid stream
    while (discarded < pre_entry_skip_bytes) {
        size_t to_discard = sizeof(discard_buf);
        if (pre_entry_skip_bytes - discarded < to_discard) {
            to_discard = (size_t)(pre_entry_skip_bytes - discarded);
        }
        strm.next_out = discard_buf;
        strm.avail_out = to_discard;

        ret = lzma_code(&strm, LZMA_RUN);
        size_t produced = to_discard - strm.avail_out;
        discarded += produced;

        if (ret == LZMA_STREAM_END) break;
        if (ret != LZMA_OK) {
            lzma_end(&strm);
            return TTZIP_ERR_CORRUPT_HEADER;
        }
    }

    // Phase 2: Direct streaming of target entry
    uint64_t extracted = 0;
    uint32_t running_crc = 0;

    while (extracted < target_entry_size) {
        size_t chunk_req = (size_t)target_entry_size - extracted;
        uint8_t* write_ptr = NULL;

        if (out_buffer) {
            write_ptr = out_buffer + extracted;
            strm.next_out = write_ptr;
            strm.avail_out = chunk_req;
        } else {
            if (chunk_req > sizeof(discard_buf)) chunk_req = sizeof(discard_buf);
            write_ptr = discard_buf;
            strm.next_out = write_ptr;
            strm.avail_out = chunk_req;
        }

        ret = lzma_code(&strm, LZMA_RUN);
        size_t produced = chunk_req - strm.avail_out;

        if (produced > 0) {
            running_crc = (uint32_t)ttzip_simd_crc32(running_crc, write_ptr, produced);
            if (out_fd >= 0) {
                ssize_t w = write(out_fd, write_ptr, produced);
                (void)w;
            }
            extracted += produced;
        }

        if (ret == LZMA_STREAM_END) break;
        if (ret != LZMA_OK) {
            lzma_end(&strm);
            return TTZIP_ERR_CORRUPT_HEADER;
        }
    }

    // Phase 3: Immediate early termination
    lzma_end(&strm);

    if (out_crc32) *out_crc32 = running_crc;
    return (extracted == target_entry_size) ? TTZIP_OK : TTZIP_ERR_CORRUPT_HEADER;
}
