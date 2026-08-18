// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#ifndef CTTZipCacheTopology_h
#define CTTZipCacheTopology_h

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Dynamic CPU Cache Topology Arbiter
 *
 * Discovers physical L1/L2 cache sizes and cacheline boundaries via
 * Darwin sysctl / POSIX sysconf, caching the results for zero-overhead hot path queries.
 */

/**
 * @brief Returns the Level 1 Data Cache size in bytes for the current CPU core.
 * Default on Apple Silicon: 131,072 (128 KB) for P-Cores, 65,536 (64 KB) for E-Cores.
 * Default on Intel x86: 32,768 (32 KB) ~ 49,152 (48 KB).
 */
size_t ttzip_cache_get_l1d_size(void);

/**
 * @brief Returns the Level 2 Cache size in bytes.
 */
size_t ttzip_cache_get_l2_size(void);

/**
 * @brief Returns the hardware cacheline size in bytes.
 * Apple Silicon: 128 bytes.
 * Intel x86_64: 64 bytes.
 */
size_t ttzip_cache_get_cacheline_size(void);

/**
 * @brief Calculates the optimal small-file batch work unit target size.
 * Aligns precisely with L1 Data Cache capacity to maintain 100% cache residency.
 */
size_t ttzip_cache_get_optimal_batch_size(void);

/**
 * @brief Returns the optimal maximum file count per batch.
 */
size_t ttzip_cache_get_optimal_max_files(void);

#ifdef __cplusplus
}
#endif

#endif // CTTZipCacheTopology_h
