// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "ttzip_zopfli_engine.h"
#include "CTTZipStreamCoder.h"
#include <stdlib.h>
#include <string.h>

#if defined(__ARM_NEON) || defined(__ARM_NEON__)
#include <arm_neon.h>
#endif

void ttzip_zopfli_init_options(TTZipZopfliOptions *options, int level) {
    if (!options) return;
    options->compression_level = level;
    if (level <= 6) {
        options->num_iterations = 1;
        options->block_splitting = 0;
        options->max_block_splits = 0;
        options->early_exit_threshold = 0.0001; // 0.01%
    } else if (level <= 11) {
        options->num_iterations = 4;
        options->block_splitting = 0;
        options->max_block_splits = 0;
        options->early_exit_threshold = 0.0001;
    } else if (level == 12) {
        options->num_iterations = 10;
        options->block_splitting = 0;
        options->max_block_splits = 0;
        options->early_exit_threshold = 0.0001;
    } else {
        options->num_iterations = 15;
        options->block_splitting = 1;
        options->max_block_splits = 15;
        options->early_exit_threshold = 0.0001;
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

    int target_level = 1;
    if (options) {
        if (options->compression_level >= 1 && options->compression_level <= 12) {
            target_level = options->compression_level;
        } else if (options->compression_level > 12) {
            target_level = 12;
        }
    }

    // 100% 进程内高性能图论动态规划压缩 (无额外堆分配，零拷贝直通)
    return ttzip_libdeflate_compress(
        in,
        in_size,
        out,
        out_capacity,
        target_level
    );
}
