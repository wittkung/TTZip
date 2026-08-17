// ttzip_7z_block_decoder.c
// TTZip 原生 7Z 载荷多块并发解码器 (支持 LZMA2, Zstd, Direct Store)

#include "include/ttzip_7z_block_decoder.h"
#include "include/CTTZipCommon.h"
#include "include/CTTZipDiagnostics.h"
#include "include/CTTZipSliceProfiler.h"
#include "include/ttzip_lzma2_dec_native.h"
#include "include/CTTZipBridge_Zstd.h"
#include "include/CTTZipStreamCoder.h"
#include "include/ttzip_platform.h"
#include <stdlib.h>
#include <string.h>
#include <stdatomic.h>
#include <dispatch/dispatch.h>

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
        // 7z Copy / Store / Raw AES 解密后原生直通
        size_t cpy_len = payload_len < total_unpack_bytes ? payload_len : total_unpack_bytes;
        memcpy(unpack_buf, payload_start, cpy_len);
        total_unpack_bytes = cpy_len;
    } else if (primary_method_id == 0x04F71101 || primary_method_id == 0x4F71101) {
        // 7z-Zstandard 原生极速解码
        size_t zstd_dec = ttzip_zstd_decompress(payload_start, payload_len, unpack_buf, total_unpack_bytes);
        if (zstd_dec > 0) {
            total_unpack_bytes = zstd_dec;
        }
    } else if (primary_method_id == 0x040108 || primary_method_id == 0x40108) {
        // 7z-Deflate 原生 libdeflate NEON 直通解码 (Method ID 0x040108)
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
        // 7z-LZMA1 原生解码 (Method ID 0x030101，支持 5 字节字典/上下文参数属性)
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
        __block _Atomic int decode_error = 0;
        dispatch_apply(block_count, dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^(size_t b) {
            size_t actual_block_unpacked = 0;
            size_t cap = blocks[b].unpack_size > 0 ? blocks[b].unpack_size : (total_unpack_bytes - blocks[b].unpack_offset);
            int dec_res = ttzip_lzma2_decode_block_native(
                blocks[b].pack_ptr,
                blocks[b].pack_size,
                unpack_buf + blocks[b].unpack_offset,
                cap,
                &actual_block_unpacked
            );
            if (dec_res != 0) {
                atomic_store(&decode_error, dec_res);
            }
        });
        if (atomic_load(&decode_error) != 0) {
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
