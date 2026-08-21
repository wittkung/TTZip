// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! ARM64 NEON Hardware Pipelined AES-256 Implementations.

#[cfg(target_arch = "aarch64")]
use super::Aes256Context;
#[cfg(target_arch = "aarch64")]
use core::arch::aarch64::*;

#[cfg(target_arch = "aarch64")]
#[target_feature(enable = "aes")]
pub unsafe fn aes256_ctr_crypt_neon(
    ctx: &Aes256Context,
    initial_counter: u64,
    src: *const u8,
    len: usize,
    dst: *mut u8,
) {
    let mut rk = [vdupq_n_u8(0); 15];
    for i in 0..15 {
        rk[i] = vld1q_u8(ctx.round_keys_enc[i].as_ptr());
    }

    let num_blocks = (len + 15) / 16;
    let mut i = 0;

    while i + 8 <= num_blocks {
        let c0 = initial_counter + (i as u64) + 0;
        let c1 = initial_counter + (i as u64) + 1;
        let c2 = initial_counter + (i as u64) + 2;
        let c3 = initial_counter + (i as u64) + 3;
        let c4 = initial_counter + (i as u64) + 4;
        let c5 = initial_counter + (i as u64) + 5;
        let c6 = initial_counter + (i as u64) + 6;
        let c7 = initial_counter + (i as u64) + 7;

        let ctr0: [u64; 2] = [c0, 0];
        let ctr1: [u64; 2] = [c1, 0];
        let ctr2: [u64; 2] = [c2, 0];
        let ctr3: [u64; 2] = [c3, 0];
        let ctr4: [u64; 2] = [c4, 0];
        let ctr5: [u64; 2] = [c5, 0];
        let ctr6: [u64; 2] = [c6, 0];
        let ctr7: [u64; 2] = [c7, 0];

        let mut b0 = vld1q_u8(ctr0.as_ptr() as *const u8);
        let mut b1 = vld1q_u8(ctr1.as_ptr() as *const u8);
        let mut b2 = vld1q_u8(ctr2.as_ptr() as *const u8);
        let mut b3 = vld1q_u8(ctr3.as_ptr() as *const u8);
        let mut b4 = vld1q_u8(ctr4.as_ptr() as *const u8);
        let mut b5 = vld1q_u8(ctr5.as_ptr() as *const u8);
        let mut b6 = vld1q_u8(ctr6.as_ptr() as *const u8);
        let mut b7 = vld1q_u8(ctr7.as_ptr() as *const u8);

        for r in 0..13 {
            b0 = vaesmcq_u8(vaeseq_u8(b0, rk[r]));
            b1 = vaesmcq_u8(vaeseq_u8(b1, rk[r]));
            b2 = vaesmcq_u8(vaeseq_u8(b2, rk[r]));
            b3 = vaesmcq_u8(vaeseq_u8(b3, rk[r]));
            b4 = vaesmcq_u8(vaeseq_u8(b4, rk[r]));
            b5 = vaesmcq_u8(vaeseq_u8(b5, rk[r]));
            b6 = vaesmcq_u8(vaeseq_u8(b6, rk[r]));
            b7 = vaesmcq_u8(vaeseq_u8(b7, rk[r]));
        }

        b0 = veorq_u8(vaeseq_u8(b0, rk[13]), rk[14]);
        b1 = veorq_u8(vaeseq_u8(b1, rk[13]), rk[14]);
        b2 = veorq_u8(vaeseq_u8(b2, rk[13]), rk[14]);
        b3 = veorq_u8(vaeseq_u8(b3, rk[13]), rk[14]);
        b4 = veorq_u8(vaeseq_u8(b4, rk[13]), rk[14]);
        b5 = veorq_u8(vaeseq_u8(b5, rk[13]), rk[14]);
        b6 = veorq_u8(vaeseq_u8(b6, rk[13]), rk[14]);
        b7 = veorq_u8(vaeseq_u8(b7, rk[13]), rk[14]);

        let block_offset = i * 16;
        let rem = if block_offset + 128 <= len {
            128
        } else {
            len - block_offset
        };

        if rem == 128 {
            let s0 = vld1q_u8(src.add(block_offset));
            let s1 = vld1q_u8(src.add(block_offset + 16));
            let s2 = vld1q_u8(src.add(block_offset + 32));
            let s3 = vld1q_u8(src.add(block_offset + 48));
            let s4 = vld1q_u8(src.add(block_offset + 64));
            let s5 = vld1q_u8(src.add(block_offset + 80));
            let s6 = vld1q_u8(src.add(block_offset + 96));
            let s7 = vld1q_u8(src.add(block_offset + 112));

            vst1q_u8(dst.add(block_offset), veorq_u8(s0, b0));
            vst1q_u8(dst.add(block_offset + 16), veorq_u8(s1, b1));
            vst1q_u8(dst.add(block_offset + 32), veorq_u8(s2, b2));
            vst1q_u8(dst.add(block_offset + 48), veorq_u8(s3, b3));
            vst1q_u8(dst.add(block_offset + 64), veorq_u8(s4, b4));
            vst1q_u8(dst.add(block_offset + 80), veorq_u8(s5, b5));
            vst1q_u8(dst.add(block_offset + 96), veorq_u8(s6, b6));
            vst1q_u8(dst.add(block_offset + 112), veorq_u8(s7, b7));
        } else {
            let mut ks = [0u8; 128];
            vst1q_u8(ks.as_mut_ptr(), b0);
            vst1q_u8(ks.as_mut_ptr().add(16), b1);
            vst1q_u8(ks.as_mut_ptr().add(32), b2);
            vst1q_u8(ks.as_mut_ptr().add(48), b3);
            vst1q_u8(ks.as_mut_ptr().add(64), b4);
            vst1q_u8(ks.as_mut_ptr().add(80), b5);
            vst1q_u8(ks.as_mut_ptr().add(96), b6);
            vst1q_u8(ks.as_mut_ptr().add(112), b7);
            for k in 0..rem {
                *dst.add(block_offset + k) = *src.add(block_offset + k) ^ ks[k];
            }
        }

        i += 8;
    }

    while i < num_blocks {
        let c0 = initial_counter + (i as u64);
        let ctr0: [u64; 2] = [c0, 0];
        let mut b0 = vld1q_u8(ctr0.as_ptr() as *const u8);
        for r in 0..13 {
            b0 = vaesmcq_u8(vaeseq_u8(b0, rk[r]));
        }
        b0 = veorq_u8(vaeseq_u8(b0, rk[13]), rk[14]);

        let block_offset = i * 16;
        let rem = if block_offset + 16 <= len {
            16
        } else {
            len - block_offset
        };

        if rem == 16 {
            let s0 = vld1q_u8(src.add(block_offset));
            vst1q_u8(dst.add(block_offset), veorq_u8(s0, b0));
        } else {
            let mut ks = [0u8; 16];
            vst1q_u8(ks.as_mut_ptr(), b0);
            for k in 0..rem {
                *dst.add(block_offset + k) = *src.add(block_offset + k) ^ ks[k];
            }
        }

        i += 1;
    }
}

#[cfg(target_arch = "aarch64")]
#[target_feature(enable = "aes")]
pub unsafe fn aes256_cbc_decrypt_neon(
    ctx: &Aes256Context,
    iv: &[u8; 16],
    src: *const u8,
    len: usize,
    dst: *mut u8,
) {
    let mut rk_dec = [vdupq_n_u8(0); 15];
    for i in 0..15 {
        rk_dec[i] = vld1q_u8(ctx.round_keys_dec[i].as_ptr());
    }

    let num_blocks = len / 16;
    let mut current_iv = vld1q_u8(iv.as_ptr());
    let mut i = 0;

    while i + 8 <= num_blocks {
        let offset = i * 16;
        let c0 = vld1q_u8(src.add(offset));
        let c1 = vld1q_u8(src.add(offset + 16));
        let c2 = vld1q_u8(src.add(offset + 32));
        let c3 = vld1q_u8(src.add(offset + 48));
        let c4 = vld1q_u8(src.add(offset + 64));
        let c5 = vld1q_u8(src.add(offset + 80));
        let c6 = vld1q_u8(src.add(offset + 96));
        let c7 = vld1q_u8(src.add(offset + 112));

        let mut b0 = c0;
        let mut b1 = c1;
        let mut b2 = c2;
        let mut b3 = c3;
        let mut b4 = c4;
        let mut b5 = c5;
        let mut b6 = c6;
        let mut b7 = c7;

        for r in 0..13 {
            b0 = vaesimcq_u8(vaesdq_u8(b0, rk_dec[r]));
            b1 = vaesimcq_u8(vaesdq_u8(b1, rk_dec[r]));
            b2 = vaesimcq_u8(vaesdq_u8(b2, rk_dec[r]));
            b3 = vaesimcq_u8(vaesdq_u8(b3, rk_dec[r]));
            b4 = vaesimcq_u8(vaesdq_u8(b4, rk_dec[r]));
            b5 = vaesimcq_u8(vaesdq_u8(b5, rk_dec[r]));
            b6 = vaesimcq_u8(vaesdq_u8(b6, rk_dec[r]));
            b7 = vaesimcq_u8(vaesdq_u8(b7, rk_dec[r]));
        }

        b0 = veorq_u8(vaesdq_u8(b0, rk_dec[13]), rk_dec[14]);
        b1 = veorq_u8(vaesdq_u8(b1, rk_dec[13]), rk_dec[14]);
        b2 = veorq_u8(vaesdq_u8(b2, rk_dec[13]), rk_dec[14]);
        b3 = veorq_u8(vaesdq_u8(b3, rk_dec[13]), rk_dec[14]);
        b4 = veorq_u8(vaesdq_u8(b4, rk_dec[13]), rk_dec[14]);
        b5 = veorq_u8(vaesdq_u8(b5, rk_dec[13]), rk_dec[14]);
        b6 = veorq_u8(vaesdq_u8(b6, rk_dec[13]), rk_dec[14]);
        b7 = veorq_u8(vaesdq_u8(b7, rk_dec[13]), rk_dec[14]);

        let p0 = veorq_u8(b0, current_iv);
        let p1 = veorq_u8(b1, c0);
        let p2 = veorq_u8(b2, c1);
        let p3 = veorq_u8(b3, c2);
        let p4 = veorq_u8(b4, c3);
        let p5 = veorq_u8(b5, c4);
        let p6 = veorq_u8(b6, c5);
        let p7 = veorq_u8(b7, c6);

        current_iv = c7;

        vst1q_u8(dst.add(offset), p0);
        vst1q_u8(dst.add(offset + 16), p1);
        vst1q_u8(dst.add(offset + 32), p2);
        vst1q_u8(dst.add(offset + 48), p3);
        vst1q_u8(dst.add(offset + 64), p4);
        vst1q_u8(dst.add(offset + 80), p5);
        vst1q_u8(dst.add(offset + 96), p6);
        vst1q_u8(dst.add(offset + 112), p7);

        i += 8;
    }

    while i < num_blocks {
        let offset = i * 16;
        let c = vld1q_u8(src.add(offset));
        let mut b = c;
        for r in 0..13 {
            b = vaesimcq_u8(vaesdq_u8(b, rk_dec[r]));
        }
        b = veorq_u8(vaesdq_u8(b, rk_dec[13]), rk_dec[14]);
        let p = veorq_u8(b, current_iv);
        current_iv = c;
        vst1q_u8(dst.add(offset), p);
        i += 1;
    }
}

#[cfg(target_arch = "aarch64")]
#[target_feature(enable = "aes")]
pub unsafe fn aes256_cbc_encrypt_neon(
    ctx: &Aes256Context,
    iv: &[u8; 16],
    src: *const u8,
    len: usize,
    dst: *mut u8,
) {
    let mut rk_enc = [vdupq_n_u8(0); 15];
    for i in 0..15 {
        rk_enc[i] = vld1q_u8(ctx.round_keys_enc[i].as_ptr());
    }

    let num_blocks = len / 16;
    let mut current_iv = vld1q_u8(iv.as_ptr());

    for i in 0..num_blocks {
        let offset = i * 16;
        let p = vld1q_u8(src.add(offset));
        let mut b = veorq_u8(p, current_iv);
        for r in 0..13 {
            b = vaesmcq_u8(vaeseq_u8(b, rk_enc[r]));
        }
        b = veorq_u8(vaeseq_u8(b, rk_enc[13]), rk_enc[14]);
        current_iv = b;
        vst1q_u8(dst.add(offset), b);
    }
}
