// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#ifndef CTTZipBitGroom_h
#define CTTZipBitGroom_h

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Calculates the number of explicit mantissa bits to preserve for a given Number of Significant Digits (NSD).
 * @param nsd Number of decimal significant digits (1..7 for Float32, 1..15 for Float64)
 * @param is_double True for Float64, false for Float32
 * @return Number of mantissa bits kept (e.g. 11 bits for NSD 3 on Float32)
 */
uint32_t ttzip_bitgroom_calc_mantissa_bits(uint8_t nsd, bool is_double);

/**
 * @brief Applies Bit-Grooming (alternating bit-shaving and bit-setting) to Float32 array using ARM NEON.
 */
void ttzip_filter_bitgroom_float32_neon(
    const float* src,
    float* dst,
    size_t count,
    uint8_t nsd
);

/**
 * @brief Applies Bit-Grooming to Float64 array using ARM NEON.
 */
void ttzip_filter_bitgroom_float64_neon(
    const double* src,
    double* dst,
    size_t count,
    uint8_t nsd
);

/**
 * @brief Applies BitRound (nearest-even arithmetic rounding) to Float32 array using ARM NEON.
 */
void ttzip_filter_bitround_float32_neon(
    const float* src,
    float* dst,
    size_t count,
    uint8_t nsd
);

#ifdef __cplusplus
}
#endif

#endif /* CTTZipBitGroom_h */
