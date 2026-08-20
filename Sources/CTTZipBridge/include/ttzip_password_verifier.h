// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#ifndef TTZIP_PASSWORD_VERIFIER_H
#define TTZIP_PASSWORD_VERIFIER_H

#include "ttzip_platform.h"
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    TTZIP_CRYPTO_FMT_UNKNOWN = 0,
    TTZIP_CRYPTO_FMT_ZIP_TRADITIONAL = 1, // PKWARE ZipCrypto (12-byte header check)
    TTZIP_CRYPTO_FMT_ZIP_WINZIP_AES = 2,  // WinZip AES-128/192/256 (2-byte PVV check)
    TTZIP_CRYPTO_FMT_7Z_AES256 = 3        // 7-Zip SHA-256 KDF (2^N cycles + AES-CBC probe)
} ttzip_crypto_format_t;

typedef struct {
    ttzip_crypto_format_t format;
    uint8_t salt[16];
    size_t salt_len;
    uint8_t pvv[2];                  // 2-byte Password Verification Value (WinZip AES)
    uint16_t zip_crc_msb;            // Expected MSB check byte (PKWARE traditional)
    uint32_t num_cycles_power;       // 7z KDF power-of-2 cycles (e.g. 19)
    uint8_t aes_iv[16];              // 7z AES IV
    const uint8_t* probe_ciphertext; // Encrypted header stream chunk for 7z probe
    size_t probe_ciphertext_len;
    uint32_t expected_probe_crc32;   // Expected CRC-32 of decrypted probe block
} ttzip_crypto_probe_ctx_t;

/**
 * @brief Tests a single candidate password against pre-extracted crypto probe parameters in memory.
 * @return true if password is verified, false otherwise.
 */
TTZIP_API bool ttzip_verify_password_probe(
    const ttzip_crypto_probe_ctx_t* ctx,
    const char* password
);

/**
 * @brief Multi-threaded batch verification across candidate password dictionary.
 * @param ctx Crypto probe context.
 * @param candidates Array of candidate password strings.
 * @param candidate_count Number of candidate passwords.
 * @param num_threads Number of worker threads (0 for hardware concurrency).
 * @param out_found_password Destination buffer for matched password (if found).
 * @param max_out_len Maximum capacity of out_found_password.
 * @param out_attempts_done Pointer to store number of evaluated attempts.
 * @return 0 if password found, 1 if not found, negative on error.
 */
TTZIP_API int ttzip_batch_verify_passwords(
    const ttzip_crypto_probe_ctx_t* ctx,
    const char* const* candidates,
    size_t candidate_count,
    int num_threads,
    char* out_found_password,
    size_t max_out_len,
    size_t* out_attempts_done
);

#ifdef __cplusplus
}
#endif

#endif // TTZIP_PASSWORD_VERIFIER_H
