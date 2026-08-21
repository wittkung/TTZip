// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! AES-256-CTR encryption and decryption pipeline.

use super::Aes256Context;

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
        super::simd::aes256_ctr_crypt_neon(
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
