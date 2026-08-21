// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Integration tests for Secure Password Vault with AES-256-GCM and Zeroize Compiler Fence.

use ttzip_glue::crypto::vault::{
    aes256_gcm_decrypt, aes256_gcm_encrypt, secure_wipe,
};
use ttzip_glue::ffi::{
    ttzip_rust_vault_decrypt_key, ttzip_rust_vault_encrypt_key, ttzip_rust_vault_wipe,
};
use ttzip_glue::types::TTZipStatus;

#[test]
fn test_vault_nist_sp800_38d_vectors() {
    // NIST Case 1
    let key = [0u8; 32];
    let iv = [0u8; 12];
    let plaintext = [];
    let aad = [];
    let mut ciphertext = [];
    let mut tag = [0u8; 16];

    aes256_gcm_encrypt(&key, &iv, &plaintext, &aad, &mut ciphertext, &mut tag).unwrap();
    assert_eq!(hex::encode(tag), "530f8afbc74536b9a963b4f1c4cb738b");

    let mut decrypted = [];
    aes256_gcm_decrypt(&key, &iv, &ciphertext, &aad, &tag, &mut decrypted).unwrap();

    // NIST Case 2
    let plaintext2 = [0u8; 16];
    let mut ciphertext2 = [0u8; 16];
    let mut tag2 = [0u8; 16];
    aes256_gcm_encrypt(&key, &iv, &plaintext2, &aad, &mut ciphertext2, &mut tag2).unwrap();
    assert_eq!(hex::encode(ciphertext2), "cea7403d4d606b6e074ec5d3baf39d18");
    assert_eq!(hex::encode(tag2), "d0d1c8a799996bf0265b98b5d48ab919");

    let mut decrypted2 = [0u8; 16];
    aes256_gcm_decrypt(&key, &iv, &ciphertext2, &aad, &tag2, &mut decrypted2).unwrap();
    assert_eq!(decrypted2, plaintext2);

    // NIST Case 4 (20 bytes PT and AAD)
    let plaintext4 = hex::decode("feedfacedeadbeeffeedfacedeadbeefabaddad2").unwrap();
    let aad4 = hex::decode("feedfacedeadbeeffeedfacedeadbeefabaddad2").unwrap();
    let mut ciphertext4 = vec![0u8; plaintext4.len()];
    let mut tag4 = [0u8; 16];

    aes256_gcm_encrypt(&key, &iv, &plaintext4, &aad4, &mut ciphertext4, &mut tag4).unwrap();
    assert_eq!(hex::encode(&ciphertext4), "304abaf393cdd581f9a33f1d645e23f7d9cdd918");
    assert_eq!(hex::encode(tag4), "f069c0aeba01aebf0ea702b3b61a6ba1");

    let mut decrypted4 = vec![0u8; ciphertext4.len()];
    aes256_gcm_decrypt(&key, &iv, &ciphertext4, &aad4, &tag4, &mut decrypted4).unwrap();
    assert_eq!(decrypted4, plaintext4);
}

#[test]
fn test_vault_ffi_c_abi_roundtrip_and_wipe() {
    let key = [0x55u8; 32];
    let iv = [0xAAu8; 12];
    let secret = b"UserMasterPasswordKeyMaterial_2026";
    let mut cipher = vec![0u8; secret.len()];
    let mut tag = [0u8; 16];

    unsafe {
        let status = ttzip_rust_vault_encrypt_key(
            key.as_ptr(),
            iv.as_ptr(),
            secret.as_ptr(),
            secret.len(),
            std::ptr::null(),
            0,
            cipher.as_mut_ptr(),
            tag.as_mut_ptr(),
        );
        assert_eq!(status, TTZipStatus::Ok);

        let mut decrypted = vec![0u8; cipher.len()];
        let status_dec = ttzip_rust_vault_decrypt_key(
            key.as_ptr(),
            iv.as_ptr(),
            cipher.as_ptr(),
            cipher.len(),
            std::ptr::null(),
            0,
            tag.as_ptr(),
            decrypted.as_mut_ptr(),
        );
        assert_eq!(status_dec, TTZipStatus::Ok);
        assert_eq!(&decrypted[..], &secret[..]);

        // Wipe memory
        ttzip_rust_vault_wipe(decrypted.as_mut_ptr(), decrypted.len());
        assert!(decrypted.iter().all(|&b| b == 0));
    }
}

#[test]
fn test_vault_tampered_tag_and_sanitization() {
    let key = [0x12u8; 32];
    let iv = [0x34u8; 12];
    let plaintext = b"Sensitive Vault Content";
    let mut cipher = vec![0u8; plaintext.len()];
    let mut tag = [0u8; 16];

    aes256_gcm_encrypt(&key, &iv, plaintext, &[], &mut cipher, &mut tag).unwrap();

    // Tamper with tag
    tag[15] ^= 0x01;
    let mut decrypted = vec![0xEEu8; cipher.len()];
    let err = aes256_gcm_decrypt(&key, &iv, &cipher, &[], &tag, &mut decrypted);
    assert_eq!(err, Err(TTZipStatus::ErrInvalidPassword));
    assert!(decrypted.iter().all(|&b| b == 0)); // Verified sanitized

    let mut sensitive = [0xFFu8; 64];
    secure_wipe(sensitive.as_mut_ptr(), sensitive.len());
    assert_eq!(sensitive, [0u8; 64]);
}
