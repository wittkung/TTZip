// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/CTTZipHeuristicTuner.h"
#include "include/CTTZipQuantumPipeline.h"
#include "include/CTTZipFilterPipeline.h"
#include "include/CTTZipSIMD.h"
#include "include/lz4.h"
#include <zstd.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

double ttzip_calc_autocorrelation_stride(const void* src, size_t len, size_t stride) {
    if (!src || len <= stride || stride == 0) return 0.0;
    const uint8_t* u8 = (const uint8_t*)src;
    size_t count = len - stride;
    
    uint64_t diff_sum = 0;
    for (size_t i = 0; i < count; i++) {
        int diff = (int)u8[i + stride] - (int)u8[i];
        diff_sum += (uint64_t)(diff * diff);
    }
    
    double variance_proxy = (double)diff_sum / (double)count;
    // Lower variance across stride indicates higher periodic autocorrelation
    double norm_score = 1.0 / (1.0 + variance_proxy * 0.001);
    return norm_score;
}

ttzip_tuning_recommendation_t ttzip_heuristic_eval_cascade(
    const void* src,
    size_t len,
    uint8_t typesize,
    const ttzip_tuning_params_t* params
) {
    ttzip_tuning_recommendation_t rec;
    rec.filter_type = TTZIP_FILTER_NONE;
    rec.type_size = typesize > 0 ? typesize : 4;
    rec.codec = TTZIP_TUNER_CODEC_LZ4;
    rec.clevel = 1;
    rec.predicted_ratio = 1.0;
    rec.score = 1.0;

    if (!src || len == 0) return rec;

    double alpha = params ? params->alpha : 0.5;
    double beta = params ? params->beta : 0.5;
    double entropy_cutoff = params ? (params->entropy_cutoff > 0 ? params->entropy_cutoff : 7.65) : 7.65;
    size_t sample_cap = params ? (params->sample_size > 0 ? params->sample_size : 16384) : 16384;
    size_t sample_len = len > sample_cap ? sample_cap : len;

    // Tier 1: Rapid Shannon Entropy Rejection
    double entropy = ttzip_quantum_calc_entropy_neon(src, sample_len);
    if (entropy > entropy_cutoff) {
        // High entropy media -> pass-through direct store
        rec.filter_type = TTZIP_FILTER_NONE;
        rec.codec = TTZIP_TUNER_CODEC_DIRECT;
        rec.clevel = 0;
        rec.predicted_ratio = 1.0;
        rec.score = 1.0;
        return rec;
    }

    // Tier 2: Check uniform special-value fast bypass
    ttzip_special_desc_t special = ttzip_detect_uniform_block(src, sample_len, rec.type_size);
    if (special.is_uniform) {
        rec.filter_type = TTZIP_FILTER_NONE;
        rec.codec = TTZIP_TUNER_CODEC_DIRECT;
        rec.clevel = 0;
        rec.predicted_ratio = 999.0;
        rec.score = 100.0;
        return rec;
    }

    // Tier 3: Micro-Sampling & Pareto Objective Scoring
    uint8_t sample_buf[16384];
    uint8_t filter_buf[16384];
    uint8_t comp_buf[32768];

    memcpy(sample_buf, src, sample_len);

    struct {
        ttzip_filter_type_t filter;
        ttzip_tuner_codec_t codec;
        int clevel;
        double speed_weight;
    } candidates[4] = {
        { TTZIP_FILTER_NONE, TTZIP_TUNER_CODEC_LZ4, 1, 1.0 },
        { TTZIP_FILTER_SHUFFLE, TTZIP_TUNER_CODEC_LZ4, 1, 0.85 },
        { TTZIP_FILTER_BITSHUFFLE, TTZIP_TUNER_CODEC_LZ4, 1, 0.75 },
        { TTZIP_FILTER_DELTA, TTZIP_TUNER_CODEC_ZSTD, 1, 0.60 }
    };

    double best_score = -1.0;

    for (int i = 0; i < 4; i++) {
        const uint8_t* to_compress = sample_buf;
        size_t to_compress_len = sample_len;

        if (candidates[i].filter == TTZIP_FILTER_SHUFFLE) {
            ttzip_filter_shuffle_forward(sample_buf, filter_buf, sample_len, rec.type_size);
            to_compress = filter_buf;
        } else if (candidates[i].filter == TTZIP_FILTER_BITSHUFFLE) {
            ttzip_filter_bitshuffle_forward_neon(sample_buf, filter_buf, sample_len, rec.type_size);
            to_compress = filter_buf;
        } else if (candidates[i].filter == TTZIP_FILTER_DELTA) {
            ttzip_filter_bytedelta_forward_neon(sample_buf, filter_buf, sample_len, rec.type_size);
            to_compress = filter_buf;
        }

        size_t c_size = 0;
        if (candidates[i].codec == TTZIP_TUNER_CODEC_LZ4) {
            c_size = (size_t)LZ4_compress_fast((const char*)to_compress, (char*)comp_buf, (int)to_compress_len, (int)sizeof(comp_buf), 1);
        } else if (candidates[i].codec == TTZIP_TUNER_CODEC_ZSTD) {
            c_size = ZSTD_compress(comp_buf, sizeof(comp_buf), to_compress, to_compress_len, 1);
        }

        if (c_size == 0 || ZSTD_isError(c_size)) continue;

        double ratio = (double)sample_len / (double)c_size;
        double pareto_score = alpha * ratio + beta * (candidates[i].speed_weight * 2.0);

        if (pareto_score > best_score) {
            best_score = pareto_score;
            rec.filter_type = candidates[i].filter;
            rec.codec = candidates[i].codec;
            rec.clevel = candidates[i].clevel;
            rec.predicted_ratio = ratio;
            rec.score = pareto_score;
        }
    }

    return rec;
}
