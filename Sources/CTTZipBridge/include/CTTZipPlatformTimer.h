// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file CTTZipPlatformTimer.h
 * @brief High-precision nanosecond monotonic hardware timer and calibration interface.
 */

#ifndef CTTZIP_PLATFORM_TIMER_H
#define CTTZIP_PLATFORM_TIMER_H

#include "ttzip_platform.h"
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    const char* platform_os;
    const char* architecture;
    const char* timer_backend;
    uint64_t    frequency_hz;
    uint32_t    timebase_numer;
    uint32_t    timebase_denom;
    double      resolution_nanos;
    double      overhead_nanos;
} ttzip_timer_calibration_t;

TTZIP_API void ttzip_platform_timer_init(void);
TTZIP_API uint64_t ttzip_platform_monotonic_nanos(void);
TTZIP_API uint64_t ttzip_platform_raw_ticks(void);
TTZIP_API uint64_t ttzip_platform_ticks_to_nanos(uint64_t ticks);
TTZIP_API void ttzip_platform_timer_get_calibration(ttzip_timer_calibration_t* out_calib);

#ifdef __cplusplus
}
#endif

#endif /* CTTZIP_PLATFORM_TIMER_H */
