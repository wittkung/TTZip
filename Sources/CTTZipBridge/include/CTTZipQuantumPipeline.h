// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file CTTZipQuantumPipeline.h
 * @brief Quantum 128KB block hardware slicing, Shannon entropy, and branchless NEON routines.
 */

#ifndef CTTZipQuantumPipeline_h
#define CTTZipQuantumPipeline_h

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    TTZIP_SPECIAL_STANDARD = 0,
    TTZIP_SPECIAL_ZERO     = 1,
    TTZIP_SPECIAL_NAN      = 2,
    TTZIP_SPECIAL_VALUE    = 3,
    TTZIP_SPECIAL_UNINIT   = 4
} ttzip_special_value_t;

typedef struct {
    bool is_uniform;
    ttzip_special_value_t special_code;
    uint64_t repeat_pattern;
    size_t uncompressed_size;
} ttzip_special_desc_t;

ttzip_special_desc_t ttzip_detect_uniform_block(const void* buf, size_t len, uint8_t typesize);
size_t ttzip_fill_special_value(void* dst, size_t dst_capacity, ttzip_special_desc_t desc);

double ttzip_quantum_calc_entropy_neon(const void* buf, size_t len);
void ttzip_quantum_copy_branchless_neon(void* dst, const void* src, size_t len);

size_t ttzip_quantum_rle_compress_neon(const void* src, size_t src_size, void* dst, size_t dst_capacity);
size_t ttzip_quantum_rle_decompress_neon(const void* src, size_t src_size, void* dst, size_t dst_capacity);

size_t ttzip_quantum_decompress_two_pass(
    const void* src,
    size_t src_size,
    void* dst,
    size_t dst_capacity
);

#ifdef __cplusplus
}
#endif

#endif /* CTTZipQuantumPipeline_h */
