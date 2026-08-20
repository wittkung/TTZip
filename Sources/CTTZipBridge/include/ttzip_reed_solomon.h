// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#ifndef TTZIP_REED_SOLOMON_H
#define TTZIP_REED_SOLOMON_H

#include "ttzip_platform.h"
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Galois Field GF(2^8) lookup tables
extern const uint8_t ttzip_rs_exp_table[512];
extern const uint8_t ttzip_rs_log_table[256];

/**
 * @brief Multiplies two elements in GF(2^8).
 */
static inline uint8_t ttzip_rs_gf_mul(uint8_t a, uint8_t b) {
    if (a == 0 || b == 0) return 0;
    return ttzip_rs_exp_table[(size_t)ttzip_rs_log_table[a] + (size_t)ttzip_rs_log_table[b]];
}

/**
 * @brief Computes multiplicative inverse in GF(2^8).
 */
static inline uint8_t ttzip_rs_gf_inv(uint8_t a) {
    if (a == 0) return 0;
    return ttzip_rs_exp_table[255 - ttzip_rs_log_table[a]];
}

/**
 * @brief Initializes an M x K Cauchy generator matrix in GF(2^8).
 * @param rows_m Number of parity slices (M).
 * @param cols_k Number of data slices (K).
 * @param out_matrix Destination buffer of size M * K bytes.
 * @return 0 on success, negative error code on invalid parameters.
 */
TTZIP_API int ttzip_rs_create_cauchy_matrix(
    size_t rows_m,
    size_t cols_k,
    uint8_t* out_matrix
);

/**
 * @brief Inverts an N x N matrix in GF(2^8) using Gauss-Jordan elimination.
 * @param in_matrix Row-major input matrix (N * N bytes).
 * @param n Dimension of square matrix.
 * @param out_matrix Destination buffer for inverted matrix (N * N bytes).
 * @return 0 on success, -1 if matrix is singular.
 */
TTZIP_API int ttzip_rs_invert_matrix(
    const uint8_t* in_matrix,
    size_t n,
    uint8_t* out_matrix
);

/**
 * @brief Encodes K data slices into M parity slices using ARM NEON SIMD acceleration.
 * @param data_slices Array of K pointers to intact data buffers.
 * @param k Number of data slices.
 * @param parity_slices Array of M pointers to destination parity buffers.
 * @param m Number of parity slices.
 * @param slice_size Size of each slice in bytes.
 * @return 0 on success, negative on error.
 */
TTZIP_API int ttzip_rs_encode_neon(
    const uint8_t* const* data_slices,
    size_t k,
    uint8_t* const* parity_slices,
    size_t m,
    size_t slice_size
);

/**
 * @brief Decodes and reconstructs missing data slices from intact data and parity slices.
 * @param available_slices Array of intact data and parity slice pointers.
 * @param slice_indices Array of global indices corresponding to available_slices (0..K-1 for data, K..K+M-1 for parity).
 * @param available_count Total available slices provided (must be >= K).
 * @param k Number of original data slices.
 * @param m Number of parity slices.
 * @param missing_indices Array of missing data slice indices (each in 0..K-1).
 * @param missing_count Number of missing data slices to reconstruct (must be <= M).
 * @param reconstructed_slices Destination buffer pointers for the missing slices.
 * @param slice_size Size of each slice in bytes.
 * @return 0 on success, negative on unrecoverable erasure count or singular matrix.
 */
TTZIP_API int ttzip_rs_decode_neon(
    const uint8_t* const* available_slices,
    const int* slice_indices,
    size_t available_count,
    size_t k,
    size_t m,
    const int* missing_indices,
    size_t missing_count,
    uint8_t* const* reconstructed_slices,
    size_t slice_size
);

#ifdef __cplusplus
}
#endif

#endif // TTZIP_REED_SOLOMON_H
