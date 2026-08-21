// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

use super::*;
use crate::types::TTZipStatus;

#[test]
fn test_sha1_nist_vectors() {
    // "abc"
    let hash = sha1(b"abc");
    assert_eq!(
        hex::encode(hash),
        "a9993e364706816aba3e25717850c26c9cd0d89d"
    );

    // "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
    let hash2 = sha1(b"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq");
    assert_eq!(
        hex::encode(hash2),
        "84983e441c3bd26ebaae4aa1f95129e5e54670f1"
    );
}

#[test]
fn test_hmac_sha1_rfc2202() {
    let key = [0x0bu8; 20];
    let data = b"Hi There";
    let mac = hmac_sha1(&key, data);
    assert_eq!(
        hex::encode(mac),
        "b617318655057264e28bc0b6fb378c8ef146be00"
    );
}

#[test]
fn test_pbkdf2_sha1_rfc6070() {
    let password = b"password";
    let salt = b"salt";
    let mut key = [0u8; 20];
    pbkdf2_sha1(password, salt, 1, &mut key).unwrap();
    assert_eq!(
        hex::encode(key),
        "0c60c80f961f0e71f3a9b524af6012062fe037a6"
    );

    pbkdf2_sha1(password, salt, 2, &mut key).unwrap();
    assert_eq!(
        hex::encode(key),
        "ea6c014dc72d6f8ccd1ed92ace1d41f0d8de8957"
    );
}

#[test]
fn test_winzip_aes256_roundtrip() {
    let password = "SecretPassword123!";
    let salt = [0x55u8; 16];
    let plaintext = b"Hello WinZip AES-256 Hardware Encrypted Stream! Testing 1234567890.";

    let mut payload = Vec::new();
    winzip_aes256_encrypt_and_tag(password, &salt, plaintext, &mut payload).unwrap();
    assert_eq!(payload.len(), 16 + 2 + plaintext.len() + 10);

    let mut decrypted = vec![0u8; plaintext.len()];
    let dec_len = winzip_aes256_decrypt_and_verify(password, &payload, &mut decrypted).unwrap();
    assert_eq!(dec_len, plaintext.len());
    assert_eq!(&decrypted, plaintext);

    // Wrong password check
    let err = winzip_aes256_decrypt_and_verify("WrongPassword", &payload, &mut decrypted);
    assert_eq!(err, Err(TTZipStatus::ErrInvalidPassword));
}
