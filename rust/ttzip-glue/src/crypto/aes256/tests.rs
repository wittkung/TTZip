// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

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
