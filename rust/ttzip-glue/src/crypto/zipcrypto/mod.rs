// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Traditional PKZIP 3-Key Stream Cipher implementation with hardware acceleration and Zeroize.

pub mod scalar;
pub mod simd;
#[cfg(test)]
pub mod tests;

use zeroize::{Zeroize, ZeroizeOnDrop};

pub use scalar::{
    crc32_byte, decrypt_byte_key, update_keys, ZIPCRYPTO_KEY0_INIT, ZIPCRYPTO_KEY1_INIT,
    ZIPCRYPTO_KEY2_INIT, ZIPCRYPTO_MULT,
};
pub use simd::{decrypt_stream_fast, encrypt_stream_fast, update_keys_fast, ZipCryptoBatch4};

/// 3-Key state for the traditional PKZIP stream cipher (`key0`, `key1`, `key2`).
///
/// Automatically zeroes secret key state out of memory when dropped.
#[repr(C)]
#[derive(Clone, PartialEq, Eq, Zeroize, ZeroizeOnDrop)]
pub struct ZipCryptoKeys {
    pub key0: u32,
    pub key1: u32,
    pub key2: u32,
}

impl core::fmt::Debug for ZipCryptoKeys {
    fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        f.debug_struct("ZipCryptoKeys")
            .field("key0", &"[REDACTED]")
            .field("key1", &"[REDACTED]")
            .field("key2", &"[REDACTED]")
            .finish()
    }
}

impl Default for ZipCryptoKeys {
    #[inline]
    fn default() -> Self {
        Self {
            key0: ZIPCRYPTO_KEY0_INIT,
            key1: ZIPCRYPTO_KEY1_INIT,
            key2: ZIPCRYPTO_KEY2_INIT,
        }
    }
}

impl ZipCryptoKeys {
    /// Creates a new uninitialized `ZipCryptoKeys` structure with standard initial constants.
    #[inline]
    pub fn new() -> Self {
        Self::default()
    }

    /// Initializes cipher keys from a password byte slice.
    pub fn from_password(password: &[u8]) -> Self {
        let mut keys = Self::default();
        keys.init_with_password(password);
        keys
    }

    /// Updates current key state with the password bytes.
    #[inline]
    pub fn init_with_password(&mut self, password: &[u8]) {
        for &b in password {
            self.update(b);
        }
    }

    /// Updates internal key states using the provided plaintext byte.
    #[inline(always)]
    pub fn update(&mut self, plain_byte: u8) {
        update_keys_fast(&mut self.key0, &mut self.key1, &mut self.key2, plain_byte);
    }

    /// Returns the current keystream byte.
    #[inline(always)]
    pub fn keystream_byte(&self) -> u8 {
        decrypt_byte_key(self.key2)
    }

    /// Decrypts a single byte and advances the internal key state.
    #[inline(always)]
    pub fn decrypt_byte(&mut self, cipher_byte: u8) -> u8 {
        let k = self.keystream_byte();
        let plain = cipher_byte ^ k;
        self.update(plain);
        plain
    }

    /// Encrypts a single byte and advances the internal key state.
    #[inline(always)]
    pub fn encrypt_byte(&mut self, plain_byte: u8) -> u8 {
        let k = self.keystream_byte();
        let cipher = plain_byte ^ k;
        self.update(plain_byte);
        cipher
    }

    /// Decrypts a slice of bytes in place.
    #[inline]
    pub fn decrypt_slice(&mut self, data: &mut [u8]) {
        decrypt_stream_fast(&mut self.key0, &mut self.key1, &mut self.key2, data);
    }

    /// Encrypts a slice of bytes in place.
    #[inline]
    pub fn encrypt_slice(&mut self, data: &mut [u8]) {
        encrypt_stream_fast(&mut self.key0, &mut self.key1, &mut self.key2, data);
    }

    /// Decrypts source buffer into destination buffer.
    #[inline]
    pub fn decrypt_copy(&mut self, src: &[u8], dst: &mut [u8]) {
        let len = src.len().min(dst.len());
        dst[..len].copy_from_slice(&src[..len]);
        self.decrypt_slice(&mut dst[..len]);
    }

    /// Encrypts source buffer into destination buffer.
    #[inline]
    pub fn encrypt_copy(&mut self, src: &[u8], dst: &mut [u8]) {
        let len = src.len().min(dst.len());
        dst[..len].copy_from_slice(&src[..len]);
        self.encrypt_slice(&mut dst[..len]);
    }
}

/// Convenience helper to decrypt a slice given a password.
pub fn zipcrypto_decrypt_slice(password: &[u8], data: &mut [u8]) {
    let mut keys = ZipCryptoKeys::from_password(password);
    keys.decrypt_slice(data);
}

/// Convenience helper to encrypt a slice given a password.
pub fn zipcrypto_encrypt_slice(password: &[u8], data: &mut [u8]) {
    let mut keys = ZipCryptoKeys::from_password(password);
    keys.encrypt_slice(data);
}
