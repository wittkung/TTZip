// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file CTTZipPlatform.h
 * @brief Platform alias header forwarding to ttzip_platform.h.
 */

#ifndef CTTZIP_PLATFORM_H
#define CTTZIP_PLATFORM_H

#include "ttzip_platform.h"

#ifdef __cplusplus
extern "C" {
#endif

/* ============================================================================
 * Hardware Thermal State Accessors
 * ============================================================================ */
TTZIP_API void ttzip_bridge_set_thermal_state(int32_t state);
TTZIP_API int32_t ttzip_bridge_get_thermal_state(void);

#ifdef __cplusplus
}
#endif

#endif /* CTTZIP_PLATFORM_H */
