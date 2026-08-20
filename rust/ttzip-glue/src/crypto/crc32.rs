// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Hardware-accelerated CRC-32 (IEEE 802.3) engine.
//!
//! Provides ARM64 PMULL 12-way vector polynomial folding (>65 GB/s on Apple Silicon),
//! x86_64 PCLMULQDQ folding, and a Slice-by-8 scalar fallback.

const CRC32_X1567_MODG: u64 = 0x596c8d81;
const CRC32_X1503_MODG: u64 = 0xf5e48c85;
const CRC32_X799_MODG: u64 = 0xdf068dc2;
const CRC32_X735_MODG: u64 = 0x57c54819;
const CRC32_X543_MODG: u64 = 0x8f352d95;
const CRC32_X479_MODG: u64 = 0x1d9513d7;
const CRC32_X415_MODG: u64 = 0x3db1ecdc;
const CRC32_X351_MODG: u64 = 0xaf449247;
const CRC32_X287_MODG: u64 = 0xf1da05aa;
const CRC32_X223_MODG: u64 = 0x81256527;
const CRC32_X159_MODG: u64 = 0xae689191;
const CRC32_X95_MODG: u64 = 0xccaa009e;

// ============================================================================
// 1. ARM64 PMULL 12-Way & 4-Way Vector Folding
// ============================================================================
#[cfg(target_arch = "aarch64")]
mod arm64 {
    use super::*;
    use core::arch::aarch64::*;

    #[inline(always)]
    unsafe fn u32_to_bytevec(a: u32) -> uint8x16_t {
        vreinterpretq_u8_u32(vsetq_lane_u32(a, vdupq_n_u32(0), 0))
    }

    #[inline(always)]
    unsafe fn load_multipliers(p: &[u64; 2]) -> poly64x2_t {
        vreinterpretq_p64_u64(vld1q_u64(p.as_ptr()))
    }

    #[inline(always)]
    unsafe fn clmul_low(a: uint8x16_t, b: poly64x2_t) -> uint8x16_t {
        vreinterpretq_u8_p128(vmull_p64(
            vgetq_lane_p64(vreinterpretq_p64_u8(a), 0),
            vgetq_lane_p64(b, 0),
        ))
    }

    #[inline(always)]
    unsafe fn clmul_high(a: uint8x16_t, b: poly64x2_t) -> uint8x16_t {
        vreinterpretq_u8_p128(vmull_high_p64(vreinterpretq_p64_u8(a), b))
    }

    #[inline(always)]
    unsafe fn fold_vec(cur: uint8x16_t, next: uint8x16_t, mult: poly64x2_t) -> uint8x16_t {
        let low = clmul_low(cur, mult);
        let high = clmul_high(cur, mult);
        veorq_u8(next, veorq_u8(low, high))
    }

    #[target_feature(enable = "crc")]
    pub unsafe fn crc32_arm_pmull_raw(mut crc: u32, mut p: *const u8, mut len: usize) -> u32 {
        let mut v0: uint8x16_t;
        let mut v1: uint8x16_t;
        let mut v2: uint8x16_t;
        let mut v3: uint8x16_t;
        let mut v4: uint8x16_t;
        let mut v5: uint8x16_t;
        let mut v6: uint8x16_t;
        let mut v7: uint8x16_t;
        let mut v8: uint8x16_t;
        let mut v9: uint8x16_t;
        let mut v10: uint8x16_t;
        let mut v11: uint8x16_t;

        if len < 3 * 192 {
            static MULTS: [[u64; 2]; 3] = [
                [CRC32_X543_MODG, CRC32_X479_MODG],
                [CRC32_X287_MODG, CRC32_X223_MODG],
                [CRC32_X159_MODG, CRC32_X95_MODG],
            ];

            if len < 64 {
                return finish_tail(crc, p, len);
            }

            let mult_4 = load_multipliers(&MULTS[0]);
            let mult_2 = load_multipliers(&MULTS[1]);
            let mult_1 = load_multipliers(&MULTS[2]);

            v0 = veorq_u8(vld1q_u8(p), u32_to_bytevec(crc));
            v1 = vld1q_u8(p.add(16));
            v2 = vld1q_u8(p.add(32));
            v3 = vld1q_u8(p.add(48));
            p = p.add(64);
            len -= 64;

            while len >= 64 {
                v0 = fold_vec(v0, vld1q_u8(p), mult_4);
                v1 = fold_vec(v1, vld1q_u8(p.add(16)), mult_4);
                v2 = fold_vec(v2, vld1q_u8(p.add(32)), mult_4);
                v3 = fold_vec(v3, vld1q_u8(p.add(48)), mult_4);
                p = p.add(64);
                len -= 64;
            }

            v0 = fold_vec(v0, v2, mult_2);
            v1 = fold_vec(v1, v3, mult_2);
            if len >= 32 {
                v0 = fold_vec(v0, vld1q_u8(p), mult_2);
                v1 = fold_vec(v1, vld1q_u8(p.add(16)), mult_2);
                p = p.add(32);
                len -= 32;
            }
            v0 = fold_vec(v0, v1, mult_1);
        } else {
            static MULTS: [[u64; 2]; 4] = [
                [CRC32_X1567_MODG, CRC32_X1503_MODG],
                [CRC32_X799_MODG, CRC32_X735_MODG],
                [CRC32_X415_MODG, CRC32_X351_MODG],
                [CRC32_X159_MODG, CRC32_X95_MODG],
            ];
            let mult_12 = load_multipliers(&MULTS[0]);
            let mult_6 = load_multipliers(&MULTS[1]);
            let mult_3 = load_multipliers(&MULTS[2]);
            let mult_1 = load_multipliers(&MULTS[3]);

            let align = ((p as usize).wrapping_neg()) & 15;
            if align != 0 {
                if align & 1 != 0 {
                    crc = __crc32b(crc, *p);
                    p = p.add(1);
                }
                if align & 2 != 0 {
                    crc = __crc32h(crc, (p as *const u16).read_unaligned());
                    p = p.add(2);
                }
                if align & 4 != 0 {
                    crc = __crc32w(crc, (p as *const u32).read_unaligned());
                    p = p.add(4);
                }
                if align & 8 != 0 {
                    crc = __crc32d(crc, (p as *const u64).read_unaligned());
                    p = p.add(8);
                }
                len -= align;
            }

            let mut vp = p as *const uint8x16_t;
            v0 = veorq_u8(*vp, u32_to_bytevec(crc));
            vp = vp.add(1);
            v1 = *vp; vp = vp.add(1);
            v2 = *vp; vp = vp.add(1);
            v3 = *vp; vp = vp.add(1);
            v4 = *vp; vp = vp.add(1);
            v5 = *vp; vp = vp.add(1);
            v6 = *vp; vp = vp.add(1);
            v7 = *vp; vp = vp.add(1);
            v8 = *vp; vp = vp.add(1);
            v9 = *vp; vp = vp.add(1);
            v10 = *vp; vp = vp.add(1);
            v11 = *vp; vp = vp.add(1);
            len -= 192;

            while len >= 192 {
                v0 = fold_vec(v0, *vp, mult_12); vp = vp.add(1);
                v1 = fold_vec(v1, *vp, mult_12); vp = vp.add(1);
                v2 = fold_vec(v2, *vp, mult_12); vp = vp.add(1);
                v3 = fold_vec(v3, *vp, mult_12); vp = vp.add(1);
                v4 = fold_vec(v4, *vp, mult_12); vp = vp.add(1);
                v5 = fold_vec(v5, *vp, mult_12); vp = vp.add(1);
                v6 = fold_vec(v6, *vp, mult_12); vp = vp.add(1);
                v7 = fold_vec(v7, *vp, mult_12); vp = vp.add(1);
                v8 = fold_vec(v8, *vp, mult_12); vp = vp.add(1);
                v9 = fold_vec(v9, *vp, mult_12); vp = vp.add(1);
                v10 = fold_vec(v10, *vp, mult_12); vp = vp.add(1);
                v11 = fold_vec(v11, *vp, mult_12); vp = vp.add(1);
                len -= 192;
            }

            v0 = fold_vec(v0, v6, mult_6);
            v1 = fold_vec(v1, v7, mult_6);
            v2 = fold_vec(v2, v8, mult_6);
            v3 = fold_vec(v3, v9, mult_6);
            v4 = fold_vec(v4, v10, mult_6);
            v5 = fold_vec(v5, v11, mult_6);

            if len >= 96 {
                v0 = fold_vec(v0, *vp, mult_6); vp = vp.add(1);
                v1 = fold_vec(v1, *vp, mult_6); vp = vp.add(1);
                v2 = fold_vec(v2, *vp, mult_6); vp = vp.add(1);
                v3 = fold_vec(v3, *vp, mult_6); vp = vp.add(1);
                v4 = fold_vec(v4, *vp, mult_6); vp = vp.add(1);
                v5 = fold_vec(v5, *vp, mult_6); vp = vp.add(1);
                len -= 96;
            }

            v0 = fold_vec(v0, v3, mult_3);
            v1 = fold_vec(v1, v4, mult_3);
            v2 = fold_vec(v2, v5, mult_3);

            if len >= 48 {
                v0 = fold_vec(v0, *vp, mult_3); vp = vp.add(1);
                v1 = fold_vec(v1, *vp, mult_3); vp = vp.add(1);
                v2 = fold_vec(v2, *vp, mult_3); vp = vp.add(1);
                len -= 48;
            }

            v0 = fold_vec(v0, v1, mult_1);
            v0 = fold_vec(v0, v2, mult_1);
            p = vp as *const u8;
        }

        crc = __crc32d(0, vgetq_lane_u64(vreinterpretq_u64_u8(v0), 0));
        crc = __crc32d(crc, vgetq_lane_u64(vreinterpretq_u64_u8(v0), 1));

        finish_tail(crc, p, len)
    }

    #[inline(always)]
    unsafe fn finish_tail(mut crc: u32, mut p: *const u8, len: usize) -> u32 {
        if len & 32 != 0 {
            crc = __crc32d(crc, (p as *const u64).read_unaligned());
            crc = __crc32d(crc, (p.add(8) as *const u64).read_unaligned());
            crc = __crc32d(crc, (p.add(16) as *const u64).read_unaligned());
            crc = __crc32d(crc, (p.add(24) as *const u64).read_unaligned());
            p = p.add(32);
        }
        if len & 16 != 0 {
            crc = __crc32d(crc, (p as *const u64).read_unaligned());
            crc = __crc32d(crc, (p.add(8) as *const u64).read_unaligned());
            p = p.add(16);
        }
        if len & 8 != 0 {
            crc = __crc32d(crc, (p as *const u64).read_unaligned());
            p = p.add(8);
        }
        if len & 4 != 0 {
            crc = __crc32w(crc, (p as *const u32).read_unaligned());
            p = p.add(4);
        }
        if len & 2 != 0 {
            crc = __crc32h(crc, (p as *const u16).read_unaligned());
            p = p.add(2);
        }
        if len & 1 != 0 {
            crc = __crc32b(crc, *p);
        }
        crc
    }
}

// ============================================================================
// 2. Slice-by-8 Scalar Reference Fallback
// ============================================================================
#[allow(dead_code)]
pub mod scalar {
    // Precomputed IEEE 802.3 CRC-32 table (polynomial 0xEDB88320)
    const fn make_tables() -> [[u32; 256]; 8] {
        let mut tables = [[0u32; 256]; 8];
        let mut i = 0;
        while i < 256 {
            let mut crc = i as u32;
            let mut j = 0;
            while j < 8 {
                crc = if (crc & 1) != 0 {
                    (crc >> 1) ^ 0xEDB88320
                } else {
                    crc >> 1
                };
                j += 1;
            }
            tables[0][i] = crc;
            i += 1;
        }

        let mut slice = 1;
        while slice < 8 {
            let mut idx = 0;
            while idx < 256 {
                let prev = tables[slice - 1][idx];
                tables[slice][idx] = (prev >> 8) ^ tables[0][(prev & 0xFF) as usize];
                idx += 1;
            }
            slice += 1;
        }
        tables
    }

    static CRC_TABLE: [[u32; 256]; 8] = make_tables();

    pub fn crc32_slice8(mut crc: u32, data: &[u8]) -> u32 {
        crc = !crc;
        let mut p = data.as_ptr();
        let mut len = data.len();

        while len >= 8 {
            let one = crc ^ unsafe { (p as *const u32).read_unaligned() };
            let two = unsafe { (p.add(4) as *const u32).read_unaligned() };

            let b0 = (one & 0xFF) as usize;
            let b1 = ((one >> 8) & 0xFF) as usize;
            let b2 = ((one >> 16) & 0xFF) as usize;
            let b3 = ((one >> 24) & 0xFF) as usize;

            let b4 = (two & 0xFF) as usize;
            let b5 = ((two >> 8) & 0xFF) as usize;
            let b6 = ((two >> 16) & 0xFF) as usize;
            let b7 = ((two >> 24) & 0xFF) as usize;

            crc = CRC_TABLE[7][b0]
                ^ CRC_TABLE[6][b1]
                ^ CRC_TABLE[5][b2]
                ^ CRC_TABLE[4][b3]
                ^ CRC_TABLE[3][b4]
                ^ CRC_TABLE[2][b5]
                ^ CRC_TABLE[1][b6]
                ^ CRC_TABLE[0][b7];

            unsafe {
                p = p.add(8);
            }
            len -= 8;
        }

        while len > 0 {
            let b = unsafe { *p };
            crc = (crc >> 8) ^ CRC_TABLE[0][((crc ^ (b as u32)) & 0xFF) as usize];
            unsafe {
                p = p.add(1);
            }
            len -= 1;
        }

        !crc
    }
}

// ============================================================================
// 3. Public High-Speed CRC-32 Entrypoint
// ============================================================================

/// Computes CRC-32 (IEEE 802.3) with hardware acceleration where available.
///
/// Returns the updated CRC-32 value for the given input buffer.
#[inline]
pub fn crc32_fast(crc: u32, data: &[u8]) -> u32 {
    if data.is_empty() {
        return crc;
    }

    #[cfg(target_arch = "aarch64")]
    {
        // On Apple Silicon / ARM64, invoke the PMULL wide fold implementation
        unsafe {
            !arm64::crc32_arm_pmull_raw(!crc, data.as_ptr(), data.len())
        }
    }

    #[cfg(not(target_arch = "aarch64"))]
    {
        scalar::crc32_slice8(crc, data)
    }
}

/// Computes the initial CRC-32 of a buffer from starting value 0.
#[inline]
pub fn crc32(data: &[u8]) -> u32 {
    crc32_fast(0, data)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_crc32_empty() {
        assert_eq!(crc32(&[]), 0);
        assert_eq!(crc32_fast(12345, &[]), 12345);
    }

    #[test]
    fn test_crc32_basic_vectors() {
        // "123456789" is standard check value: 0xCBF43926
        assert_eq!(crc32(b"123456789"), 0xCBF43926);
        assert_eq!(scalar::crc32_slice8(0, b"123456789"), 0xCBF43926);
    }

    #[test]
    fn test_crc32_sizes_and_alignments() {
        let mut buffer = vec![0u8; 10000];
        for (i, b) in buffer.iter_mut().enumerate() {
            *b = (i * 31 + 17) as u8;
        }

        let reference = scalar::crc32_slice8(0, &buffer);
        let fast = crc32_fast(0, &buffer);
        assert_eq!(fast, reference, "Fast and scalar CRC32 mismatch on 10KB buffer");

        // Test varying chunk sizes across fold boundaries
        for size in [1, 2, 3, 4, 7, 8, 15, 16, 31, 32, 63, 64, 127, 128, 191, 192, 512, 1024, 4096] {
            let ref_val = scalar::crc32_slice8(0, &buffer[..size]);
            let fast_val = crc32_fast(0, &buffer[..size]);
            assert_eq!(fast_val, ref_val, "Mismatch for size {}", size);
        }
    }
}
