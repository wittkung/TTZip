/**
 * @file ttzip_benchmark_harness.h
 * @brief Zero-overhead ANSI C11 benchmark and performance evaluation harness for TTZip.
 * 
 * SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
 * Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>. All rights reserved.
 */

#ifndef TTZIP_BENCHMARK_HARNESS_H
#define TTZIP_BENCHMARK_HARNESS_H

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <string.h>
#include <time.h>
#include <math.h>

#include "CTTZipCorpusGen.h"

#if defined(__APPLE__)
#include <mach/mach_time.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

// ==============================================================================
// 1. High-Resolution Monotonic Clock (< 1ns precision)
// ==============================================================================
static inline uint64_t ttzip_bench_nanos(void) {
#if defined(__APPLE__)
    static mach_timebase_info_data_t timebase;
    if (timebase.denom == 0) {
        mach_timebase_info(&timebase);
    }
    uint64_t mach_time = mach_absolute_time();
    return (mach_time * timebase.numer) / timebase.denom;
#elif defined(CLOCK_MONOTONIC_RAW)
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC_RAW, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ULL + (uint64_t)ts.tv_nsec;
#else
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ULL + (uint64_t)ts.tv_nsec;
#endif
}

// ==============================================================================
// 2. Metrics & Math Calculations
// ==============================================================================
static inline double ttzip_calc_throughput_mbs(size_t bytes, uint64_t elapsed_nanos) {
    if (elapsed_nanos == 0) return 0.0;
    return ((double)bytes * 1000000000.0) / ((double)elapsed_nanos * 1048576.0);
}

static inline double ttzip_calc_ratio_pct(size_t compressed_bytes, size_t original_bytes) {
    if (original_bytes == 0) return 0.0;
    return ((double)compressed_bytes * 100.0) / (double)original_bytes;
}

static inline double ttzip_calc_mips_score(double throughput_mbs, double ratio_pct) {
    double ratio_multiplier = 1.0 + ((100.0 - ratio_pct) / 50.0);
    if (ratio_multiplier < 0.2) ratio_multiplier = 0.2;
    return throughput_mbs * ratio_multiplier;
}

// ==============================================================================
// 3. Pareto Frontier Point Model
// ==============================================================================
typedef struct {
    char   name[32];
    double ratio_pct;     // Lower is better
    double speed_mbs;     // Higher is better
    bool   is_optimal;
} ttzip_bench_point_t;

static inline void ttzip_compute_pareto_frontier(ttzip_bench_point_t* points, size_t count) {
    if (!points || count == 0) return;

    for (size_t i = 0; i < count; ++i) {
        points[i].is_optimal = true;
        for (size_t j = 0; j < count; ++j) {
            if (i == j) continue;
            // Point j dominates point i if j has lower or equal ratio AND higher or equal speed
            if (points[j].ratio_pct <= points[i].ratio_pct && points[j].speed_mbs >= points[i].speed_mbs) {
                if (points[j].ratio_pct < points[i].ratio_pct || points[j].speed_mbs > points[i].speed_mbs) {
                    points[i].is_optimal = false;
                    break;
                }
            }
        }
    }
}

#ifdef __cplusplus
}
#endif

#endif // TTZIP_BENCHMARK_HARNESS_H
