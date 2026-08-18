// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/ttzip_adaptive_block_split.h"
#include <string.h>

void ttzip_block_split_init(ttzip_block_split_stats_t *stats) {
    if (stats) {
        memset(stats, 0, sizeof(*stats));
    }
}

void ttzip_block_split_observe_lit(ttzip_block_split_stats_t *stats, uint8_t lit) {
    if (!stats) return;
    uint32_t type = ((lit >> 5) & 0x6) | (lit & 1);
    stats->new_observations[type]++;
    stats->num_new_observations++;
}

void ttzip_block_split_observe_match(ttzip_block_split_stats_t *stats, uint32_t length) {
    if (!stats) return;
    uint32_t type = TTZIP_NUM_LITERAL_OBS_TYPES + (length >= 9 ? 1 : 0);
    stats->new_observations[type]++;
    stats->num_new_observations++;
}

void ttzip_block_split_merge(ttzip_block_split_stats_t *stats) {
    if (!stats) return;
    for (size_t i = 0; i < TTZIP_NUM_OBSERVATION_TYPES; i++) {
        stats->observations[i] += stats->new_observations[i];
        stats->new_observations[i] = 0;
    }
    stats->num_observations += stats->num_new_observations;
    stats->num_new_observations = 0;
}

const uint8_t *ttzip_choose_max_block_end(
    const uint8_t *in_block_begin,
    const uint8_t *in_end,
    size_t soft_max_len
) {
    if (!in_block_begin || !in_end) return in_end;
    if ((size_t)(in_end - in_block_begin) < soft_max_len + TTZIP_MIN_BLOCK_LENGTH) {
        return in_end;
    }
    return in_block_begin + soft_max_len;
}

bool ttzip_should_end_block(
    ttzip_block_split_stats_t *stats,
    const uint8_t *in_block_begin,
    const uint8_t *in_next,
    const uint8_t *in_end
) {
    if (!stats || !in_block_begin || !in_next || !in_end) return false;

    size_t cur_len = (size_t)(in_next - in_block_begin);
    size_t rem_len = (size_t)(in_end - in_next);

    if (stats->num_new_observations < TTZIP_NUM_OBSERVATIONS_PER_CHECK ||
        cur_len < TTZIP_MIN_BLOCK_LENGTH ||
        rem_len < TTZIP_MIN_BLOCK_LENGTH) {
        return false;
    }

    if (stats->num_observations > 0) {
        uint32_t total_delta = 0;
        for (size_t i = 0; i < TTZIP_NUM_OBSERVATION_TYPES; i++) {
            uint32_t expected = stats->observations[i] * stats->num_new_observations;
            uint32_t actual = stats->new_observations[i] * stats->num_observations;
            total_delta += (actual > expected) ? (actual - expected) : (expected - actual);
        }

        uint32_t num_items = stats->num_observations + stats->num_new_observations;
        uint64_t cutoff = (uint64_t)stats->num_new_observations * 200U / 512U * stats->num_observations;

        if (cur_len < 10000U && num_items < 8192U) {
            cutoff += cutoff * (8192U - num_items) / 8192U;
        }

        uint64_t metric = (uint64_t)total_delta + ((uint64_t)(cur_len / 4096U) * stats->num_observations);
        if (metric >= cutoff) {
            return true;
        }
    }

    ttzip_block_split_merge(stats);
    return false;
}

ttzip_block_type_t ttzip_eval_best_block_type(
    uint32_t dynamic_cost,
    uint32_t static_cost,
    uint32_t block_length,
    unsigned bitcount,
    uint32_t *out_best_cost
) {
    uint32_t pad_bits = (-(bitcount + 3)) & 7;
    uint32_t num_subblocks = (block_length + 65534U) / 65535U;
    uint32_t uncompressed_cost = 3 + pad_bits + 32 + (40 * (num_subblocks > 0 ? num_subblocks - 1 : 0)) + (8 * block_length);

    uint32_t best_cost = dynamic_cost;
    ttzip_block_type_t best_type = TTZIP_BLOCK_DYNAMIC;

    if (static_cost <= best_cost) {
        best_cost = static_cost;
        best_type = TTZIP_BLOCK_STATIC;
    }
    if (uncompressed_cost <= best_cost) {
        best_cost = uncompressed_cost;
        best_type = TTZIP_BLOCK_STORED;
    }

    if (out_best_cost) {
        *out_best_cost = best_cost;
    }
    return best_type;
}
