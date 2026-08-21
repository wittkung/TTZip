// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Systematic Cauchy Reed-Solomon Erasure Coding and Matrix Inversion over $\text{GF}(2^8)$.

use super::gf8::{gf_inv, gf_mul, gf8_mul_add_slice};
use crate::types::TTZipStatus;

/// Constructs an $M \times K$ Cauchy generator matrix.
///
/// Element $C_{i, j} = \frac{1}{i \oplus (M + j)}$.
pub fn create_cauchy_matrix(rows_m: usize, cols_k: usize) -> Vec<u8> {
    let mut matrix = vec![0u8; rows_m * cols_k];
    for i in 0..rows_m {
        for j in 0..cols_k {
            let diff = (i as u8) ^ ((rows_m + j) as u8);
            matrix[i * cols_k + j] = gf_inv(diff);
        }
    }
    matrix
}

/// Inverts an $N \times N$ matrix over $\text{GF}(2^8)$ using Gaussian elimination.
pub fn invert_matrix(matrix: &[u8], n: usize) -> Result<Vec<u8>, TTZipStatus> {
    if matrix.len() != n * n || n == 0 {
        return Err(TTZipStatus::ErrInvalidParam);
    }

    let width = n * 2;
    let mut aug = vec![0u8; n * width];

    for i in 0..n {
        for j in 0..n {
            aug[i * width + j] = matrix[i * n + j];
        }
        for j in 0..n {
            aug[i * width + n + j] = if i == j { 1 } else { 0 };
        }
    }

    for col in 0..n {
        let mut pivot_row = col;
        while pivot_row < n && aug[pivot_row * width + col] == 0 {
            pivot_row += 1;
        }
        if pivot_row == n {
            return Err(TTZipStatus::ErrCorruptHeader); // Singular matrix
        }

        if pivot_row != col {
            for k in 0..width {
                let tmp = aug[col * width + k];
                aug[col * width + k] = aug[pivot_row * width + k];
                aug[pivot_row * width + k] = tmp;
            }
        }

        let pivot_inv = gf_inv(aug[col * width + col]);
        for k in 0..width {
            aug[col * width + k] = gf_mul(aug[col * width + k], pivot_inv);
        }

        for r in 0..n {
            if r == col {
                continue;
            }
            let factor = aug[r * width + col];
            if factor == 0 {
                continue;
            }
            for k in 0..width {
                let term = gf_mul(aug[col * width + k], factor);
                aug[r * width + k] ^= term;
            }
        }
    }

    let mut inv = vec![0u8; n * n];
    for i in 0..n {
        for j in 0..n {
            inv[i * n + j] = aug[i * width + n + j];
        }
    }
    Ok(inv)
}

/// High-performance Systematic Cauchy Reed-Solomon Codec.
#[derive(Debug, Clone)]
pub struct ReedSolomonEngine {
    pub k: usize,
    pub m: usize,
    pub cauchy_matrix: Vec<u8>,
}

impl ReedSolomonEngine {
    /// Creates a new Reed-Solomon engine for $K$ data shards and $M$ parity shards.
    pub fn new(k: usize, m: usize) -> Result<Self, TTZipStatus> {
        if k == 0 || m == 0 || k + m > 256 {
            return Err(TTZipStatus::ErrInvalidParam);
        }
        let cauchy_matrix = create_cauchy_matrix(m, k);
        Ok(Self {
            k,
            m,
            cauchy_matrix,
        })
    }

    /// Encodes $K$ data shards into $M$ parity shards.
    pub fn encode(
        &self,
        data_shards: &[&[u8]],
        parity_shards: &mut [&mut [u8]],
    ) -> Result<(), TTZipStatus> {
        if data_shards.len() != self.k || parity_shards.len() != self.m {
            return Err(TTZipStatus::ErrInvalidParam);
        }
        let block_size = data_shards[0].len();
        if block_size == 0 {
            return Err(TTZipStatus::ErrInvalidParam);
        }

        for (p, p_slice) in parity_shards.iter_mut().enumerate() {
            if p_slice.len() != block_size {
                return Err(TTZipStatus::ErrInvalidParam);
            }
            p_slice.fill(0);
            for (d, d_slice) in data_shards.iter().enumerate() {
                if d_slice.len() != block_size {
                    return Err(TTZipStatus::ErrInvalidParam);
                }
                let coeff = self.cauchy_matrix[p * self.k + d];
                if coeff != 0 {
                    gf8_mul_add_slice(coeff, d_slice, p_slice);
                }
            }
        }
        Ok(())
    }

    /// Reconstructs missing data shards from any $K$ available shards (data or parity).
    pub fn decode(
        &self,
        available_shards: &[&[u8]],
        available_indices: &[usize],
        missing_indices: &[usize],
        reconstructed: &mut [&mut [u8]],
    ) -> Result<(), TTZipStatus> {
        if available_shards.len() < self.k
            || available_indices.len() != available_shards.len()
            || missing_indices.len() != reconstructed.len()
            || missing_indices.is_empty()
        {
            return Err(TTZipStatus::ErrInvalidParam);
        }

        let block_size = available_shards[0].len();
        if block_size == 0 {
            return Err(TTZipStatus::ErrInvalidParam);
        }

        let k = self.k;
        let mut submatrix = vec![0u8; k * k];
        for r in 0..k {
            let idx = available_indices[r];
            if idx < k {
                for c in 0..k {
                    submatrix[r * k + c] = if c == idx { 1 } else { 0 };
                }
            } else {
                let parity_row = idx - k;
                if parity_row >= self.m {
                    return Err(TTZipStatus::ErrInvalidParam);
                }
                for c in 0..k {
                    submatrix[r * k + c] = self.cauchy_matrix[parity_row * k + c];
                }
            }
        }

        let inv_matrix = invert_matrix(&submatrix, k)?;

        for (m_idx, &missing_col) in missing_indices.iter().enumerate() {
            if missing_col >= k {
                continue;
            }
            let dst = &mut reconstructed[m_idx];
            if dst.len() != block_size {
                return Err(TTZipStatus::ErrInvalidParam);
            }
            dst.fill(0);

            for r in 0..k {
                let coeff = inv_matrix[missing_col * k + r];
                if coeff != 0 {
                    gf8_mul_add_slice(coeff, available_shards[r], dst);
                }
            }
        }

        Ok(())
    }
}
