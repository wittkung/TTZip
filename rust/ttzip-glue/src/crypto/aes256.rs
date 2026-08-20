// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Hardware-accelerated AES-256 engine.
//!
//! Provides ARM64 NEON Crypto 8-way interleaved pipelined AES-256-CTR and AES-256-CBC
//! operations (128 bytes/loop), zeroized memory cleanup, and standard fallbacks.

use zeroize::{Zeroize, ZeroizeOnDrop};

static RCON: [u8; 15] = [
    0x00, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1B, 0x36, 0x6C, 0xD8, 0xAB, 0x4D,
];

static SBOX: [u8; 256] = [
    0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b, 0xfe, 0xd7, 0xab, 0x76,
    0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0, 0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0,
    0xb7, 0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15,
    0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80, 0xe2, 0xeb, 0x27, 0xb2, 0x75,
    0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0, 0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84,
    0x53, 0xd1, 0x00, 0xed, 0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf,
    0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f, 0x50, 0x3c, 0x9f, 0xa8,
    0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5, 0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2,
    0xcd, 0x0c, 0x13, 0xec, 0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73,
    0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8, 0x14, 0xde, 0x5e, 0x0b, 0xdb,
    0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5c, 0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79,
    0xe7, 0xc8, 0x37, 0x6d, 0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08,
    0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f, 0x4b, 0xbd, 0x8b, 0x8a,
    0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e,
    0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf,
    0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f, 0xb0, 0x54, 0xbb, 0x16,
];

#[inline(always)]
fn sub_word(w: u32) -> u32 {
    (SBOX[(w & 0xFF) as usize] as u32)
        | ((SBOX[((w >> 8) & 0xFF) as usize] as u32) << 8)
        | ((SBOX[((w >> 16) & 0xFF) as usize] as u32) << 16)
        | ((SBOX[((w >> 24) & 0xFF) as usize] as u32) << 24)
}

#[inline(always)]
fn rot_word(w: u32) -> u32 {
    (w >> 8) | (w << 24)
}

/// AES-256 Context holding expanded round keys for encryption and decryption.
#[derive(Clone, Zeroize, ZeroizeOnDrop)]
pub struct Aes256Context {
    pub key: [u8; 32],
    pub round_keys_enc: [[u8; 16]; 15],
    pub round_keys_dec: [[u8; 16]; 15],
}

impl Aes256Context {
    /// Creates and expands round keys from a 256-bit key.
    pub fn new(key: &[u8; 32]) -> Self {
        let mut ctx = Self {
            key: *key,
            round_keys_enc: [[0u8; 16]; 15],
            round_keys_dec: [[0u8; 16]; 15],
        };
        ctx.expand_keys();
        ctx
    }

    fn expand_keys(&mut self) {
        let mut w = [0u32; 60];
        for i in 0..8 {
            w[i] = (self.key[i * 4] as u32)
                | ((self.key[i * 4 + 1] as u32) << 8)
                | ((self.key[i * 4 + 2] as u32) << 16)
                | ((self.key[i * 4 + 3] as u32) << 24);
        }

        for i in 8..60 {
            let mut temp = w[i - 1];
            if i % 8 == 0 {
                temp = sub_word(rot_word(temp)) ^ (RCON[i / 8] as u32);
            } else if i % 8 == 4 {
                temp = sub_word(temp);
            }
            w[i] = w[i - 8] ^ temp;
        }

        for i in 0..15 {
            let rk_u32 = [w[i * 4], w[i * 4 + 1], w[i * 4 + 2], w[i * 4 + 3]];
            for j in 0..4 {
                self.round_keys_enc[i][j * 4] = (rk_u32[j] & 0xFF) as u8;
                self.round_keys_enc[i][j * 4 + 1] = ((rk_u32[j] >> 8) & 0xFF) as u8;
                self.round_keys_enc[i][j * 4 + 2] = ((rk_u32[j] >> 16) & 0xFF) as u8;
                self.round_keys_enc[i][j * 4 + 3] = ((rk_u32[j] >> 24) & 0xFF) as u8;
            }
        }

        w.zeroize();

        // Generate Decryption Round Keys
        #[cfg(target_arch = "aarch64")]
        {
            use core::arch::aarch64::*;
            unsafe {
                self.round_keys_dec[0] = self.round_keys_enc[14];
                for r in 1..14 {
                    let rk = vld1q_u8(self.round_keys_enc[14 - r].as_ptr());
                    let rk_dec = vaesimcq_u8(rk);
                    vst1q_u8(self.round_keys_dec[r].as_mut_ptr(), rk_dec);
                }
                self.round_keys_dec[14] = self.round_keys_enc[0];
            }
        }

        #[cfg(not(target_arch = "aarch64"))]
        {
            self.round_keys_dec = self.round_keys_enc;
        }
    }
}

// ============================================================================
// ARM64 Hardware Pipelined AES Implementations
// ============================================================================
#[cfg(target_arch = "aarch64")]
pub mod arm64 {
    use super::*;
    use core::arch::aarch64::*;

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
}

// ============================================================================
// Public Safe Wrappers
// ============================================================================

/// Performs AES-256-CTR encryption or decryption (CTR mode is symmetric).
pub fn aes256_ctr_crypt(
    key: &[u8; 32],
    initial_counter: u64,
    src: &[u8],
    dst: &mut [u8],
) -> Result<(), &'static str> {
    if src.len() > dst.len() {
        return Err("Destination buffer too small");
    }
    if src.is_empty() {
        return Ok(());
    }

    let ctx = Aes256Context::new(key);

    #[cfg(target_arch = "aarch64")]
    unsafe {
        arm64::aes256_ctr_crypt_neon(
            &ctx,
            initial_counter,
            src.as_ptr(),
            src.len(),
            dst.as_mut_ptr(),
        );
        Ok(())
    }

    #[cfg(not(target_arch = "aarch64"))]
    {
        use aes::cipher::{KeyIvInit, StreamCipher};
        type Aes256Ctr128BE = ctr::Ctr128BE<aes::Aes256>;
        let mut iv = [0u8; 16];
        iv[..8].copy_from_slice(&initial_counter.to_le_bytes());
        let mut cipher = Aes256Ctr128BE::new(key.into(), &iv.into());
        dst[..src.len()].copy_from_slice(src);
        cipher.apply_keystream(&mut dst[..src.len()]);
        Ok(())
    }
}

/// Performs AES-256-CBC decryption. Length must be a multiple of 16.
pub fn aes256_cbc_decrypt(
    key: &[u8; 32],
    iv: &[u8; 16],
    src: &[u8],
    dst: &mut [u8],
) -> Result<(), &'static str> {
    if src.len() % 16 != 0 {
        return Err("Input length must be a multiple of 16 bytes for CBC mode");
    }
    if src.len() > dst.len() {
        return Err("Destination buffer too small");
    }
    if src.is_empty() {
        return Ok(());
    }

    let ctx = Aes256Context::new(key);

    #[cfg(target_arch = "aarch64")]
    unsafe {
        arm64::aes256_cbc_decrypt_neon(
            &ctx,
            iv,
            src.as_ptr(),
            src.len(),
            dst.as_mut_ptr(),
        );
        Ok(())
    }

    #[cfg(not(target_arch = "aarch64"))]
    {
        use aes::cipher::{BlockDecryptMut, KeyIvInit};
        type Aes256CbcDec = cbc::Decryptor<aes::Aes256>;
        let decryptor = Aes256CbcDec::new(key.into(), iv.into());
        dst[..src.len()].copy_from_slice(src);
        for chunk in dst[..src.len()].chunks_exact_mut(16) {
            let block = aes::cipher::generic_array::GenericArray::from_mut_slice(chunk);
            decryptor.clone().decrypt_block_mut(block);
        }
        Ok(())
    }
}

/// Performs AES-256-CBC encryption. Length must be a multiple of 16.
pub fn aes256_cbc_encrypt(
    key: &[u8; 32],
    iv: &[u8; 16],
    src: &[u8],
    dst: &mut [u8],
) -> Result<(), &'static str> {
    if src.len() % 16 != 0 {
        return Err("Input length must be a multiple of 16 bytes for CBC mode");
    }
    if src.len() > dst.len() {
        return Err("Destination buffer too small");
    }
    if src.is_empty() {
        return Ok(());
    }

    let ctx = Aes256Context::new(key);

    #[cfg(target_arch = "aarch64")]
    unsafe {
        arm64::aes256_cbc_encrypt_neon(
            &ctx,
            iv,
            src.as_ptr(),
            src.len(),
            dst.as_mut_ptr(),
        );
        Ok(())
    }

    #[cfg(not(target_arch = "aarch64"))]
    {
        use aes::cipher::{BlockEncryptMut, KeyIvInit};
        type Aes256CbcEnc = cbc::Encryptor<aes::Aes256>;
        let encryptor = Aes256CbcEnc::new(key.into(), iv.into());
        dst[..src.len()].copy_from_slice(src);
        for chunk in dst[..src.len()].chunks_exact_mut(16) {
            let block = aes::cipher::generic_array::GenericArray::from_mut_slice(chunk);
            encryptor.clone().encrypt_block_mut(block);
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_aes256_cbc_roundtrip() {
        let key = [0x2bu8; 32];
        let iv = [0x1au8; 16];
        let mut plaintext = vec![0u8; 256];
        for (i, b) in plaintext.iter_mut().enumerate() {
            *b = (i * 7 + 3) as u8;
        }

        let mut ciphertext = vec![0u8; 256];
        let mut decrypted = vec![0u8; 256];

        aes256_cbc_encrypt(&key, &iv, &plaintext, &mut ciphertext).unwrap();
        assert_ne!(plaintext, ciphertext);

        aes256_cbc_decrypt(&key, &iv, &ciphertext, &mut decrypted).unwrap();
        assert_eq!(plaintext, decrypted);
    }

    #[test]
    fn test_aes256_ctr_roundtrip() {
        let key = [0x5au8; 32];
        let counter = 100u64;
        let mut plaintext = vec![0u8; 300]; // not aligned to 16/128
        for (i, b) in plaintext.iter_mut().enumerate() {
            *b = (i ^ 0xAA) as u8;
        }

        let mut ciphertext = vec![0u8; 300];
        let mut decrypted = vec![0u8; 300];

        aes256_ctr_crypt(&key, counter, &plaintext, &mut ciphertext).unwrap();
        assert_ne!(plaintext, ciphertext);

        aes256_ctr_crypt(&key, counter, &ciphertext, &mut decrypted).unwrap();
        assert_eq!(plaintext, decrypted);
    }
}
