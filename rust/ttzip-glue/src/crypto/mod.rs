// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Hardware-accelerated cryptographic primitives and checksum routines.

pub mod adler32;
pub mod aes256;
pub mod crc32;
pub mod sha1;
pub mod sha256;

pub use adler32::{adler32, adler32_fast};
pub use aes256::{aes256_cbc_decrypt, aes256_cbc_encrypt, aes256_ctr_crypt, Aes256Context};
pub use crc32::{crc32, crc32_fast};
pub use sha1::{
    hmac_sha1, hmac_sha1_10, pbkdf2_sha1, sha1, winzip_aes256_decrypt_and_verify,
    winzip_aes256_derive_keys, winzip_aes256_encrypt_and_tag, FastSha1, WinZipAes256Keys,
};
pub use sha256::{sha256_7z_kdf, FastSha256};
