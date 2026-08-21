// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Galois Field $\text{GF}(2^8)$ Arithmetic and ARM NEON Nibble SIMD Acceleration.
//!
//! Uses irreducible polynomial `0x11D` ($x^8 + x^4 + x^3 + x^2 + 1$).

#[cfg(target_arch = "aarch64")]
use core::arch::aarch64::*;

/// Generates exponential and logarithmic lookup tables at compile time.
const fn generate_gf8_tables() -> ([u8; 512], [u8; 256]) {
    let mut exp = [0u8; 512];
    let mut log = [0u8; 256];
    let mut x: u16 = 1;
    let mut i = 0;
    while i < 255 {
        exp[i] = x as u8;
        exp[i + 255] = x as u8;
        log[x as usize] = i as u8;
        x <<= 1;
        if x >= 256 {
            x ^= 0x11D;
        }
        i += 1;
    }
    exp[510] = exp[0];
    exp[511] = exp[1];
    log[0] = 0;
    (exp, log)
}

pub static EXP_TABLE: [u8; 512] = {
    let (exp, _) = generate_gf8_tables();
    exp
};

pub static LOG_TABLE: [u8; 256] = {
    let (_, log) = generate_gf8_tables();
    log
};

/// Addition in $\text{GF}(2^8)$ (bitwise XOR).
#[inline(always)]
pub const fn gf_add(a: u8, b: u8) -> u8 {
    a ^ b
}

/// Subtraction in $\text{GF}(2^8)$ (identical to addition).
#[inline(always)]
pub const fn gf_sub(a: u8, b: u8) -> u8 {
    a ^ b
}

/// Multiplication in $\text{GF}(2^8)$.
#[inline(always)]
pub fn gf_mul(a: u8, b: u8) -> u8 {
    if a == 0 || b == 0 {
        0
    } else {
        let idx = (LOG_TABLE[a as usize] as usize) + (LOG_TABLE[b as usize] as usize);
        EXP_TABLE[idx]
    }
}

/// Multiplicative inverse in $\text{GF}(2^8)$ ($a^{-1}$).
#[inline(always)]
pub fn gf_inv(a: u8) -> u8 {
    if a == 0 {
        0
    } else {
        let idx = 255 - (LOG_TABLE[a as usize] as usize);
        EXP_TABLE[idx]
    }
}

/// Division in $\text{GF}(2^8)$ ($a / b$).
#[inline(always)]
pub fn gf_div(a: u8, b: u8) -> u8 {
    if a == 0 || b == 0 {
        0
    } else {
        gf_mul(a, gf_inv(b))
    }
}

/// Computes $a^e$ in $\text{GF}(2^8)$.
pub fn gf_pow(a: u8, exp: usize) -> u8 {
    if a == 0 {
        return if exp == 0 { 1 } else { 0 };
    }
    if exp == 0 {
        return 1;
    }
    let log_a = LOG_TABLE[a as usize] as usize;
    let idx = (log_a * exp) % 255;
    EXP_TABLE[idx]
}

/// Precomputes 4-bit nibble split multiplication lookup tables (low and high 16 bytes).
#[inline(always)]
pub fn compute_nibble_tables(coeff: u8) -> ([u8; 16], [u8; 16]) {
    let mut tbl_low = [0u8; 16];
    let mut tbl_high = [0u8; 16];
    for i in 0..16 {
        tbl_low[i] = gf_mul(coeff, i as u8);
        tbl_high[i] = gf_mul(coeff, (i << 4) as u8);
    }
    (tbl_low, tbl_high)
}

/// Multiplies a slice by scalar `coeff` in $\text{GF}(2^8)$ and XOR-accumulates into `dst`.
///
/// `dst[i] ^= coeff * src[i]`
#[inline]
pub fn gf8_mul_add_slice(coeff: u8, src: &[u8], dst: &mut [u8]) {
    if coeff == 0 {
        return;
    }
    let len = src.len().min(dst.len());
    if len == 0 {
        return;
    }

    #[cfg(target_arch = "aarch64")]
    unsafe {
        neon_gf8_mul_add_raw(coeff, src.as_ptr(), dst.as_mut_ptr(), len);
    }

    #[cfg(not(target_arch = "aarch64"))]
    {
        scalar_gf8_mul_add_raw(coeff, src, dst, len);
    }
}

/// Scalar fallback for `dst[i] ^= coeff * src[i]`.
#[inline]
pub fn scalar_gf8_mul_add_raw(coeff: u8, src: &[u8], dst: &mut [u8], len: usize) {
    if coeff == 1 {
        for i in 0..len {
            dst[i] ^= src[i];
        }
        return;
    }
    let (tbl_low, tbl_high) = compute_nibble_tables(coeff);
    for i in 0..len {
        let b = src[i];
        let p = tbl_low[(b & 0x0F) as usize] ^ tbl_high[(b >> 4) as usize];
        dst[i] ^= p;
    }
}

/// ARM NEON 4-Way unrolled nibble split SIMD multiplication (>25 GB/s).
#[cfg(target_arch = "aarch64")]
#[inline]
unsafe fn neon_gf8_mul_add_raw(coeff: u8, mut src: *const u8, mut dst: *mut u8, mut len: usize) {
    if coeff == 1 {
        while len >= 64 {
            let s0 = vld1q_u8(src);
            let s1 = vld1q_u8(src.add(16));
            let s2 = vld1q_u8(src.add(32));
            let s3 = vld1q_u8(src.add(48));

            let d0 = vld1q_u8(dst);
            let d1 = vld1q_u8(dst.add(16));
            let d2 = vld1q_u8(dst.add(32));
            let d3 = vld1q_u8(dst.add(48));

            vst1q_u8(dst, veorq_u8(d0, s0));
            vst1q_u8(dst.add(16), veorq_u8(d1, s1));
            vst1q_u8(dst.add(32), veorq_u8(d2, s2));
            vst1q_u8(dst.add(48), veorq_u8(d3, s3));

            src = src.add(64);
            dst = dst.add(64);
            len -= 64;
        }
        while len >= 16 {
            let s = vld1q_u8(src);
            let d = vld1q_u8(dst);
            vst1q_u8(dst, veorq_u8(d, s));
            src = src.add(16);
            dst = dst.add(16);
            len -= 16;
        }
        while len > 0 {
            *dst ^= *src;
            src = src.add(1);
            dst = dst.add(1);
            len -= 1;
        }
        return;
    }

    let (tbl_l, tbl_h) = compute_nibble_tables(coeff);
    let t_low = vld1q_u8(tbl_l.as_ptr());
    let t_high = vld1q_u8(tbl_h.as_ptr());
    let mask_low = vdupq_n_u8(0x0F);

    // 64-byte unrolled loop
    while len >= 64 {
        let v0 = vld1q_u8(src);
        let v1 = vld1q_u8(src.add(16));
        let v2 = vld1q_u8(src.add(32));
        let v3 = vld1q_u8(src.add(48));

        let l0 = vandq_u8(v0, mask_low);
        let h0 = vshrq_n_u8(v0, 4);
        let l1 = vandq_u8(v1, mask_low);
        let h1 = vshrq_n_u8(v1, 4);
        let l2 = vandq_u8(v2, mask_low);
        let h2 = vshrq_n_u8(v2, 4);
        let l3 = vandq_u8(v3, mask_low);
        let h3 = vshrq_n_u8(v3, 4);

        let p0 = veorq_u8(vqtbl1q_u8(t_low, l0), vqtbl1q_u8(t_high, h0));
        let p1 = veorq_u8(vqtbl1q_u8(t_low, l1), vqtbl1q_u8(t_high, h1));
        let p2 = veorq_u8(vqtbl1q_u8(t_low, l2), vqtbl1q_u8(t_high, h2));
        let p3 = veorq_u8(vqtbl1q_u8(t_low, l3), vqtbl1q_u8(t_high, h3));

        let d0 = vld1q_u8(dst);
        let d1 = vld1q_u8(dst.add(16));
        let d2 = vld1q_u8(dst.add(32));
        let d3 = vld1q_u8(dst.add(48));

        vst1q_u8(dst, veorq_u8(d0, p0));
        vst1q_u8(dst.add(16), veorq_u8(d1, p1));
        vst1q_u8(dst.add(32), veorq_u8(d2, p2));
        vst1q_u8(dst.add(48), veorq_u8(d3, p3));

        src = src.add(64);
        dst = dst.add(64);
        len -= 64;
    }

    while len >= 16 {
        let v = vld1q_u8(src);
        let l = vandq_u8(v, mask_low);
        let h = vshrq_n_u8(v, 4);
        let prod = veorq_u8(vqtbl1q_u8(t_low, l), vqtbl1q_u8(t_high, h));
        let cur = vld1q_u8(dst);
        vst1q_u8(dst, veorq_u8(cur, prod));

        src = src.add(16);
        dst = dst.add(16);
        len -= 16;
    }

    while len > 0 {
        let b = *src;
        let p = tbl_l[(b & 0x0F) as usize] ^ tbl_h[(b >> 4) as usize];
        *dst ^= p;
        src = src.add(1);
        dst = dst.add(1);
        len -= 1;
    }
}
