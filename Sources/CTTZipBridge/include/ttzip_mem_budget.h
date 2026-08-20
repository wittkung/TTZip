// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#ifndef TTZIP_MEM_BUDGET_H
#define TTZIP_MEM_BUDGET_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    uint64_t total_physical_ram;
    uint64_t available_physical_ram;
    uint64_t safe_budget_bytes;
} ttzip_mem_budget_t;

/**
 * @brief Queries current system memory state and computes a safe dynamic allocation budget.
 * @return ttzip_mem_budget_t containing physical RAM statistics.
 */
ttzip_mem_budget_t ttzip_mem_budget_query(void);

/**
 * @brief Clamps a desired memory allocation against system budget limits.
 * @param desired_bytes Requested buffer or arena size in bytes.
 * @param min_bytes Floor boundary for the operation.
 * @param max_bytes Ceiling boundary for the operation.
 * @return Safe byte allocation size.
 */
uint64_t ttzip_mem_budget_clamp(uint64_t desired_bytes, uint64_t min_bytes, uint64_t max_bytes);

/**
 * @brief Overrides the global memory budget limit in bytes (0 to reset to automatic).
 */
void ttzip_mem_budget_set_override(uint64_t max_budget_bytes);

#ifdef __cplusplus
}
#endif

#endif /* TTZIP_MEM_BUDGET_H */
