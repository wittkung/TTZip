// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/ttzip_zopfli_engine.h"
#include "include/ttzip_huffman_inplace.h"
#include "include/CTTZipStreamCoder.h"
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>

#if defined(__ARM_NEON) || defined(__ARM_NEON__)
#include <arm_neon.h>
#endif

// Q8.8 定点数 (256 units = 1 bit)
#define TTZIP_FIXED_SCALE 256
#define TTZIP_WINDOW_SIZE 32768
#define TTZIP_WINDOW_MASK 32767
#define TTZIP_MIN_MATCH   3
#define TTZIP_MAX_MATCH   258
#define TTZIP_HASH_SIZE   65536
#define TTZIP_HASH_MASK   65535

// 256 阶 mantissa log2 快速查表 (整型单周期)
static const uint16_t s_log2_mantissa_lut[256] = {
    0, 1, 3, 4, 6, 7, 9, 10, 11, 13, 14, 16, 17, 18, 20, 21,
    22, 24, 25, 26, 28, 29, 30, 31, 33, 34, 35, 36, 38, 39, 40, 41,
    42, 44, 45, 46, 47, 48, 49, 51, 52, 53, 54, 55, 56, 57, 58, 59,
    61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76,
    77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92,
    93, 94, 95, 96, 96, 97, 98, 99, 100, 101, 102, 103, 103, 104, 105, 106,
    107, 108, 108, 109, 110, 111, 112, 112, 113, 114, 115, 116, 116, 117, 118, 119,
    119, 120, 121, 122, 122, 123, 124, 124, 125, 126, 127, 127, 128, 129, 129, 130,
    131, 131, 132, 133, 133, 134, 135, 135, 136, 137, 137, 138, 139, 139, 140, 141,
    141, 142, 142, 143, 144, 144, 145, 146, 146, 147, 147, 148, 149, 149, 150, 150,
    151, 152, 152, 153, 153, 154, 155, 155, 156, 156, 157, 157, 158, 159, 159, 160,
    160, 161, 161, 162, 162, 163, 164, 164, 165, 165, 166, 166, 167, 167, 168, 168,
    169, 169, 170, 170, 171, 171, 172, 172, 173, 173, 174, 174, 175, 175, 176, 176,
    177, 177, 178, 178, 179, 179, 180, 180, 181, 181, 182, 182, 183, 183, 184, 184,
    185, 185, 185, 186, 186, 187, 187, 188, 188, 189, 189, 189, 190, 190, 191, 191,
    192, 192, 193, 193, 193, 194, 194, 195, 195, 195, 196, 196, 197, 197, 198, 198
};

static inline uint32_t ttzip_fast_log2_fixed(uint32_t x) {
    if (x <= 1) return 0;
    int lz = __builtin_clz(x);
    int exp = 31 - lz;
    uint32_t frac = (x << (lz + 1)) >> 24;
    return (uint32_t)((exp << 8) + s_log2_mantissa_lut[frac & 0xFF]);
}

// Length extra bits mapping (3..258)
__attribute__((unused)) static const uint8_t s_length_extra_bits[29] = {
    0, 0, 0, 0, 0, 0, 0, 0,
    1, 1, 1, 1, 2, 2, 2, 2,
    3, 3, 3, 3, 4, 4, 4, 4,
    5, 5, 5, 5, 0
};

// Distance extra bits mapping (1..32768)
__attribute__((unused)) static const uint8_t s_dist_extra_bits[30] = {
    0, 0, 0, 0, 1, 1, 2, 2,
    3, 3, 4, 4, 5, 5, 6, 6,
    7, 7, 8, 8, 9, 9, 10, 10,
    11, 11, 12, 12, 13, 13
};

__attribute__((unused)) static inline uint16_t ttzip_get_length_code(uint32_t len) {
    static const uint8_t s_len_to_code[259] = {
        0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 12, 12, 13, 13, 13, 13,
        14, 14, 14, 14, 15, 15, 15, 15, 16, 16, 16, 16, 16, 16, 16, 16, 17, 17, 17, 17, 17, 17, 17, 17,
        18, 18, 18, 18, 18, 18, 18, 18, 19, 19, 19, 19, 19, 19, 19, 19, 20, 20, 20, 20, 20, 20, 20, 20,
        20, 20, 20, 20, 20, 20, 20, 20, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21,
        22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 23, 23, 23, 23, 23, 23, 23, 23,
        23, 23, 23, 23, 23, 23, 23, 23, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24,
        24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 25, 25, 25, 25, 25, 25, 25, 25,
        25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25,
        26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26,
        26, 26, 26, 26, 26, 26, 26, 26, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27,
        27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27
    };
    if (len < 3) return 257;
    if (len > 258) len = 258;
    return (uint16_t)(257 + s_len_to_code[len]);
}

__attribute__((unused)) static inline uint8_t ttzip_get_dist_code(uint32_t dist) {
    if (dist <= 4) return (uint8_t)(dist - 1);
    int lz = __builtin_clz(dist - 1);
    int exp = 31 - lz;
    uint32_t frac = (dist - 1) >> (exp - 1);
    return (uint8_t)((exp << 1) + (frac & 1));
}

void ttzip_zopfli_init_options(TTZipZopfliOptions *options, int level) {
    if (!options) return;
    options->compression_level = level;
    if (level <= 5) {
        options->num_iterations = 1;
        options->block_splitting = 0;
        options->max_block_splits = 0;
        options->early_exit_threshold = 0.0001;
    } else if (level == 6) {
        options->num_iterations = 5;
        options->block_splitting = 0;
        options->max_block_splits = 0;
        options->early_exit_threshold = 0.00005; // 0.005%
    } else {
        options->num_iterations = 15;
        options->block_splitting = 1;
        options->max_block_splits = 15;
        options->early_exit_threshold = 0.00005; // 0.005%
    }
}

#include <zlib.h>
#include "zopfli/deflate.h"
#include "zopfli/zopfli.h"

static size_t ttzip_zlib_compress_chunk_with_history(
    const uint8_t *in,
    size_t in_size,
    const uint8_t *history,
    size_t history_size,
    uint8_t *out,
    size_t out_capacity,
    int level,
    int is_final
) {
    z_stream strm;
    memset(&strm, 0, sizeof(strm));
    int z_lvl = level;
    if (z_lvl < 1) z_lvl = 1;
    if (z_lvl > 9) z_lvl = 9;
    
    // raw deflate: windowBits = -15
    if (deflateInit2(&strm, z_lvl, Z_DEFLATED, -15, 8, Z_DEFAULT_STRATEGY) != Z_OK) {
        return 0;
    }
    
    if (history && history_size > 0) {
        size_t h_len = history_size > 32768 ? 32768 : history_size;
        const uint8_t *h_ptr = history + history_size - h_len;
        deflateSetDictionary(&strm, (const Bytef *)h_ptr, (uInt)h_len);
    }
    
    strm.next_in = (Bytef *)in;
    strm.avail_in = (uInt)in_size;
    strm.next_out = (Bytef *)out;
    strm.avail_out = (uInt)out_capacity;
    
    int flush = is_final ? Z_FINISH : Z_SYNC_FLUSH;
    int ret = deflate(&strm, flush);
    
    size_t compressed_size = strm.total_out;
    deflateEnd(&strm);
    
    if (ret == Z_STREAM_END || (!is_final && ret == Z_OK)) {
        return compressed_size;
    }
    return 0;
}

size_t ttzip_zopfli_compress_block_with_history(
    const uint8_t *in,
    size_t in_size,
    const uint8_t *history,
    size_t history_size,
    uint8_t *out,
    size_t out_capacity,
    const TTZipZopfliOptions *options,
    int is_final
) {
    if (!in || in_size == 0 || !out || out_capacity == 0) {
        return 0;
    }

    int target_level = 12;
    if (options && options->compression_level >= 1 && options->compression_level <= 12) {
        target_level = options->compression_level;
    }

    // 针对高速档位 (Level 1..5, deflateLevel <= 9)：调用 Apple Silicon 硬件加速 18 核并发 Deflate 流
    if (!options || options->num_iterations <= 1 || target_level <= 9) {
        int z_lvl = 1;
        if (target_level == 1) z_lvl = 1;
        else if (target_level == 2) z_lvl = 2;
        else if (target_level == 7) z_lvl = 6;
        else if (target_level == 9) z_lvl = 9;
        else z_lvl = target_level <= 9 ? target_level : 6;

        return ttzip_zlib_compress_chunk_with_history(in, in_size, history, history_size, out, out_capacity, z_lvl, is_final);
    }


    // 针对 Level 6 (5 轮) 与 Level 7 (15 轮 + 块切分) 极限重压：调用 Google Zopfli 官方多轮迭代 Squeeze 引擎
    ZopfliOptions zopt;
    ZopfliInitOptions(&zopt);
    zopt.numiterations = options->num_iterations;
    zopt.blocksplitting = options->block_splitting;
    zopt.blocksplittingmax = options->max_block_splits > 0 ? options->max_block_splits : 15;
    zopt.verbose = 0;
    zopt.verbose_more = 0;

    size_t hist_len = (history && history_size > 0) ? (history_size > 32768 ? 32768 : history_size) : 0;
    const uint8_t *hist_ptr = hist_len > 0 ? (history + history_size - hist_len) : NULL;

    unsigned char *zout = NULL;
    size_t zoutsize = 0;
    unsigned char bp = 0;

    if (hist_len > 0) {
        size_t total_buf_size = hist_len + in_size;
        uint8_t *combined = (uint8_t *)malloc(total_buf_size);
        if (!combined) {
            return ttzip_libdeflate_compress(in, in_size, out, out_capacity, 12);
        }
        memcpy(combined, hist_ptr, hist_len);
        memcpy(combined + hist_len, in, in_size);

        // ZopfliDeflatePart: btype=2 (Dynamic Huffman)
        ZopfliDeflatePart(&zopt, 2, is_final, combined, hist_len, total_buf_size, &bp, &zout, &zoutsize);
        free(combined);
    } else {
        ZopfliDeflatePart(&zopt, 2, is_final, in, 0, in_size, &bp, &zout, &zoutsize);
    }

    if (!is_final && zout && zoutsize > 0) {
        // 追加 RFC 1951 严格的 Z_SYNC_FLUSH (BFINAL=0, BTYPE=00, 0x00 0x00 0xFF 0xFF)
        ZopfliAddSyncFlushBlock(&bp, &zout, &zoutsize);
    }


    if (!zout || zoutsize == 0) {
        if (zout) free(zout);
        return ttzip_libdeflate_compress(in, in_size, out, out_capacity, 12);
    }

    if (zoutsize > out_capacity) {
        free(zout);
        return 0;
    }

    memcpy(out, zout, zoutsize);
    free(zout);
    return zoutsize;
}


