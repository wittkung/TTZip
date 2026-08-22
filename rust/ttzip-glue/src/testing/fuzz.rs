// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Deterministic SplitMix64 PRNG and 10-operator fuzzing mutation engine.

use crate::types::TTZipStatus;
use std::panic::catch_unwind;

/// 64-bit deterministic SplitMix64 pseudo-random number generator.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct SplitMix64 {
    pub state: u64,
}

impl SplitMix64 {
    #[inline]
    pub fn new(seed: u64) -> Self {
        Self { state: seed }
    }

    #[inline]
    pub fn next_u64(&mut self) -> u64 {
        self.state = self.state.wrapping_add(0x9E3779B97F4A7C15);
        let mut z = self.state;
        z = (z ^ (z >> 30)).wrapping_mul(0xBF58476D1CE4E5B9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94D049BB133111EB);
        z ^ (z >> 31)
    }

    #[inline]
    pub fn next_range(&mut self, min: usize, max: usize) -> usize {
        if min >= max {
            return min;
        }
        let range = (max - min) as u64;
        min + (self.next_u64() % range) as usize
    }
}

/// 10 deterministic mutation operators for format robustness and security testing.
#[repr(u32)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MutationOperator {
    BitFlip = 0,
    ByteReplace = 1,
    CorruptMagic = 2,
    CorruptCRC = 3,
    TruncateStream = 4,
    InjectZipSlipPath = 5,
    OversizeHeader = 6,
    InvalidDictSize = 7,
    ShuffleChunk = 8,
    ZeroRange = 9,
}

impl MutationOperator {
    pub fn from_u32(val: u32) -> Option<Self> {
        match val {
            0 => Some(Self::BitFlip),
            1 => Some(Self::ByteReplace),
            2 => Some(Self::CorruptMagic),
            3 => Some(Self::CorruptCRC),
            4 => Some(Self::TruncateStream),
            5 => Some(Self::InjectZipSlipPath),
            6 => Some(Self::OversizeHeader),
            7 => Some(Self::InvalidDictSize),
            8 => Some(Self::ShuffleChunk),
            9 => Some(Self::ZeroRange),
            _ => None,
        }
    }
}

/// Applies a specified deterministic mutation operator to an archive byte stream.
pub fn mutate_stream(data: &[u8], op: MutationOperator, prng: &mut SplitMix64) -> Vec<u8> {
    if data.is_empty() {
        return Vec::new();
    }
    let mut out = data.to_vec();

    match op {
        MutationOperator::BitFlip => {
            let byte_idx = prng.next_range(0, out.len());
            let bit_pos = prng.next_range(0, 8);
            out[byte_idx] ^= 1 << bit_pos;
        }
        MutationOperator::ByteReplace => {
            let byte_idx = prng.next_range(0, out.len());
            let val = if prng.next_u64().is_multiple_of(2) { 0x00 } else { 0xFF };
            out[byte_idx] = val;
        }
        MutationOperator::CorruptMagic => {
            let flip_len = 4.min(out.len());
            for b in out[..flip_len].iter_mut() {
                *b ^= 0xFF;
            }
        }
        MutationOperator::CorruptCRC => {
            if out.len() >= 18 {
                for b in out[14..18].iter_mut() {
                    *b ^= 0xFF;
                }
            } else {
                let mid = out.len() / 2;
                let end = out.len().min(mid + 4);
                for b in out[mid..end].iter_mut() {
                    *b ^= 0xFF;
                }
            }
        }
        MutationOperator::TruncateStream => {
            if out.len() <= 2 {
                return Vec::new();
            }
            let min_cut = 1.max((out.len() as f64 * 0.1) as usize);
            let max_cut = (min_cut + 1).max((out.len() - 1).min((out.len() as f64 * 0.9) as usize));
            let cut = prng.next_range(min_cut, max_cut);
            out.truncate(cut);
        }
        MutationOperator::InjectZipSlipPath => {
            let evil = b"../../../../../../etc/passwd\0";
            let pk = [0x50, 0x4B, 0x03, 0x04];
            if let Some(pos) = find_signature(&out, &pk) {
                if pos + 30 <= out.len() {
                    let name_len = (out[pos + 26] as usize) | ((out[pos + 27] as usize) << 8);
                    let mut injected = Vec::with_capacity(out.len() + evil.len());
                    injected.extend_from_slice(&out[..pos + 26]);
                    let new_len = evil.len() as u16;
                    injected.push((new_len & 0xFF) as u8);
                    injected.push(((new_len >> 8) & 0xFF) as u8);
                    injected.extend_from_slice(&out[pos + 28..pos + 30]);
                    injected.extend_from_slice(evil);
                    let rem_offset = pos + 30 + name_len;
                    if rem_offset < out.len() {
                        injected.extend_from_slice(&out[rem_offset..]);
                    }
                    return injected;
                }
            }
            let overwrite_len = evil.len().min(out.len());
            out[..overwrite_len].copy_from_slice(&evil[..overwrite_len]);
        }
        MutationOperator::OversizeHeader => {
            let pk = [0x50, 0x4B, 0x03, 0x04];
            if let Some(pos) = find_signature(&out, &pk) {
                if pos + 26 <= out.len() {
                    for b in out[pos + 18..pos + 26].iter_mut() {
                        *b = 0xFF;
                    }
                }
            } else if out.len() >= 512 {
                let octal_max = b"77777777777\0";
                let len = octal_max.len().min(12);
                out[124..124 + len].copy_from_slice(&octal_max[..len]);
            } else {
                let tgt = 16.min(out.len().saturating_sub(4));
                let end = out.len().min(tgt + 4);
                for b in out[tgt..end].iter_mut() {
                    *b = 0xFF;
                }
            }
        }
        MutationOperator::InvalidDictSize => {
            let sz = [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C];
            let xz = [0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00];
            let zstd = [0x28, 0xB5, 0x2F, 0xFD];
            let is_sz = find_signature(&out, &sz).is_some() && out.len() > 10;
            let is_xz = find_signature(&out, &xz).is_some() && out.len() > 8;
            if is_sz || is_xz {
                out[6] = 0xFF;
                out[7] = 0xFF;
            } else if find_signature(&out, &zstd).is_some() && out.len() > 5 {
                out[4] = 0xFF;
            } else {
                let idx = 6.min(out.len().saturating_sub(1));
                out[idx] = 0xFF;
            }
        }
        MutationOperator::ShuffleChunk => {
            let chunk_len = prng.next_range(4, 16.min(out.len()) + 1);
            let start = prng.next_range(0, out.len().saturating_sub(chunk_len) + 1);
            // Fisher-Yates shuffle
            for i in (1..chunk_len).rev() {
                let j = prng.next_range(0, i + 1);
                out.swap(start + i, start + j);
            }
        }
        MutationOperator::ZeroRange => {
            let zero_len = prng.next_range(1, 64.min(out.len()) + 1);
            let start = prng.next_range(0, out.len().saturating_sub(zero_len) + 1);
            for b in out[start..start + zero_len].iter_mut() {
                *b = 0x00;
            }
        }
    }

    out
}

#[inline]
fn find_signature(data: &[u8], sig: &[u8]) -> Option<usize> {
    if data.len() < sig.len() || sig.is_empty() {
        return None;
    }
    let max_search = (data.len() - sig.len()).min(4096);
    for i in 0..=max_search {
        if &data[i..i + sig.len()] == sig {
            return Some(i);
        }
    }
    None
}

/// C-ABI: Applies a deterministic mutation operator to an input buffer.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_fuzz_mutate(
    data: *const u8,
    len: usize,
    op_index: u32,
    seed: u64,
    out_buf: *mut u8,
    out_cap: usize,
    out_len: *mut usize,
    next_seed: *mut u64,
) -> TTZipStatus {
    let result = catch_unwind(|| {
        if data.is_null() && len > 0 {
            return TTZipStatus::ErrInvalidParam;
        }
        if out_len.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }

        let op = match MutationOperator::from_u32(op_index) {
            Some(o) => o,
            None => return TTZipStatus::ErrInvalidParam,
        };

        let mut prng = SplitMix64::new(seed);
        let src = if len > 0 {
            std::slice::from_raw_parts(data, len)
        } else {
            &[]
        };

        let mutated = mutate_stream(src, op, &mut prng);
        *out_len = mutated.len();

        if !next_seed.is_null() {
            *next_seed = prng.state;
        }

        if !out_buf.is_null() && out_cap > 0 {
            if mutated.len() > out_cap {
                return TTZipStatus::ErrOutOfMemory;
            }
            if !mutated.is_empty() {
                std::ptr::copy_nonoverlapping(mutated.as_ptr(), out_buf, mutated.len());
            }
        }

        TTZipStatus::Ok
    });
    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}
