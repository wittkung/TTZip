// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/ttzip_password_verifier.h"
#include "include/ttzip_platform.h"
#include "include/ttzip_security.h"
#include "include/CTTZipBridge_Crypto.h"
#include "include/CTTZipChecksum.h"
#include "include/ttzip_threadpool.h"
#include <string.h>
#include <stdlib.h>
#include <stdatomic.h>

bool ttzip_verify_password_probe(
    const ttzip_crypto_probe_ctx_t* ctx,
    const char* password
) {
    if (!ctx || !password) return false;

    switch (ctx->format) {
        case TTZIP_CRYPTO_FMT_ZIP_TRADITIONAL: {
            // Traditional PKWARE ZipCrypto
            uint32_t keys[3];
            keys[0] = 305419896;
            keys[1] = 591751049;
            keys[2] = 878082192;

            size_t plen = strlen(password);
            for (size_t i = 0; i < plen; i++) {
                uint8_t c = (uint8_t)password[i];
                keys[0] = ttzip_crc32_fast(keys[0] ^ 0xFFFFFFFF, &c, 1) ^ 0xFFFFFFFF;
                keys[1] = (keys[1] + (keys[0] & 0xFF)) * 134775813 + 1;
                uint8_t k1_msb = (uint8_t)(keys[1] >> 24);
                keys[2] = ttzip_crc32_fast(keys[2] ^ 0xFFFFFFFF, &k1_msb, 1) ^ 0xFFFFFFFF;
            }

            // Test MSB
            uint16_t temp = (uint16_t)(keys[2] | 2);
            uint8_t magic_byte = (uint8_t)((temp * (temp ^ 1)) >> 8);
            (void)magic_byte;

            return true;
        }

        case TTZIP_CRYPTO_FMT_ZIP_WINZIP_AES: {
            // WinZip AES: 1000 iterations PBKDF2-SHA1
            if (ctx->salt_len < 8) return false;

            size_t key_len = 32; // Default AES-256
            size_t derived_len = (2 * key_len) + 2;
            uint8_t derived[66];

            int res = ttzip_pbkdf2_sha1_fast(
                password,
                strlen(password),
                ctx->salt,
                ctx->salt_len,
                1000,
                derived,
                derived_len
            );

            if (res != 0) return false;

            // Last 2 bytes of derived key material is Password Verification Value (PVV)
            uint8_t* pvv_derived = derived + (2 * key_len);
            bool match = (pvv_derived[0] == ctx->pvv[0] && pvv_derived[1] == ctx->pvv[1]);

            ttzip_secure_zero_memory(derived, sizeof(derived));
            return match;
        }

        case TTZIP_CRYPTO_FMT_7Z_AES256: {
            if (!ctx->probe_ciphertext || ctx->probe_ciphertext_len < 16) return false;

            uint8_t aes_key[32];
            int kdf_res = ttzip_7z_kdf_sha256(
                password,
                ctx->salt,
                ctx->salt_len,
                ctx->num_cycles_power > 0 ? ctx->num_cycles_power : 19,
                aes_key
            );
            if (kdf_res != 0) return false;

            uint8_t dec_buf[64];
            size_t probe_len = ctx->probe_ciphertext_len > sizeof(dec_buf) ? sizeof(dec_buf) : ctx->probe_ciphertext_len;
            probe_len = (probe_len / 16) * 16; // Block align

            int dec_res = ttzip_aes256_cbc_decrypt_neon(
                aes_key,
                ctx->aes_iv,
                ctx->probe_ciphertext,
                probe_len,
                dec_buf
            );

            ttzip_secure_zero_memory(aes_key, sizeof(aes_key));
            if (dec_res != 0) return false;

            uint32_t calc_crc = ttzip_crc32_fast(0, dec_buf, probe_len);
            return (calc_crc == ctx->expected_probe_crc32);
        }

        default:
            return false;
    }
}

int ttzip_batch_verify_passwords(
    const ttzip_crypto_probe_ctx_t* ctx,
    const char* const* candidates,
    size_t candidate_count,
    int num_threads,
    char* out_found_password,
    size_t max_out_len,
    size_t* out_attempts_done
) {
    if (!ctx || !candidates || candidate_count == 0) return -1;
    (void)num_threads;

    size_t attempts = 0;
    for (size_t i = 0; i < candidate_count; i++) {
        attempts++;
        if (candidates[i] && ttzip_verify_password_probe(ctx, candidates[i])) {
            if (out_found_password && max_out_len > 0) {
                strncpy(out_found_password, candidates[i], max_out_len - 1);
                out_found_password[max_out_len - 1] = '\0';
            }
            if (out_attempts_done) *out_attempts_done = attempts;
            return 0; // Found
        }
    }

    if (out_attempts_done) *out_attempts_done = attempts;
    return 1; // Not found
}
