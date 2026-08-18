// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#ifndef CTTZipHeuristicTuner_h
#define CTTZipHeuristicTuner_h

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>
#include "CTTZipFilterPipeline.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    TTZIP_TUNER_CODEC_DIRECT = 0,
    TTZIP_TUNER_CODEC_LZ4 = 1,
    TTZIP_TUNER_CODEC_ZSTD = 2,
    TTZIP_TUNER_CODEC_DEFLATE = 3,
    TTZIP_TUNER_CODEC_SNAPPY = 4
} ttzip_tuner_codec_t;

typedef struct {
    ttzip_filter_type_t filter_type;
    uint8_t type_size;
    ttzip_tuner_codec_t codec;
    int clevel;
    double predicted_ratio;
    double score;
} ttzip_tuning_recommendation_t;

typedef struct {
    double alpha; // Weight for compression ratio (0.0 to 1.0)
    double beta;  // Weight for compression speed (0.0 to 1.0)
    double entropy_cutoff; // Default: 7.65 (incompressible limit)
    size_t sample_size;    // Default: 16384 (16KB)
} ttzip_tuning_params_t;

/**
 * @brief Evaluates input buffer using 3-tier cascade and Pareto scoring to select optimal filter/codec.
 * @param[in] src Input buffer pointer
 * @param[in] len Length of input buffer
 * @param[in] typesize Detected or suggested data type size (e.g. 4 for float32/int32)
 * @param[in] params Tuning parameters (pass NULL for defaults)
 * @return Tuned recommendation struct with selected filter and codec
 */
ttzip_tuning_recommendation_t ttzip_heuristic_eval_cascade(
    const void* src,
    size_t len,
    uint8_t typesize,
    const ttzip_tuning_params_t* params
);

/**
 * @brief Computes multi-stride autocorrelation to detect periodic structures in binary data.
 * @param[in] src Input buffer pointer
 * @param[in] len Length of sample
 * @param[in] stride Stride to test (e.g., 2, 4, 8)
 * @return Correlation coefficient between 0.0 and 1.0
 */
double ttzip_calc_autocorrelation_stride(const void* src, size_t len, size_t stride);

typedef struct {
    bool is_scientific_float;
    uint8_t type_size;       // 4 for Float32, 8 for Float64
    double stride_score;     // Autocorrelation score
    double exponent_std_dev; // Exponent cluster standard deviation
    double normalized_ratio; // Percentage in normalized float domain (0.0 .. 1.0)
} ttzip_float_detect_result_t;

/**
 * @brief Automatically detects scientific floating-point data arrays via NEON stride & exponent clustering.
 * @param[in] src Sample buffer pointer
 * @param[in] len Length of sample (e.g., 16KB)
 * @return Detection result struct
 */
ttzip_float_detect_result_t ttzip_detect_scientific_float_neon(const void* src, size_t len);

#ifdef __cplusplus
}
#endif

#endif /* CTTZipHeuristicTuner_h */
