// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_7z_crypto_neon.c
 * @brief TTZip 7Z ARM64 hardware accelerated crypto engine (ARMv8 AES + SHA-256).
 */

#include "include/ttzip_7z_crypto_neon.h"
#include "include/ttzip_threadpool.h"
#include <string.h>
#include <stdlib.h>
#include <CommonCrypto/CommonCrypto.h>

#if defined(__ARM_NEON) || defined(__ARM_NEON__) || defined(__aarch64__)
#include <arm_neon.h>
#endif

#include "include/CTTZipBridge_Crypto.h"
#include "include/ttzip_7z_kdf_arm64.h"

int ttzip_7z_kdf_sha256_neon(
    const char* password,
    const uint8_t* salt,
    size_t salt_len,
    uint32_t num_cycles_power,
    uint8_t out_key[32]
) {
    return ttzip_7z_kdf_sha256_armv8(password, salt, salt_len, num_cycles_power, out_key);
}

typedef struct {
    const uint8_t* key;
    const uint8_t* active_iv;
    const uint8_t* src;
    uint8_t* dst;
    size_t size;
    size_t chunk_size;
    bool has_error;
} aes_chunk_worker_arg_t;

static void aes_chunk_worker(size_t i, void* arg) {
    aes_chunk_worker_arg_t* ctx = (aes_chunk_worker_arg_t*)arg;
    size_t offset = i * ctx->chunk_size;
    size_t cur_len = (offset + ctx->chunk_size <= ctx->size) ? ctx->chunk_size : (ctx->size - offset);
    if (cur_len % 16 != 0) cur_len = (cur_len / 16) * 16;
    if (cur_len == 0) return;

    const uint8_t* chunk_iv = (i == 0) ? ctx->active_iv : (ctx->src + offset - 16);
    size_t dataOutMoved = 0;
    CCCryptorStatus status = CCCrypt(
        kCCDecrypt,
        kCCAlgorithmAES,
        0,
        ctx->key,
        kCCKeySizeAES256,
        chunk_iv,
        ctx->src + offset,
        cur_len,
        ctx->dst + offset,
        cur_len,
        &dataOutMoved
    );
    if (status != kCCSuccess) {
        ctx->has_error = true;
    }
}

int ttzip_7z_aes256_cbc_decrypt_neon(
    const uint8_t* key,
    const uint8_t* iv,
    const uint8_t* src,
    size_t size,
    uint8_t* dst
) {
    if (!key || !src || !dst || size == 0 || (size % 16) != 0) {
        return -1;
    }

    uint8_t default_iv[16] = {0};
    const uint8_t* active_iv = iv ? iv : default_iv;

    if (size < 256 * 1024) {
        size_t dataOutMoved = 0;
        CCCryptorStatus status = CCCrypt(
            kCCDecrypt,
            kCCAlgorithmAES,
            0, // No padding (CBC raw)
            key,
            kCCKeySizeAES256,
            active_iv,
            src,
            size,
            dst,
            size,
            &dataOutMoved
        );
        return status == kCCSuccess ? 0 : -2;
    }

    // Parallel CBC decryption (512KB chunks, 16-byte aligned)
    size_t chunk_size = 512 * 1024;
    size_t num_chunks = (size + chunk_size - 1) / chunk_size;

    aes_chunk_worker_arg_t worker_arg = {
        .key = key,
        .active_iv = active_iv,
        .src = src,
        .dst = dst,
        .size = size,
        .chunk_size = chunk_size,
        .has_error = false
    };

    ttzip_parallel_for(ttzip_threadpool_shared(), num_chunks, aes_chunk_worker, &worker_arg);

    return worker_arg.has_error ? -2 : 0;
}
