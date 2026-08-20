// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/ttzip_reed_solomon.h"
#include <string.h>
#include <stdlib.h>

#if defined(__ARM_NEON) || defined(__ARM_NEON__)
#include <arm_neon.h>
#define TTZIP_HAS_NEON 1
#else
#define TTZIP_HAS_NEON 0
#endif

// MARK: - Precomputed GF(2^8) Galois Field Tables (Polynomial 0x11D)

static uint8_t g_rs_exp[512];
static uint8_t g_rs_log[256];
static bool g_rs_initialized = false;

static void ttzip_rs_init_tables(void) {
    if (g_rs_initialized) return;
    uint16_t x = 1;
    for (int i = 0; i < 255; i++) {
        g_rs_exp[i] = (uint8_t)x;
        g_rs_exp[i + 255] = (uint8_t)x;
        x = (x << 1) ^ (x >= 128 ? 0x11D : 0);
    }
    g_rs_exp[510] = g_rs_exp[0];
    g_rs_exp[511] = g_rs_exp[1];

    for (int i = 0; i < 255; i++) {
        g_rs_log[g_rs_exp[i]] = (uint8_t)i;
    }
    g_rs_log[0] = 0;
    g_rs_initialized = true;
}

const uint8_t ttzip_rs_exp_table[512] = {0};
const uint8_t ttzip_rs_log_table[256] = {0};

static inline uint8_t rs_gf_mul(uint8_t a, uint8_t b) {
    if (!g_rs_initialized) ttzip_rs_init_tables();
    if (a == 0 || b == 0) return 0;
    return g_rs_exp[(size_t)g_rs_log[a] + (size_t)g_rs_log[b]];
}

static inline uint8_t rs_gf_inv(uint8_t a) {
    if (!g_rs_initialized) ttzip_rs_init_tables();
    if (a == 0) return 0;
    return g_rs_exp[255 - (size_t)g_rs_log[a]];
}

int ttzip_rs_create_cauchy_matrix(size_t rows_m, size_t cols_k, uint8_t* out_matrix) {
    if (!out_matrix || rows_m == 0 || cols_k == 0) return -1;
    if (!g_rs_initialized) ttzip_rs_init_tables();

    for (size_t i = 0; i < rows_m; i++) {
        uint8_t xi = (uint8_t)i;
        for (size_t j = 0; j < cols_k; j++) {
            uint8_t yj = (uint8_t)(rows_m + j);
            uint8_t diff = xi ^ yj;
            out_matrix[i * cols_k + j] = rs_gf_inv(diff);
        }
    }
    return 0;
}

int ttzip_rs_invert_matrix(const uint8_t* in_matrix, size_t n, uint8_t* out_matrix) {
    if (!in_matrix || !out_matrix || n == 0) return -1;
    if (!g_rs_initialized) ttzip_rs_init_tables();

    // Augmented matrix [A | I] of size n x 2n
    size_t width = n * 2;
    uint8_t* aug = (uint8_t*)malloc(n * width);
    if (!aug) return -1;

    for (size_t i = 0; i < n; i++) {
        for (size_t j = 0; j < n; j++) {
            aug[i * width + j] = in_matrix[i * n + j];
        }
        for (size_t j = n; j < width; j++) {
            aug[i * width + j] = (j - n == i) ? 1 : 0;
        }
    }

    // Gauss-Jordan elimination
    for (size_t col = 0; col < n; col++) {
        size_t pivot_row = col;
        while (pivot_row < n && aug[pivot_row * width + col] == 0) {
            pivot_row++;
        }
        if (pivot_row == n) {
            free(aug);
            return -1; // Singular matrix
        }

        if (pivot_row != col) {
            for (size_t j = 0; j < width; j++) {
                uint8_t tmp = aug[col * width + j];
                aug[col * width + j] = aug[pivot_row * width + j];
                aug[pivot_row * width + j] = tmp;
            }
        }

        uint8_t pivot_val = aug[col * width + col];
        uint8_t pivot_inv = rs_gf_inv(pivot_val);
        for (size_t j = 0; j < width; j++) {
            aug[col * width + j] = rs_gf_mul(aug[col * width + j], pivot_inv);
        }

        for (size_t r = 0; r < n; r++) {
            if (r == col) continue;
            uint8_t factor = aug[r * width + col];
            if (factor == 0) continue;
            for (size_t j = 0; j < width; j++) {
                aug[r * width + j] ^= rs_gf_mul(aug[col * width + j], factor);
            }
        }
    }

    for (size_t i = 0; i < n; i++) {
        for (size_t j = 0; j < n; j++) {
            out_matrix[i * n + j] = aug[i * width + (j + n)];
        }
    }

    free(aug);
    return 0;
}

#if TTZIP_HAS_NEON
static inline void rs_vector_mul_add_neon(uint8_t* dst, const uint8_t* src, uint8_t coeff, size_t len) {
    if (coeff == 0 || len == 0) return;
    if (coeff == 1) {
        size_t i = 0;
        for (; i + 16 <= len; i += 16) {
            uint8x16_t d = vld1q_u8(dst + i);
            uint8x16_t s = vld1q_u8(src + i);
            vst1q_u8(dst + i, veorq_u8(d, s));
        }
        for (; i < len; i++) {
            dst[i] ^= src[i];
        }
        return;
    }

    uint8_t tbl_lo_arr[16];
    uint8_t tbl_hi_arr[16];
    for (int k = 0; k < 16; k++) {
        tbl_lo_arr[k] = rs_gf_mul((uint8_t)k, coeff);
        tbl_hi_arr[k] = rs_gf_mul((uint8_t)(k << 4), coeff);
    }
    uint8x16_t tbl_lo = vld1q_u8(tbl_lo_arr);
    uint8x16_t tbl_hi = vld1q_u8(tbl_hi_arr);
    uint8x16_t mask_lo = vdupq_n_u8(0x0F);

    size_t i = 0;
    for (; i + 16 <= len; i += 16) {
        uint8x16_t d = vld1q_u8(dst + i);
        uint8x16_t s = vld1q_u8(src + i);

        uint8x16_t lo = vandq_u8(s, mask_lo);
        uint8x16_t hi = vshrq_n_u8(s, 4);

        uint8x16_t prod_lo = vqtbl1q_u8(tbl_lo, lo);
        uint8x16_t prod_hi = vqtbl1q_u8(tbl_hi, hi);
        uint8x16_t prod = veorq_u8(prod_lo, prod_hi);

        vst1q_u8(dst + i, veorq_u8(d, prod));
    }
    for (; i < len; i++) {
        dst[i] ^= rs_gf_mul(src[i], coeff);
    }
}
#else
static inline void rs_vector_mul_add_scalar(uint8_t* dst, const uint8_t* src, uint8_t coeff, size_t len) {
    if (coeff == 0) return;
    for (size_t i = 0; i < len; i++) {
        dst[i] ^= rs_gf_mul(src[i], coeff);
    }
}
#endif

int ttzip_rs_encode_neon(
    const uint8_t* const* data_slices,
    size_t k,
    uint8_t* const* parity_slices,
    size_t m,
    size_t slice_size
) {
    if (!data_slices || !parity_slices || k == 0 || m == 0 || slice_size == 0) return -1;
    if (!g_rs_initialized) ttzip_rs_init_tables();

    uint8_t* cauchy_matrix = (uint8_t*)malloc(m * k);
    if (!cauchy_matrix) return -1;
    if (ttzip_rs_create_cauchy_matrix(m, k, cauchy_matrix) != 0) {
        free(cauchy_matrix);
        return -1;
    }

    for (size_t i = 0; i < m; i++) {
        memset(parity_slices[i], 0, slice_size);
        for (size_t j = 0; j < k; j++) {
            uint8_t coeff = cauchy_matrix[i * k + j];
#if TTZIP_HAS_NEON
            rs_vector_mul_add_neon(parity_slices[i], data_slices[j], coeff, slice_size);
#else
            rs_vector_mul_add_scalar(parity_slices[i], data_slices[j], coeff, slice_size);
#endif
        }
    }

    free(cauchy_matrix);
    return 0;
}

int ttzip_rs_decode_neon(
    const uint8_t* const* available_slices,
    const int* slice_indices,
    size_t available_count,
    size_t k,
    size_t m,
    const int* missing_indices,
    size_t missing_count,
    uint8_t* const* reconstructed_slices,
    size_t slice_size
) {
    if (!available_slices || !slice_indices || !missing_indices || !reconstructed_slices) return -1;
    if (available_count < k || missing_count > m || missing_count == 0) return -1;
    if (!g_rs_initialized) ttzip_rs_init_tables();

    // Generate Cauchy matrix for all M parity equations
    uint8_t* cauchy_matrix = (uint8_t*)malloc(m * k);
    if (!cauchy_matrix) return -1;
    ttzip_rs_create_cauchy_matrix(m, k, cauchy_matrix);

    // Build K x K encoding submatrix corresponding to the chosen K available slices
    uint8_t* submatrix = (uint8_t*)malloc(k * k);
    if (!submatrix) {
        free(cauchy_matrix);
        return -1;
    }

    for (size_t row = 0; row < k; row++) {
        int idx = slice_indices[row];
        if (idx < (int)k) {
            // Intact data slice: identity equation
            for (size_t c = 0; c < k; c++) {
                submatrix[row * k + c] = (c == (size_t)idx) ? 1 : 0;
            }
        } else {
            // Parity slice: row (idx - k) of Cauchy matrix
            size_t parity_idx = (size_t)(idx - (int)k);
            for (size_t c = 0; c < k; c++) {
                submatrix[row * k + c] = cauchy_matrix[parity_idx * k + c];
            }
        }
    }

    // Invert submatrix to get decoding matrix
    uint8_t* inv_matrix = (uint8_t*)malloc(k * k);
    if (!inv_matrix) {
        free(cauchy_matrix);
        free(submatrix);
        return -1;
    }

    if (ttzip_rs_invert_matrix(submatrix, k, inv_matrix) != 0) {
        free(cauchy_matrix);
        free(submatrix);
        free(inv_matrix);
        return -1; // Unrecoverable
    }

    // Reconstruct each missing data slice
    for (size_t m_idx = 0; m_idx < missing_count; m_idx++) {
        int missing_data_idx = missing_indices[m_idx];
        if (missing_data_idx >= (int)k) continue;

        memset(reconstructed_slices[m_idx], 0, slice_size);
        const uint8_t* decode_row = inv_matrix + (missing_data_idx * k);

        for (size_t j = 0; j < k; j++) {
            uint8_t coeff = decode_row[j];
#if TTZIP_HAS_NEON
            rs_vector_mul_add_neon(reconstructed_slices[m_idx], available_slices[j], coeff, slice_size);
#else
            rs_vector_mul_add_scalar(reconstructed_slices[m_idx], available_slices[j], coeff, slice_size);
#endif
        }
    }

    free(cauchy_matrix);
    free(submatrix);
    free(inv_matrix);
    return 0;
}
