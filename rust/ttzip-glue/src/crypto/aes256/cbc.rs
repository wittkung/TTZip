// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! AES-256-CBC encryption and decryption routines.

use super::Aes256Context;

/// Performs AES-256-CBC decryption. Length must be a multiple of 16.
pub fn aes256_cbc_decrypt(
    key: &[u8; 32],
    iv: &[u8; 16],
    src: &[u8],
    dst: &mut [u8],
) -> Result<(), &'static str> {
    if !src.len().is_multiple_of(16) {
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
        super::simd::aes256_cbc_decrypt_neon(
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
    if !src.len().is_multiple_of(16) {
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
        super::simd::aes256_cbc_encrypt_neon(
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
