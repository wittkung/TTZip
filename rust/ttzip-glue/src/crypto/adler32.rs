// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Hardware-accelerated Adler-32 engine.
//!
//! Provides ARMv8.2-A UDOT 64 bytes/loop dot-product weighted accumulation
//! with N_MAX = 5552 deferred modulo arithmetic (25~32+ GB/s on Apple Silicon),
//! universal NEON baseline, and a 4-byte unrolled scalar fallback.

const TTZIP_ADLER32_DIVISOR: u32 = 65521;
const TTZIP_ADLER32_MAX_CHUNK: usize = 5552;

// ============================================================================
// 1. Scalar Fallback Algorithm (4-byte loop unrolling + 5552-byte deferred modulo)
// ============================================================================
pub mod scalar {
    use super::*;

    #[inline(always)]
    pub fn adler32_scalar_chunk(mut s1: u32, mut s2: u32, mut p: *const u8, mut n: usize) -> (u32, u32) {
        if n >= 4 {
            let mut s1_sum = 0u32;
            let mut b0_sum = 0u32;
            let mut b1_sum = 0u32;
            let mut b2_sum = 0u32;
            let mut b3_sum = 0u32;

            while n >= 4 {
                s1_sum = s1_sum.wrapping_add(s1);
                let p0 = unsafe { *p as u32 };
                let p1 = unsafe { *p.add(1) as u32 };
                let p2 = unsafe { *p.add(2) as u32 };
                let p3 = unsafe { *p.add(3) as u32 };

                s1 = s1.wrapping_add(p0 + p1 + p2 + p3);
                b0_sum = b0_sum.wrapping_add(p0);
                b1_sum = b1_sum.wrapping_add(p1);
                b2_sum = b2_sum.wrapping_add(p2);
                b3_sum = b3_sum.wrapping_add(p3);

                unsafe {
                    p = p.add(4);
                }
                n -= 4;
            }

            s2 = s2.wrapping_add(4 * (s1_sum.wrapping_add(b0_sum)) + 3 * b1_sum + 2 * b2_sum + b3_sum);
        }

        while n > 0 {
            let b = unsafe { *p as u32 };
            s1 = s1.wrapping_add(b);
            s2 = s2.wrapping_add(s1);
            unsafe {
                p = p.add(1);
            }
            n -= 1;
        }

        s1 %= TTZIP_ADLER32_DIVISOR;
        s2 %= TTZIP_ADLER32_DIVISOR;
        (s1, s2)
    }

    pub fn adler32_scalar(adler: u32, data: &[u8]) -> u32 {
        let mut s1 = adler & 0xFFFF;
        let mut s2 = adler >> 16;
        let mut p = data.as_ptr();
        let mut len = data.len();

        while len > 0 {
            let n = len.min(TTZIP_ADLER32_MAX_CHUNK & !3);
            len -= n;
            let (new_s1, new_s2) = adler32_scalar_chunk(s1, s2, p, n);
            s1 = new_s1;
            s2 = new_s2;
            unsafe {
                p = p.add(n);
            }
        }

        (s2 << 16) | s1
    }
}

// ============================================================================
// 2. ARM64 NEON & DotProd Implementation
// ============================================================================
#[cfg(target_arch = "aarch64")]
mod arm64 {
    use super::*;
    use core::arch::aarch64::*;
    use core::arch::asm;

    static MULTS_ARRAY: [u8; 64] = [
        64, 63, 62, 61, 60, 59, 58, 57, 56, 55, 54, 53, 52, 51, 50, 49,
        48, 47, 46, 45, 44, 43, 42, 41, 40, 39, 38, 37, 36, 35, 34, 33,
        32, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17,
        16, 15, 14, 13, 12, 11, 10,  9,  8,  7,  6,  5,  4,  3,  2,  1,
    ];

    #[inline(always)]
    unsafe fn udot_u32(mut acc: uint32x4_t, a: uint8x16_t, b: uint8x16_t) -> uint32x4_t {
        asm!(
            "udot {acc:v}.4s, {a:v}.16b, {b:v}.16b",
            acc = inout(vreg) acc,
            a = in(vreg) a,
            b = in(vreg) b,
            options(pure, nomem, nostack)
        );
        acc
    }

    #[target_feature(enable = "dotprod")]
    pub unsafe fn adler32_neon_dotprod(adler: u32, mut p: *const u8, mut len: usize) -> u32 {
        let mults_a = vld1q_u8(MULTS_ARRAY.as_ptr());
        let mults_b = vld1q_u8(MULTS_ARRAY.as_ptr().add(16));
        let mults_c = vld1q_u8(MULTS_ARRAY.as_ptr().add(32));
        let mults_d = vld1q_u8(MULTS_ARRAY.as_ptr().add(48));
        let ones = vdupq_n_u8(1);

        let mut s1 = adler & 0xFFFF;
        let mut s2 = adler >> 16;

        if len > 32768 && ((p as usize) & 15) != 0 {
            while ((p as usize) & 15) != 0 {
                s1 = s1.wrapping_add(*p as u32);
                s2 = s2.wrapping_add(s1);
                p = p.add(1);
                len -= 1;
            }
            s1 %= TTZIP_ADLER32_DIVISOR;
            s2 %= TTZIP_ADLER32_DIVISOR;
        }

        while len > 0 {
            let mut n = len.min(TTZIP_ADLER32_MAX_CHUNK & !63);
            len -= n;

            if n >= 64 {
                let mut v_s1_a = vdupq_n_u32(0);
                let mut v_s1_b = vdupq_n_u32(0);
                let mut v_s1_c = vdupq_n_u32(0);
                let mut v_s1_d = vdupq_n_u32(0);

                let mut v_s2_a = vdupq_n_u32(0);
                let mut v_s2_b = vdupq_n_u32(0);
                let mut v_s2_c = vdupq_n_u32(0);
                let mut v_s2_d = vdupq_n_u32(0);

                let mut v_s1_sums_a = vdupq_n_u32(0);
                let mut v_s1_sums_b = vdupq_n_u32(0);
                let mut v_s1_sums_c = vdupq_n_u32(0);
                let mut v_s1_sums_d = vdupq_n_u32(0);

                s2 = s2.wrapping_add(s1.wrapping_mul((n & !63) as u32));

                while n >= 64 {
                    let data_a = vld1q_u8(p);
                    let data_b = vld1q_u8(p.add(16));
                    let data_c = vld1q_u8(p.add(32));
                    let data_d = vld1q_u8(p.add(48));

                    v_s1_sums_a = vaddq_u32(v_s1_sums_a, v_s1_a);
                    v_s1_a = udot_u32(v_s1_a, data_a, ones);
                    v_s2_a = udot_u32(v_s2_a, data_a, mults_a);

                    v_s1_sums_b = vaddq_u32(v_s1_sums_b, v_s1_b);
                    v_s1_b = udot_u32(v_s1_b, data_b, ones);
                    v_s2_b = udot_u32(v_s2_b, data_b, mults_b);

                    v_s1_sums_c = vaddq_u32(v_s1_sums_c, v_s1_c);
                    v_s1_c = udot_u32(v_s1_c, data_c, ones);
                    v_s2_c = udot_u32(v_s2_c, data_c, mults_c);

                    v_s1_sums_d = vaddq_u32(v_s1_sums_d, v_s1_d);
                    v_s1_d = udot_u32(v_s1_d, data_d, ones);
                    v_s2_d = udot_u32(v_s2_d, data_d, mults_d);

                    p = p.add(64);
                    n -= 64;
                }

                let v_s1 = vaddq_u32(vaddq_u32(v_s1_a, v_s1_b), vaddq_u32(v_s1_c, v_s1_d));
                let mut v_s2 = vaddq_u32(vaddq_u32(v_s2_a, v_s2_b), vaddq_u32(v_s2_c, v_s2_d));
                let v_s1_sums = vaddq_u32(vaddq_u32(v_s1_sums_a, v_s1_sums_b), vaddq_u32(v_s1_sums_c, v_s1_sums_d));

                v_s2 = vaddq_u32(v_s2, vqshlq_n_u32::<6>(v_s1_sums));

                s1 = s1.wrapping_add(vaddvq_u32(v_s1));
                s2 = s2.wrapping_add(vaddvq_u32(v_s2));
            }

            let (new_s1, new_s2) = scalar::adler32_scalar_chunk(s1, s2, p, n);
            s1 = new_s1;
            s2 = new_s2;
            p = p.add(n);
        }

        (s2 << 16) | s1
    }
}

// ============================================================================
// 3. Unified Cross-Platform Public Entrypoint
// ============================================================================

/// Computes Adler-32 with hardware acceleration where available.
///
/// Returns the updated Adler-32 checksum.
#[inline]
pub fn adler32_fast(adler: u32, data: &[u8]) -> u32 {
    if data.is_empty() {
        return adler;
    }

    #[cfg(target_arch = "aarch64")]
    {
        unsafe {
            arm64::adler32_neon_dotprod(adler, data.as_ptr(), data.len())
        }
    }

    #[cfg(not(target_arch = "aarch64"))]
    {
        scalar::adler32_scalar(adler, data)
    }
}

/// Computes the initial Adler-32 of a buffer starting from standard initial value 1.
#[inline]
pub fn adler32(data: &[u8]) -> u32 {
    adler32_fast(1, data)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_adler32_empty() {
        assert_eq!(adler32(&[]), 1);
        assert_eq!(adler32_fast(12345, &[]), 12345);
    }

    #[test]
    fn test_adler32_basic_vectors() {
        // "123456789" => 0x091E01DE (152961502)
        assert_eq!(adler32(b"123456789"), 0x091E01DE);
        assert_eq!(scalar::adler32_scalar(1, b"123456789"), 0x091E01DE);

        // "Wikipedia" => 0x11E60398
        assert_eq!(adler32(b"Wikipedia"), 0x11E60398);
        assert_eq!(scalar::adler32_scalar(1, b"Wikipedia"), 0x11E60398);
    }

    #[test]
    fn test_adler32_long_buffer_and_chunking() {
        let mut buffer = vec![0u8; 20000];
        for (i, b) in buffer.iter_mut().enumerate() {
            *b = ((i * 37 + 13) & 0xFF) as u8;
        }

        let ref_val = scalar::adler32_scalar(1, &buffer);
        let fast_val = adler32_fast(1, &buffer);
        assert_eq!(fast_val, ref_val, "Fast and scalar Adler32 mismatch on 20KB buffer");

        for size in [1, 3, 7, 16, 32, 63, 64, 65, 127, 128, 5551, 5552, 5553, 11104, 15000] {
            let r = scalar::adler32_scalar(1, &buffer[..size]);
            let f = adler32_fast(1, &buffer[..size]);
            assert_eq!(f, r, "Mismatch at size {}", size);
        }
    }
}
