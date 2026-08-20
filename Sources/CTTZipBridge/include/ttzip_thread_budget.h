// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#ifndef TTZIP_THREAD_BUDGET_H
#define TTZIP_THREAD_BUDGET_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    uint32_t total_logical_cores;
    uint32_t p_cores;
    uint32_t e_cores;
    uint32_t default_threads;
} ttzip_cpu_topology_t;

/**
 * @brief Detects system CPU topology (logical cores, P-cores, E-cores).
 * @return ttzip_cpu_topology_t struct containing detected topology.
 */
ttzip_cpu_topology_t ttzip_cpu_topology_detect(void);

/**
 * @brief Computes optimal thread count for an operation given requested thread count.
 * @param requested_threads 0 for automatic (topology-based default), or >0 for explicit.
 * @return Clamped, safe thread count bounded by hardware and system limits.
 */
uint32_t ttzip_thread_budget_get(uint32_t requested_threads);

/**
 * @brief Overrides the global maximum thread limit (0 to reset to automatic).
 */
void ttzip_thread_budget_set_override(uint32_t max_threads);

#ifdef __cplusplus
}
#endif

#endif /* TTZIP_THREAD_BUDGET_H */
