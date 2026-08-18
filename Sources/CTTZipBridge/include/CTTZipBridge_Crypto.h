// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#ifndef CTTZIPBRIDGE_CRYPTO_H
#define CTTZIPBRIDGE_CRYPTO_H

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Derives cryptographic keys using PBKDF2-HMAC-SHA1.
 *
 * @param password Pointer to UTF-8 encoded password string.
 * @param pass_len Length of password in bytes.
 * @param salt Pointer to salt buffer.
 * @param salt_len Length of salt in bytes (typically 16 bytes for WinZip AES-256).
 * @param rounds Number of PBKDF2 iterations (e.g. 1000).
 * @param out_key Destination buffer for derived key material.
 * @param key_len Requested derived key length in bytes.
 * @return 0 on success, non-zero error code otherwise.
 */
int ttzip_pbkdf2_sha1_fast(
    const char* password,
    size_t pass_len,
    const uint8_t* salt,
    size_t salt_len,
    uint32_t rounds,
    uint8_t* out_key,
    size_t key_len
);

/**
 * Derives cryptographic keys using PBKDF2-HMAC-SHA256.
 *
 * @param password Pointer to UTF-8 encoded password string.
 * @param pass_len Length of password in bytes.
 * @param salt Pointer to salt buffer.
 * @param salt_len Length of salt in bytes.
 * @param rounds Number of PBKDF2 iterations.
 * @param out_key Destination buffer for derived key material.
 * @param key_len Requested derived key length in bytes.
 * @return 0 on success, non-zero error code otherwise.
 */
int ttzip_pbkdf2_sha256_fast(
    const char* password,
    size_t pass_len,
    const uint8_t* salt,
    size_t salt_len,
    uint32_t rounds,
    uint8_t* out_key,
    size_t key_len
);

/**
 * Performs AES-256 CTR encryption/decryption on a single thread.
 *
 * @param key 32-byte AES-256 encryption key.
 * @param initial_block_count 1-based initial 16-byte block counter (WinZip AES convention).
 * @param src Input ciphertext/plaintext buffer.
 * @param length Buffer length in bytes.
 * @param dst Destination buffer.
 * @return 0 on success, non-zero on failure.
 */
int ttzip_aes256_ctr_crypt(
    const uint8_t* key,
    uint64_t initial_block_count,
    const uint8_t* src,
    size_t length,
    uint8_t* dst
);

/**
 * Performs multi-threaded parallel AES-256 CTR encryption/decryption.
 *
 * @param key 32-byte AES-256 key.
 * @param src Input buffer.
 * @param length Buffer length in bytes.
 * @param dst Destination buffer.
 * @param threads Target thread pool size.
 * @return 0 on success, non-zero on failure.
 */
int ttzip_aes256_ctr_crypt_parallel(
    const uint8_t* key,
    const uint8_t* src,
    size_t length,
    uint8_t* dst,
    int threads
);

/**
 * Computes truncated 10-byte HMAC-SHA1 authentication tag for WinZip AES format.
 *
 * @param key Authentication key buffer (32 bytes).
 * @param key_len Length of authentication key.
 * @param data Ciphertext buffer to authenticate.
 * @param data_len Length of ciphertext buffer.
 * @param out_mac Destination buffer for 10-byte truncated HMAC tag.
 * @return 0 on success, non-zero on failure.
 */
int ttzip_compute_hmac_sha1_fast(
    const uint8_t* key,
    size_t key_len,
    const uint8_t* data,
    size_t data_len,
    uint8_t out_mac[10]
);

/**
 * Fused AES-256 CTR encryption and HMAC-SHA1 authentication pipeline.
 *
 * @param derived_keys 66-byte PBKDF2 derived keys (32B AES + 32B HMAC + 2B PVV).
 * @param src Plaintext source buffer.
 * @param length Plaintext length in bytes.
 * @param dst_cipher Destination buffer for ciphertext.
 * @param out_mac Destination buffer for 10-byte HMAC tag.
 * @return 0 on success, non-zero on failure.
 */
int ttzip_aes256_encrypt_and_hmac_fused(
    const uint8_t derived_keys[66],
    const uint8_t* src,
    size_t length,
    uint8_t* dst_cipher,
    uint8_t out_mac[10]
);

/**
 * End-to-end WinZip AES-256 decryption and HMAC authentication verification.
 *
 * @param password Password string.
 * @param enc_payload Full encrypted payload stream (Salt + PVV + Ciphertext + HMAC).
 * @param payload_size Total payload stream byte count.
 * @param out_plain Destination buffer for decrypted plaintext.
 * @param out_plain_len Pointer to variable receiving plaintext length.
 * @return 0 on success, non-zero on authentication or decryption failure.
 */
int ttzip_aes256_decrypt_and_verify(
    const char* password,
    const uint8_t* enc_payload,
    size_t payload_size,
    uint8_t* out_plain,
    size_t* out_plain_len
);

/**
 * Decrypts AES-256 in CBC mode using ARM NEON SIMD acceleration.
 *
 * @param key 32-byte AES-256 key.
 * @param iv 16-byte initialization vector.
 * @param src Input ciphertext buffer.
 * @param length Length of buffer in bytes (must be multiple of 16).
 * @param dst Output plaintext buffer.
 * @return 0 on success, non-zero on failure.
 */
int ttzip_aes256_cbc_decrypt_neon(
    const uint8_t* key,
    const uint8_t iv[16],
    const uint8_t* src,
    size_t length,
    uint8_t* dst
);

/**
 * Encrypts AES-256 in CBC mode.
 *
 * @param key 32-byte AES-256 key.
 * @param iv 16-byte initialization vector.
 * @param src Input plaintext buffer.
 * @param length Length of buffer in bytes.
 * @param dst Output ciphertext buffer.
 * @return 0 on success, non-zero on failure.
 */
int ttzip_aes256_cbc_encrypt(
    const uint8_t* key,
    const uint8_t iv[16],
    const uint8_t* src,
    size_t length,
    uint8_t* dst
);

/**
 * Computes 7-Zip SHA-256 KDF key derivation.
 *
 * @param password Password string.
 * @param salt Salt buffer.
 * @param salt_len Salt length in bytes.
 * @param num_cycles_power Power-of-two iteration cycles (e.g. 19 for 2^19 rounds).
 * @param out_key 32-byte output key buffer.
 * @return 0 on success, non-zero on failure.
 */
int ttzip_7z_kdf_sha256(
    const char* password,
    const uint8_t* salt,
    size_t salt_len,
    uint32_t num_cycles_power,
    uint8_t out_key[32]
);

#ifdef __cplusplus
}
#endif

#endif /* CTTZIPBRIDGE_CRYPTO_H */
