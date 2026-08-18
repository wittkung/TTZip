// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/ttzip_zopfli_engine.h"
#include "include/CTTZipStreamCoder.h"
#include <stdlib.h>
#include <string.h>
#include <math.h>

#if defined(__ARM_NEON) || defined(__ARM_NEON__)
#include <arm_neon.h>
#endif

// Q8.8 定点数 (256 units = 1 bit)
#define TTZIP_FIXED_SCALE 256
#define TTZIP_WINDOW_SIZE 32768
#define TTZIP_WINDOW_MASK 32767
#define TTZIP_HASH_SHIFT 5
#define TTZIP_HASH_MASK 32767

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

__attribute__((unused)) static inline uint32_t ttzip_fast_log2_fixed(uint32_t x) {
    if (x <= 1) return 0;
    int lz = __builtin_clz(x);
    int exp = 31 - lz;
    uint32_t frac = (x << (lz + 1)) >> 24;
    return (uint32_t)((exp << 8) + s_log2_mantissa_lut[frac & 0xFF]);
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

size_t ttzip_zopfli_compress_block_with_history(
    const uint8_t *in,
    size_t in_size,
    const uint8_t *history,
    size_t history_size,
    uint8_t *out,
    size_t out_capacity,
    const TTZipZopfliOptions *options
) {
    (void)history;
    (void)history_size;
    if (!in || in_size == 0 || !out || out_capacity == 0) {
        return 0;
    }

    int target_level = 12;
    if (options && options->compression_level >= 1 && options->compression_level <= 12) {
        target_level = options->compression_level;
    }

    // 针对高速档位 (Level 1..10) 直接直通 libdeflate
    if (!options || options->num_iterations <= 1 || target_level <= 10) {
        return ttzip_libdeflate_compress(in, in_size, out, out_capacity, target_level);
    }

    // 针对 Level 12 极限重压：调用 libdeflate Level 12 极速近最优图论基准
    return ttzip_libdeflate_compress(in, in_size, out, out_capacity, 12);
}

