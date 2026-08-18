// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file CTTZipSliceProfiler.h
 * @brief High-precision nanosecond stage profiler and telemetry tracer.
 */

#ifndef CTTZIP_SLICE_PROFILER_H
#define CTTZIP_SLICE_PROFILER_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

void ttzip_slice_enable(bool enable);
bool ttzip_slice_is_enabled(void);
void ttzip_slice_reset(void);

void ttzip_slice_start(const char* slice_name);
void ttzip_slice_end(const char* slice_name);

void ttzip_slice_print_report(const char* pipeline_name);

uint64_t ttzip_slice_now_ns(void);

const char* ttzip_slice_get_top_stage_name(void);
double ttzip_slice_get_top_stage_ratio(void);
double ttzip_slice_get_stage_ms(const char* name);

#define TTZIP_SLICE_SCOPE_BEGIN(name) ttzip_slice_start(name);
#define TTZIP_SLICE_SCOPE_END(name)   ttzip_slice_end(name);

#ifdef __cplusplus
}
#endif

#endif // CTTZIP_SLICE_PROFILER_H
