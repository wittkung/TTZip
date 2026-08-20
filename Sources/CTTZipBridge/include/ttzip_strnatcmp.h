// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine.

/**
 * @file ttzip_strnatcmp.h
 * @brief High-speed C11 natural numeric string comparison algorithm.
 */

#ifndef TTZIP_STRNATCMP_H
#define TTZIP_STRNATCMP_H

#include "ttzip_platform.h"
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Compares two strings using natural order (case-sensitive).
 * @return <0 if a < b, 0 if a == b, >0 if a > b.
 */
TTZIP_API int ttzip_strnatcmp(const char *a, const char *b);

/**
 * @brief Compares two strings using natural order (case-insensitive).
 * @return <0 if a < b, 0 if a == b, >0 if a > b.
 */
TTZIP_API int ttzip_strnatcasecmp(const char *a, const char *b);

#ifdef __cplusplus
}
#endif

#endif /* TTZIP_STRNATCMP_H */
