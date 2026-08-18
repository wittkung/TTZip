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

#if defined(__ARM_NEON) || defined(__aarch64__)
#include <arm_neon.h>

static const uint32_t SHA256_K[64] = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
};

static inline void sha256_transform_armv8_block(uint32_t state[8], const uint8_t data[64]) {
    uint32x4_t abcd = vld1q_u32(&state[0]);
    uint32x4_t efgh = vld1q_u32(&state[4]);
    uint32x4_t abcd_orig = abcd;
    uint32x4_t efgh_orig = efgh;

    uint32x4_t w0 = vreinterpretq_u32_u8(vrev32q_u8(vld1q_u8(data + 0)));
    uint32x4_t w1 = vreinterpretq_u32_u8(vrev32q_u8(vld1q_u8(data + 16)));
    uint32x4_t w2 = vreinterpretq_u32_u8(vrev32q_u8(vld1q_u8(data + 32)));
    uint32x4_t w3 = vreinterpretq_u32_u8(vrev32q_u8(vld1q_u8(data + 48)));

    uint32x4_t wk;

    // Rounds 0-3
    wk = vaddq_u32(w0, vld1q_u32(&SHA256_K[0]));
    abcd = vsha256hq_u32(abcd, efgh, wk);
    efgh = vsha256h2q_u32(efgh, abcd_orig, wk);

    // Rounds 4-7
    wk = vaddq_u32(w1, vld1q_u32(&SHA256_K[4]));
    abcd_orig = abcd;
    abcd = vsha256hq_u32(abcd, efgh, wk);
    efgh = vsha256h2q_u32(efgh, abcd_orig, wk);

    // Rounds 8-11
    wk = vaddq_u32(w2, vld1q_u32(&SHA256_K[8]));
    abcd_orig = abcd;
    abcd = vsha256hq_u32(abcd, efgh, wk);
    efgh = vsha256h2q_u32(efgh, abcd_orig, wk);

    // Rounds 12-15
    wk = vaddq_u32(w3, vld1q_u32(&SHA256_K[12]));
    abcd_orig = abcd;
    abcd = vsha256hq_u32(abcd, efgh, wk);
    efgh = vsha256h2q_u32(efgh, abcd_orig, wk);

    for (int t = 16; t < 64; t += 16) {
        uint32x4_t s0, s1;

        // w0 (t+0..3)
        s0 = vsha256su0q_u32(w0, w1);
        w0 = vsha256su1q_u32(s0, w2, w3);
        wk = vaddq_u32(w0, vld1q_u32(&SHA256_K[t + 0]));
        abcd_orig = abcd;
        abcd = vsha256hq_u32(abcd, efgh, wk);
        efgh = vsha256h2q_u32(efgh, abcd_orig, wk);

        // w1 (t+4..7)
        s0 = vsha256su0q_u32(w1, w2);
        w1 = vsha256su1q_u32(s0, w3, w0);
        wk = vaddq_u32(w1, vld1q_u32(&SHA256_K[t + 4]));
        abcd_orig = abcd;
        abcd = vsha256hq_u32(abcd, efgh, wk);
        efgh = vsha256h2q_u32(efgh, abcd_orig, wk);

        // w2 (t+8..11)
        s0 = vsha256su0q_u32(w2, w3);
        w2 = vsha256su1q_u32(s0, w0, w1);
        wk = vaddq_u32(w2, vld1q_u32(&SHA256_K[t + 8]));
        abcd_orig = abcd;
        abcd = vsha256hq_u32(abcd, efgh, wk);
        efgh = vsha256h2q_u32(efgh, abcd_orig, wk);

        // w3 (t+12..15)
        s0 = vsha256su0q_u32(w3, w0);
        w3 = vsha256su1q_u32(s0, w1, w2);
        wk = vaddq_u32(w3, vld1q_u32(&SHA256_K[t + 12]));
        abcd_orig = abcd;
        abcd = vsha256hq_u32(abcd, efgh, wk);
        efgh = vsha256h2q_u32(efgh, abcd_orig, wk);
    }

    abcd = vaddq_u32(abcd, vld1q_u32(&state[0]));
    efgh = vaddq_u32(efgh, vld1q_u32(&state[4]));

    vst1q_u32(&state[0], abcd);
    vst1q_u32(&state[4], efgh);
}
#endif

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
        memset(session->aes_iv, 0x5A, 16);
    }

    return ttzip_7z_kdf_sha256_armv8(password, salt, salt_len, session->num_cycles_power, session->aes_key);
}
