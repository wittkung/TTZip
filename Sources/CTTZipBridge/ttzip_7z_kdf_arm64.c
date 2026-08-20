// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_7z_kdf_arm64.c
 * @brief 7Z ARM64 SHA-256 hardware accelerated Key Derivation Function (KDF).
 */

#include "include/ttzip_7z_kdf_arm64.h"
#include "include/CTTZipBridge.h"
#include <string.h>
#include <stdlib.h>
#include <Security/SecRandom.h>

// Zero-heap stack UTF-8 to UTF-16LE transcoder
static int utf8_to_utf16le_stack(const char* utf8, uint8_t* out_buf, size_t max_out_bytes, size_t* out_len) {
    if (!out_buf || max_out_bytes < 2) {
        if (out_len) *out_len = 0;
        return -1;
    }
    if (!utf8) {
        if (out_len) *out_len = 0;
        return 0;
    }
    size_t in_len = strlen(utf8);
    size_t out_idx = 0;
    for (size_t i = 0; i < in_len; ) {
        uint32_t cp = 0;
        uint8_t c = (uint8_t)utf8[i];
        if (c < 0x80) {
            cp = c; i += 1;
        } else if ((c & 0xE0) == 0xC0 && i + 1 < in_len) {
            cp = ((c & 0x1F) << 6) | ((uint8_t)utf8[i+1] & 0x3F);
            i += 2;
        } else if ((c & 0xF0) == 0xE0 && i + 2 < in_len) {
            cp = ((c & 0x0F) << 12) | (((uint8_t)utf8[i+1] & 0x3F) << 6) | ((uint8_t)utf8[i+2] & 0x3F);
            i += 3;
        } else if ((c & 0xF8) == 0xF0 && i + 3 < in_len) {
            cp = ((c & 0x07) << 18) | (((uint8_t)utf8[i+1] & 0x3F) << 12) | (((uint8_t)utf8[i+2] & 0x3F) << 6) | ((uint8_t)utf8[i+3] & 0x3F);
            i += 4;
        } else {
            cp = 0xFFFD; i += 1;
        }
        
        if (cp < 0x10000) {
            if (out_idx + 2 > max_out_bytes) break;
            out_buf[out_idx++] = (uint8_t)(cp & 0xFF);
            out_buf[out_idx++] = (uint8_t)((cp >> 8) & 0xFF);
        } else {
            if (out_idx + 4 > max_out_bytes) break;
            cp -= 0x10000;
            uint16_t high = (uint16_t)(0xD800 + (cp >> 10));
            uint16_t low = (uint16_t)(0xDC00 + (cp & 0x3FF));
            out_buf[out_idx++] = (uint8_t)(high & 0xFF);
            out_buf[out_idx++] = (uint8_t)((high >> 8) & 0xFF);
            out_buf[out_idx++] = (uint8_t)(low & 0xFF);
            out_buf[out_idx++] = (uint8_t)((low >> 8) & 0xFF);
        }
    }
    if (out_len) *out_len = out_idx;
    return 0;
}

#include <CommonCrypto/CommonDigest.h>

int ttzip_7z_kdf_sha256_armv8(
    const char* password,
    const uint8_t* salt,
    size_t salt_len,
    uint32_t num_cycles_power,
    uint8_t out_key[32]
) {
    if (!password || !out_key) return TTZIP_ERR_INVALID_PARAM;
    if (salt_len > 16) return TTZIP_ERR_INVALID_PARAM;
    if (num_cycles_power > 24) return TTZIP_ERR_INVALID_PARAM;

    // Stack fixed 536-byte buffer: [Salt (<=16) | UTF-16LE Password (<=512) | Counter (8)]
    uint8_t kdf_buf[536];
    size_t effective_salt_len = 0;
    if (salt && salt_len > 0) {
        effective_salt_len = salt_len;
        memcpy(kdf_buf, salt, effective_salt_len);
    }

    size_t utf16_len = 0;
    if (utf8_to_utf16le_stack(password, kdf_buf + effective_salt_len, 512, &utf16_len) != 0) {
        ttzip_secure_zero(kdf_buf, sizeof(kdf_buf));
        return TTZIP_ERR_INVALID_PARAM;
    }

    size_t base_len = effective_salt_len + utf16_len;
    size_t full_entry_len = base_len + 8;
    uint64_t num_cycles = (1ULL << num_cycles_power);

    CC_SHA256_CTX ctx;
    CC_SHA256_Init(&ctx);

    for (uint64_t i = 0; i < num_cycles; i++) {
        kdf_buf[base_len + 0] = (uint8_t)(i & 0xFF);
        kdf_buf[base_len + 1] = (uint8_t)((i >> 8) & 0xFF);
        kdf_buf[base_len + 2] = (uint8_t)((i >> 16) & 0xFF);
        kdf_buf[base_len + 3] = (uint8_t)((i >> 24) & 0xFF);
        kdf_buf[base_len + 4] = (uint8_t)((i >> 32) & 0xFF);
        kdf_buf[base_len + 5] = (uint8_t)((i >> 40) & 0xFF);
        kdf_buf[base_len + 6] = (uint8_t)((i >> 48) & 0xFF);
        kdf_buf[base_len + 7] = (uint8_t)((i >> 56) & 0xFF);
        CC_SHA256_Update(&ctx, kdf_buf, (CC_LONG)full_entry_len);
    }
    CC_SHA256_Final(out_key, &ctx);

    // Explicitly wipe sensitive buffers (Dead-store elimination immunity)
    ttzip_secure_zero(kdf_buf, sizeof(kdf_buf));
    ttzip_secure_zero(&ctx, sizeof(ctx));
    return TTZIP_OK;
}

int ttzip_7z_crypto_session_init(
    ttzip_7z_crypto_session_t* session,
    const char* password,
    const uint8_t* salt,
    size_t salt_len,
    uint32_t num_cycles_power
) {
    if (!session) return TTZIP_ERR_INVALID_PARAM;
    memset(session, 0, sizeof(ttzip_7z_crypto_session_t));
    if (!password || password[0] == '\0') {
        session->is_active = false;
        return TTZIP_OK;
    }
    session->is_active = true;
    session->num_cycles_power = num_cycles_power > 0 ? num_cycles_power : 19;
    
    // Cryptographically secure random IV
    if (SecRandomCopyBytes(kSecRandomDefault, 16, session->aes_iv) != errSecSuccess) {
        session->is_active = false;
        return TTZIP_ERR_ARCHIVE_INIT_FAILED;
    }

    return ttzip_7z_kdf_sha256_armv8(password, salt, salt_len, session->num_cycles_power, session->aes_key);
}
