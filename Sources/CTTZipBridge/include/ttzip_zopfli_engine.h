// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#ifndef TTZIP_ZOPFLI_ENGINE_H
#define TTZIP_ZOPFLI_ENGINE_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/// 进程内多轮迭代图论最优 Deflate 块压缩器配置
typedef struct {
    int compression_level;        ///< 请求的压缩级别 (1..15)
    int num_iterations;           ///< 迭代轮次 (Level 6: 5 轮, Level 7: 15 轮)
    int block_splitting;          ///< 是否启用局部熵变动态最优块切分 (1=开启, 0=单块)
    int max_block_splits;         ///< 最大切分块数 (默认 15)
    double early_exit_threshold;  ///< 自适应早退收敛阈值 (默认 0.0001 即 0.01%)
} TTZipZopfliOptions;

/// 默认选项初始化
void ttzip_zopfli_init_options(TTZipZopfliOptions *options, int level);

/// 进程内无锁分块最优 Deflate 压缩 (带跨块 32KB 历史字典预热)
///
/// @param in 待压缩数据块
/// @param in_size 待压缩数据字节数
/// @param history 前一个块末尾的历史数据 (用于 32KB 字典预热，可为 NULL)
/// @param history_size 历史数据字节数 (最大 32768)
/// @param out 压缩输出缓冲区
/// @param out_capacity 输出缓冲区容量
/// @param options 压缩选项
/// @return 实际压缩后的字节数；若无法压缩或空间不足返回 0
size_t ttzip_zopfli_compress_block_with_history(
    const uint8_t *in,
    size_t in_size,
    const uint8_t *history,
    size_t history_size,
    uint8_t *out,
    size_t out_capacity,
    const TTZipZopfliOptions *options
);

#ifdef __cplusplus
}
#endif

#endif /* TTZIP_ZOPFLI_ENGINE_H */
