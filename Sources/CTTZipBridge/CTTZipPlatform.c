// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file CTTZipPlatform.c
 * @brief Platform runtime state, thermal telemetry, and lock-free status storage.
 */

#include "ttzip_platform.h"
#include <stdatomic.h>

static atomic_int g_ttzip_thermal_state = 0; // 0 = Nominal, 1 = Fair, 2 = Serious, 3 = Critical

TTZIP_API void ttzip_bridge_set_thermal_state(int32_t state) {
    atomic_store_explicit(&g_ttzip_thermal_state, (int)state, memory_order_relaxed);
}

TTZIP_API int32_t ttzip_bridge_get_thermal_state(void) {
    return (int32_t)atomic_load_explicit(&g_ttzip_thermal_state, memory_order_relaxed);
}
