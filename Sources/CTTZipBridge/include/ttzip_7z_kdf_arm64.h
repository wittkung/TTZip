// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_7z_kdf_arm64.h
 * @brief ARMv8 Cryptographic Extensions accelerated 7Z SHA-256 key derivation.
 */

#ifndef TTZIP_7Z_KDF_ARM64_H
#define TTZIP_7Z_KDF_ARM64_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// 7Z AES-256 Crypto Session Struct (Read-only shared across threads)
typedef struct {
    bool     is_active;
    uint8_t  aes_key[32];
    uint8_t  aes_iv[16];
    uint32_t num_cycles_power;
} ttzip_7z_crypto_session_t;

int ttzip_7z_kdf_sha256_armv8(
    const char* password,
    const uint8_t* salt,
    size_t salt_len,
    uint32_t num_cycles_power,
    uint8_t out_key[32]
);

int ttzip_7z_crypto_session_init(
    ttzip_7z_crypto_session_t* session,
    const char* password,
    const uint8_t* salt,
    size_t salt_len,
    uint32_t num_cycles_power
);

#ifdef __cplusplus
}
#endif

#endif // TTZIP_7Z_KDF_ARM64_H
