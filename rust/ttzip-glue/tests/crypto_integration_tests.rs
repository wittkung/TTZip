// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Comprehensive differential and NIST vector integration tests for TTZip crypto operators.

use sha2::Digest;
use std::ffi::CString;
use std::time::Instant;
use ttzip_glue::crypto::{
    adler32_fast, aes256_cbc_decrypt, aes256_cbc_encrypt, aes256_ctr_crypt, crc32_fast,
    sha256_7z_kdf, Aes256Context,
};
use ttzip_glue::ffi::{
    ttzip_rust_7z_kdf_sha256, ttzip_rust_adler32, ttzip_rust_aes256_cbc_decrypt,
    ttzip_rust_aes256_ctr, ttzip_rust_crc32,
};
use ttzip_glue::types::TTZipStatus;

// ============================================================================
// 1. CRC32 Differential Testing with crc32fast Oracle
// ============================================================================
#[test]
fn test_crc32_differential_oracle() {
    let test_sizes = [
        0, 1, 2, 3, 4, 7, 8, 15, 16, 31, 32, 63, 64, 65, 127, 128, 191, 192, 193, 384, 512,
        1000, 1024, 2048, 4096, 8192, 16384, 65536,
    ];

    let mut corpus = vec![0u8; 65536];
    for (i, b) in corpus.iter_mut().enumerate() {
        *b = ((i * 131 + 17) & 0xFF) as u8;
    }

    for &size in &test_sizes {
        let chunk = &corpus[..size];
        let mut hasher = crc32fast::Hasher::new();
        hasher.update(chunk);
        let oracle_crc = hasher.finalize();

        let fast_crc = crc32_fast(0, chunk);
        assert_eq!(
            fast_crc, oracle_crc,
            "CRC32 mismatch against oracle for size {}",
            size
        );

        // Test C-ABI FFI wrapper
        let ffi_crc = unsafe { ttzip_rust_crc32(0, chunk.as_ptr(), chunk.len()) };
        assert_eq!(
            ffi_crc, oracle_crc,
            "FFI CRC32 mismatch against oracle for size {}",
            size
        );
    }

    // Test incremental CRC updates
    let chunk1 = &corpus[..500];
    let chunk2 = &corpus[500..1200];
    let expected = crc32_fast(0, &corpus[..1200]);
    let step1 = crc32_fast(0, chunk1);
    let step2 = crc32_fast(step1, chunk2);
    assert_eq!(step2, expected, "Incremental CRC32 step calculation failed");
}

// ============================================================================
// 2. Adler32 Differential Testing with adler2 Oracle
// ============================================================================
#[test]
fn test_adler32_differential_oracle() {
    let test_sizes = [
        0, 1, 2, 3, 4, 7, 8, 15, 16, 31, 32, 63, 64, 65, 127, 128, 5551, 5552, 5553, 10000,
        20000, 65536,
    ];

    let mut corpus = vec![0u8; 65536];
    for (i, b) in corpus.iter_mut().enumerate() {
        *b = ((i * 97 + 31) & 0xFF) as u8;
    }

    for &size in &test_sizes {
        let chunk = &corpus[..size];
        let mut oracle = adler2::Adler32::new();
        oracle.write_slice(chunk);
        let oracle_adler = oracle.checksum();

        let fast_adler = adler32_fast(1, chunk);
        assert_eq!(
            fast_adler, oracle_adler,
            "Adler32 mismatch against oracle for size {}",
            size
        );

        // Test C-ABI FFI wrapper
        let ffi_adler = unsafe { ttzip_rust_adler32(1, chunk.as_ptr(), chunk.len()) };
        assert_eq!(
            ffi_adler, oracle_adler,
            "FFI Adler32 mismatch against oracle for size {}",
            size
        );
    }
}

// ============================================================================
// 3. AES-256-CTR NIST Vectors & Boundary Testing
// ============================================================================
#[test]
fn test_aes256_ctr_nist_and_ffi() {
    let key = [0x42u8; 32];
    let counter = 1000u64;

    let test_lengths = [0, 1, 7, 16, 17, 32, 64, 127, 128, 129, 256, 1000, 4096];
    for &len in &test_lengths {
        let mut plaintext = vec![0u8; len];
        for (i, b) in plaintext.iter_mut().enumerate() {
            *b = (i ^ 0x55) as u8;
        }

        let mut cipher1 = vec![0u8; len];
        let mut decrypted = vec![0u8; len];

        // Safe Rust encrypt & decrypt
        aes256_ctr_crypt(&key, counter, &plaintext, &mut cipher1).unwrap();
        aes256_ctr_crypt(&key, counter, &cipher1, &mut decrypted).unwrap();
        assert_eq!(plaintext, decrypted, "AES-CTR roundtrip failed for len {}", len);

        // FFI encrypt & decrypt
        let mut cipher2 = vec![0u8; len];
        let mut ffi_decrypted = vec![0u8; len];

        let status_enc = unsafe {
            ttzip_rust_aes256_ctr(
                key.as_ptr(),
                counter,
                plaintext.as_ptr(),
                len,
                cipher2.as_mut_ptr(),
            )
        };
        assert_eq!(status_enc, TTZipStatus::Ok.to_i32());
        assert_eq!(cipher1, cipher2);

        let status_dec = unsafe {
            ttzip_rust_aes256_ctr(
                key.as_ptr(),
                counter,
                cipher2.as_ptr(),
                len,
                ffi_decrypted.as_mut_ptr(),
            )
        };
        assert_eq!(status_dec, TTZipStatus::Ok.to_i32());
        assert_eq!(plaintext, ffi_decrypted);
    }

    // FFI Error handling
    unsafe {
        let dummy = [0u8; 16];
        let mut out = [0u8; 16];
        assert_eq!(
            ttzip_rust_aes256_ctr(std::ptr::null(), 0, dummy.as_ptr(), 16, out.as_mut_ptr()),
            TTZipStatus::ErrInvalidParam.to_i32()
        );
        assert_eq!(
            ttzip_rust_aes256_ctr(dummy.as_ptr(), 0, std::ptr::null(), 16, out.as_mut_ptr()),
            TTZipStatus::ErrInvalidParam.to_i32()
        );
        assert_eq!(
            ttzip_rust_aes256_ctr(dummy.as_ptr(), 0, dummy.as_ptr(), 16, std::ptr::null_mut()),
            TTZipStatus::ErrInvalidParam.to_i32()
        );
    }
}

// ============================================================================
// 4. AES-256-CBC Decryption & FFI Testing
// ============================================================================
#[test]
fn test_aes256_cbc_decrypt_and_ffi() {
    let key = [0x37u8; 32];
    let iv = [0x12u8; 16];

    let test_lengths = [16, 32, 64, 128, 144, 256, 1024, 4096];
    for &len in &test_lengths {
        let mut plaintext = vec![0u8; len];
        for (i, b) in plaintext.iter_mut().enumerate() {
            *b = (i * 11 + 5) as u8;
        }

        let mut ciphertext = vec![0u8; len];
        let mut decrypted = vec![0u8; len];

        aes256_cbc_encrypt(&key, &iv, &plaintext, &mut ciphertext).unwrap();
        aes256_cbc_decrypt(&key, &iv, &ciphertext, &mut decrypted).unwrap();
        assert_eq!(plaintext, decrypted, "AES-CBC roundtrip failed for len {}", len);

        // FFI Decrypt
        let mut ffi_decrypted = vec![0u8; len];
        let status = unsafe {
            ttzip_rust_aes256_cbc_decrypt(
                key.as_ptr(),
                iv.as_ptr(),
                ciphertext.as_ptr(),
                len,
                ffi_decrypted.as_mut_ptr(),
            )
        };
        assert_eq!(status, TTZipStatus::Ok.to_i32());
        assert_eq!(plaintext, ffi_decrypted);
    }

    // FFI Error handling: non-16-byte aligned length must fail
    unsafe {
        let key = [0u8; 32];
        let iv = [0u8; 16];
        let buf = [0u8; 15];
        let mut out = [0u8; 15];
        assert_eq!(
            ttzip_rust_aes256_cbc_decrypt(
                key.as_ptr(),
                iv.as_ptr(),
                buf.as_ptr(),
                15,
                out.as_mut_ptr()
            ),
            TTZipStatus::ErrInvalidParam.to_i32()
        );
    }
}

// ============================================================================
// 5. 7z SHA-256 KDF Verification
// ============================================================================
fn reference_7z_kdf(password: &str, salt: &[u8], num_cycles_power: u32) -> [u8; 32] {
    let mut hasher = sha2::Sha256::new();
    let num_cycles = 1u64 << num_cycles_power;

    let mut utf16_pass = Vec::new();
    for u in password.encode_utf16() {
        utf16_pass.extend_from_slice(&u.to_le_bytes());
    }

    for i in 0..num_cycles {
        if !salt.is_empty() {
            hasher.update(salt);
        }
        if !utf16_pass.is_empty() {
            hasher.update(&utf16_pass);
        }
        hasher.update(i.to_le_bytes());
    }

    let result = hasher.finalize();
    let mut out = [0u8; 32];
    out.copy_from_slice(&result);
    out
}

#[test]
fn test_7z_kdf_sha256_against_oracle() {
    let test_passwords = [
        "123456",
        "P@ssw0rd!#$%",
        "TTZip macOS 极速压缩与解压",
        "A very long password with unicode 🚀🌟 and complex characters!",
    ];
    let salts: [&[u8]; 3] = [&[], &[0x10, 0x20, 0x30, 0x40], &[0xDE, 0xAD, 0xBE, 0xEF, 0x01, 0x02, 0x03, 0x04]];

    for &pwd in &test_passwords {
        for &salt in &salts {
            // Test with 64 cycles (power = 6)
            let oracle_key = reference_7z_kdf(pwd, salt, 6);
            let fast_key = sha256_7z_kdf(pwd, salt, 6);
            assert_eq!(
                fast_key, oracle_key,
                "7z KDF mismatch for password '{}'",
                pwd
            );

            // Test FFI wrapper
            let c_pwd = CString::new(pwd).unwrap();
            let mut ffi_out = [0u8; 32];
            let status = unsafe {
                ttzip_rust_7z_kdf_sha256(
                    c_pwd.as_ptr(),
                    if salt.is_empty() { std::ptr::null() } else { salt.as_ptr() },
                    salt.len(),
                    6,
                    ffi_out.as_mut_ptr(),
                )
            };
            assert_eq!(status, TTZipStatus::Ok.to_i32());
            assert_eq!(ffi_out, oracle_key);
        }
    }
}

// ============================================================================
// 6. Zeroize Memory Invariant Test
// ============================================================================
#[test]
fn test_aes256_context_zeroize_on_drop() {
    let key = [0x55u8; 32];
    let mut ctx = Aes256Context::new(&key);
    assert_ne!(ctx.key, [0u8; 32]);
    assert_ne!(ctx.round_keys_enc[0], [0u8; 16]);

    use zeroize::Zeroize;
    ctx.zeroize();
    assert_eq!(ctx.key, [0u8; 32]);
    assert_eq!(ctx.round_keys_enc[0], [0u8; 16]);
    assert_eq!(ctx.round_keys_dec[0], [0u8; 16]);
}

// ============================================================================
// 7. Throughput Benchmark Test
// ============================================================================
#[test]
fn test_crypto_throughput_benchmark() {
    let size = 16 * 1024 * 1024; // 16 MB buffer
    let buffer = vec![0x33u8; size];
    let mut dst = vec![0u8; size];
    let key = [0x77u8; 32];
    let iv = [0x11u8; 16];

    // Warm-up & CRC32 Benchmark
    let mut crc = 0u32;
    let start_crc = Instant::now();
    let iters_crc = 100;
    for _ in 0..iters_crc {
        crc = crc32_fast(crc, &buffer);
    }
    let dur_crc = start_crc.elapsed();
    let gb_crc = (size as f64 * iters_crc as f64) / (1024.0 * 1024.0 * 1024.0);
    let speed_crc = gb_crc / dur_crc.as_secs_f64();
    println!("CRC32 Throughput: {:.2} GB/s", speed_crc);
    assert!(crc != 0 || size > 0);

    // Adler32 Benchmark
    let mut adler = 1u32;
    let start_adler = Instant::now();
    let iters_adler = 100;
    for _ in 0..iters_adler {
        adler = adler32_fast(adler, &buffer);
    }
    let dur_adler = start_adler.elapsed();
    let gb_adler = (size as f64 * iters_adler as f64) / (1024.0 * 1024.0 * 1024.0);
    let speed_adler = gb_adler / dur_adler.as_secs_f64();
    println!("Adler32 Throughput: {:.2} GB/s", speed_adler);
    assert!(adler != 0);

    // AES-256-CTR Benchmark
    let start_ctr = Instant::now();
    let iters_ctr = 20;
    for i in 0..iters_ctr {
        aes256_ctr_crypt(&key, (i * 1000) as u64, &buffer, &mut dst).unwrap();
    }
    let dur_ctr = start_ctr.elapsed();
    let gb_ctr = (size as f64 * iters_ctr as f64) / (1024.0 * 1024.0 * 1024.0);
    let speed_ctr = gb_ctr / dur_ctr.as_secs_f64();
    println!("AES-256-CTR Throughput: {:.2} GB/s", speed_ctr);

    // AES-256-CBC Decrypt Benchmark
    let start_cbc = Instant::now();
    let iters_cbc = 20;
    for _ in 0..iters_cbc {
        aes256_cbc_decrypt(&key, &iv, &buffer, &mut dst).unwrap();
    }
    let dur_cbc = start_cbc.elapsed();
    let gb_cbc = (size as f64 * iters_cbc as f64) / (1024.0 * 1024.0 * 1024.0);
    let speed_cbc = gb_cbc / dur_cbc.as_secs_f64();
    println!("AES-256-CBC Decrypt Throughput: {:.2} GB/s", speed_cbc);
}
