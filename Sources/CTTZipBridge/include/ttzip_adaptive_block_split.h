// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_adaptive_block_split.h
 * @brief Adaptive 300KB/5KB Deflate Block Splitter & 3-Way Bit Cost Evaluator.
 * @details Implements 10-class aggregate observation sampling (8 literal + 2 match classes),
 *          integer cross-multiplication L1 drift testing, and Store/Static/Dynamic bit cost arbitration.
 */

#ifndef TTZIP_ADAPTIVE_BLOCK_SPLIT_H
#define TTZIP_ADAPTIVE_BLOCK_SPLIT_H

#include "ttzip_platform.h"
#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#define TTZIP_MIN_BLOCK_LENGTH               5000U
#define TTZIP_SOFT_MAX_BLOCK_LENGTH          300000U
#define TTZIP_NUM_OBSERVATIONS_PER_CHECK     512U
#define TTZIP_NUM_LITERAL_OBS_TYPES          8U
#define TTZIP_NUM_MATCH_OBS_TYPES            2U
#define TTZIP_NUM_OBSERVATION_TYPES          (TTZIP_NUM_LITERAL_OBS_TYPES + TTZIP_NUM_MATCH_OBS_TYPES)

typedef enum {
    TTZIP_BLOCK_STORED   = 0,
    TTZIP_BLOCK_STATIC   = 1,
    TTZIP_BLOCK_DYNAMIC  = 2
} ttzip_block_type_t;

typedef struct {
    uint32_t new_observations[TTZIP_NUM_OBSERVATION_TYPES];
    uint32_t observations[TTZIP_NUM_OBSERVATION_TYPES];
    uint32_t num_new_observations;
    uint32_t num_observations;
} ttzip_block_split_stats_t;

TTZIP_API void ttzip_block_split_init(ttzip_block_split_stats_t *stats);
TTZIP_API void ttzip_block_split_observe_lit(ttzip_block_split_stats_t *stats, uint8_t lit);
TTZIP_API void ttzip_block_split_observe_match(ttzip_block_split_stats_t *stats, uint32_t length);
TTZIP_API void ttzip_block_split_merge(ttzip_block_split_stats_t *stats);

TTZIP_API const uint8_t *ttzip_choose_max_block_end(
    const uint8_t *in_block_begin,
    const uint8_t *in_end,
    size_t soft_max_len
);

TTZIP_API bool ttzip_should_end_block(
    ttzip_block_split_stats_t *stats,
    const uint8_t *in_block_begin,
    const uint8_t *in_next,
    const uint8_t *in_end
);

TTZIP_API ttzip_block_type_t ttzip_eval_best_block_type(
    uint32_t dynamic_cost,
    uint32_t static_cost,
    uint32_t block_length,
    unsigned bitcount,
    uint32_t *out_best_cost
);

#ifdef __cplusplus
}
#endif

#endif /* TTZIP_ADAPTIVE_BLOCK_SPLIT_H */
