// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_7z_crypto_neon.h
 * @brief 7Z ARM64 hardware accelerated SHA-256 KDF and AES-256-CBC decryption.
 */

#ifndef TTZIP_7Z_CRYPTO_NEON_H
#define TTZIP_7Z_CRYPTO_NEON_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

int ttzip_7z_kdf_sha256_neon(
    const char* password,
    const uint8_t* salt,
    size_t salt_len,
    uint32_t num_cycles_power,
    uint8_t out_key[32]
);

int ttzip_7z_aes256_cbc_decrypt_neon(
    const uint8_t* key,
    const uint8_t* iv,
    const uint8_t* src,
    size_t size,
    uint8_t* dst
);

#ifdef __cplusplus
}
#endif

#endif // TTZIP_7Z_CRYPTO_NEON_H
