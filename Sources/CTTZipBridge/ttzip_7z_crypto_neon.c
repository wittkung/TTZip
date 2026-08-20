// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_7z_crypto_neon.c
 * @brief TTZip 7Z ARM64 hardware accelerated crypto engine (ARMv8 AES-256-CBC + SHA-256).
 */

#include "include/ttzip_7z_crypto_neon.h"
#include "include/ttzip_threadpool.h"
#include <string.h>
#include <stdlib.h>

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

#if defined(__ARM_NEON) || defined(__ARM_NEON__) || defined(__aarch64__)

static const uint8_t sbox[256] = {
    0x63, 0x7C, 0x77, 0x7B, 0xF2, 0x6B, 0x6F, 0xC5, 0x30, 0x01, 0x67, 0x2B, 0xFE, 0xD7, 0xAB, 0x76,
    0xCA, 0x82, 0xC9, 0x7D, 0xFA, 0x59, 0x47, 0xF0, 0xAD, 0xD4, 0xA2, 0xAF, 0x9C, 0xA4, 0x72, 0xC0,
    0xB7, 0xFD, 0x93, 0x26, 0x36, 0x3F, 0xF7, 0xCC, 0x34, 0xA5, 0xE5, 0xF1, 0x71, 0xD8, 0x31, 0x15,
    0x04, 0xC7, 0x23, 0xC3, 0x18, 0x96, 0x05, 0x9A, 0x07, 0x12, 0x80, 0xE2, 0xEB, 0x27, 0xB2, 0x75,
    0x09, 0x83, 0x2C, 0x1A, 0x1B, 0x6E, 0x5A, 0xA0, 0x52, 0x3B, 0xD6, 0xB3, 0x29, 0xE3, 0x2F, 0x84,
    0x53, 0xD1, 0x00, 0xED, 0x20, 0xFC, 0xB1, 0x5B, 0x6A, 0xCB, 0xBE, 0x39, 0x4A, 0x4C, 0x58, 0xCF,
    0xD0, 0xEF, 0xAA, 0xFB, 0x43, 0x4D, 0x33, 0x85, 0x45, 0xF9, 0x02, 0x7F, 0x50, 0x3C, 0x9F, 0xA8,
    0x51, 0xA3, 0x40, 0x8F, 0x92, 0x9D, 0x38, 0xF5, 0xBC, 0xB6, 0xDA, 0x21, 0x10, 0xFF, 0xF3, 0xD2,
    0xCD, 0x0C, 0x13, 0xEC, 0x5F, 0x97, 0x44, 0x17, 0xC4, 0xA7, 0x7E, 0x3D, 0x64, 0x5D, 0x19, 0x73,
    0x60, 0x81, 0x4F, 0xDC, 0x22, 0x2A, 0x90, 0x88, 0x46, 0xEE, 0xB8, 0x14, 0xDE, 0x5E, 0x0B, 0xDB,
    0xE0, 0x32, 0x3A, 0x0A, 0x49, 0x06, 0x24, 0x5C, 0xC2, 0xD3, 0xAC, 0x62, 0x91, 0x95, 0xE4, 0x79,
    0xE7, 0xC8, 0x37, 0x6D, 0x8D, 0xD5, 0x4E, 0xA9, 0x6C, 0x56, 0xF4, 0xEA, 0x65, 0x7A, 0xAE, 0x08,
    0xBA, 0x78, 0x25, 0x2E, 0x1C, 0xA6, 0xB4, 0xC6, 0xE8, 0xDD, 0x74, 0x1F, 0x4B, 0xBD, 0x8B, 0x8A,
    0x70, 0x3E, 0xB5, 0x66, 0x48, 0x03, 0xF6, 0x0E, 0x61, 0x35, 0x57, 0xB9, 0x86, 0xC1, 0x1D, 0x9E,
    0xE1, 0xF8, 0x98, 0x11, 0x69, 0xD9, 0x8E, 0x94, 0x9B, 0x1E, 0x87, 0xE9, 0xCE, 0x55, 0x28, 0xDF,
    0x8C, 0xA1, 0x89, 0x0D, 0xBF, 0xE6, 0x42, 0x68, 0x41, 0x99, 0x2D, 0x0F, 0xB0, 0x54, 0xBB, 0x16
};

static const uint32_t rcon_table[10] = {
    0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1B, 0x36
};

static inline uint32_t sub_word(uint32_t w) {
    return ((uint32_t)sbox[w & 0xFF]) |
           (((uint32_t)sbox[(w >> 8) & 0xFF]) << 8) |
           (((uint32_t)sbox[(w >> 16) & 0xFF]) << 16) |
           (((uint32_t)sbox[(w >> 24) & 0xFF]) << 24);
}

static inline uint32_t rot_word(uint32_t w) {
    return (w >> 8) | (w << 24);
}

static void aes256_expand_keys(const uint8_t* key, uint8x16_t drk[15]) {
    uint32_t w[60];
    memcpy(w, key, 32);

    for (int i = 8; i < 60; i++) {
        uint32_t temp = w[i - 1];
        if (i % 8 == 0) {
            temp = sub_word(rot_word(temp)) ^ rcon_table[(i / 8) - 1];
        } else if (i % 8 == 4) {
            temp = sub_word(temp);
        }
        w[i] = w[i - 8] ^ temp;
    }
    
    uint8x16_t rk[15];
    for (int r = 0; r < 15; r++) {
        rk[r] = vld1q_u8((const uint8_t*)&w[r * 4]);
    }
    
    // Equivalent inverse round keys for ARM64 vaesdq_u8
    drk[0] = rk[14];
    for (int r = 1; r < 14; r++) {
        drk[r] = vaesimcq_u8(rk[14 - r]);
    }
    drk[14] = rk[0];
}

// 8-Way Unrolled AES-256-CBC Decryption Kernel (128 bytes per iteration)
static void aes256_cbc_decrypt_block_stream_neon(
    const uint8x16_t drk[15],
    uint8x16_t* iv_state,
    const uint8_t* src,
    size_t size,
    uint8_t* dst
) {
    size_t blocks = size / 16;
    size_t i = 0;
    uint8x16_t iv = *iv_state;

    // 8-way unrolled batch loop (128-byte cache line aligned)
    for (; i + 8 <= blocks; i += 8) {
        const uint8_t* s_ptr = src + i * 16;
        uint8_t* d_ptr = dst + i * 16;

        uint8x16_t c0 = vld1q_u8(s_ptr);
        uint8x16_t c1 = vld1q_u8(s_ptr + 16);
        uint8x16_t c2 = vld1q_u8(s_ptr + 32);
        uint8x16_t c3 = vld1q_u8(s_ptr + 48);
        uint8x16_t c4 = vld1q_u8(s_ptr + 64);
        uint8x16_t c5 = vld1q_u8(s_ptr + 80);
        uint8x16_t c6 = vld1q_u8(s_ptr + 96);
        uint8x16_t c7 = vld1q_u8(s_ptr + 112);

        uint8x16_t b0 = c0;
        uint8x16_t b1 = c1;
        uint8x16_t b2 = c2;
        uint8x16_t b3 = c3;
        uint8x16_t b4 = c4;
        uint8x16_t b5 = c5;
        uint8x16_t b6 = c6;
        uint8x16_t b7 = c7;

        for (int r = 0; r < 13; r++) {
            b0 = vaesimcq_u8(vaesdq_u8(b0, drk[r]));
            b1 = vaesimcq_u8(vaesdq_u8(b1, drk[r]));
            b2 = vaesimcq_u8(vaesdq_u8(b2, drk[r]));
            b3 = vaesimcq_u8(vaesdq_u8(b3, drk[r]));
            b4 = vaesimcq_u8(vaesdq_u8(b4, drk[r]));
            b5 = vaesimcq_u8(vaesdq_u8(b5, drk[r]));
            b6 = vaesimcq_u8(vaesdq_u8(b6, drk[r]));
            b7 = vaesimcq_u8(vaesdq_u8(b7, drk[r]));
        }

        b0 = veorq_u8(vaesdq_u8(b0, drk[13]), drk[14]);
        b1 = veorq_u8(vaesdq_u8(b1, drk[13]), drk[14]);
        b2 = veorq_u8(vaesdq_u8(b2, drk[13]), drk[14]);
        b3 = veorq_u8(vaesdq_u8(b3, drk[13]), drk[14]);
        b4 = veorq_u8(vaesdq_u8(b4, drk[13]), drk[14]);
        b5 = veorq_u8(vaesdq_u8(b5, drk[13]), drk[14]);
        b6 = veorq_u8(vaesdq_u8(b6, drk[13]), drk[14]);
        b7 = veorq_u8(vaesdq_u8(b7, drk[13]), drk[14]);

        // CBC feedback XOR
        vst1q_u8(d_ptr, veorq_u8(b0, iv));
        vst1q_u8(d_ptr + 16, veorq_u8(b1, c0));
        vst1q_u8(d_ptr + 32, veorq_u8(b2, c1));
        vst1q_u8(d_ptr + 48, veorq_u8(b3, c2));
        vst1q_u8(d_ptr + 64, veorq_u8(b4, c3));
        vst1q_u8(d_ptr + 80, veorq_u8(b5, c4));
        vst1q_u8(d_ptr + 96, veorq_u8(b6, c5));
        vst1q_u8(d_ptr + 112, veorq_u8(b7, c6));

        iv = c7;
    }

    // 1-way tail loop
    for (; i < blocks; i++) {
        const uint8_t* s_ptr = src + i * 16;
        uint8_t* d_ptr = dst + i * 16;
        uint8x16_t c0 = vld1q_u8(s_ptr);
        uint8x16_t b0 = c0;

        for (int r = 0; r < 13; r++) {
            b0 = vaesimcq_u8(vaesdq_u8(b0, drk[r]));
        }
        b0 = veorq_u8(vaesdq_u8(b0, drk[13]), drk[14]);

        vst1q_u8(d_ptr, veorq_u8(b0, iv));
        iv = c0;
    }

    *iv_state = iv;
}

typedef struct {
    uint8x16_t drk[15];
    uint8x16_t initial_iv;
    const uint8_t* src;
    uint8_t* dst;
    size_t size;
    size_t chunk_size;
} aes_parallel_chunk_arg_t;

static void aes_parallel_chunk_worker(size_t i, void* arg) {
    aes_parallel_chunk_arg_t* ctx = (aes_parallel_chunk_arg_t*)arg;
    size_t offset = i * ctx->chunk_size;
    size_t cur_len = (offset + ctx->chunk_size <= ctx->size) ? ctx->chunk_size : (ctx->size - offset);
    if (cur_len % 16 != 0) cur_len = (cur_len / 16) * 16;
    if (cur_len == 0) return;

    uint8x16_t chunk_iv = (i == 0) ? ctx->initial_iv : vld1q_u8(ctx->src + offset - 16);
    aes256_cbc_decrypt_block_stream_neon(ctx->drk, &chunk_iv, ctx->src + offset, cur_len, ctx->dst + offset);
}

#endif // __ARM_NEON

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

#if defined(__ARM_NEON) || defined(__ARM_NEON__) || defined(__aarch64__)
    uint8x16_t drk[15];
    aes256_expand_keys(key, drk);

    uint8_t default_iv[16] = {0};
    uint8x16_t iv_vec = vld1q_u8(iv ? iv : default_iv);

    if (size < 64 * 1024) {
        aes256_cbc_decrypt_block_stream_neon(drk, &iv_vec, src, size, dst);
        return 0;
    }

    // Parallel multi-core dispatch on P-cores (128KB chunk size)
    size_t chunk_size = 128 * 1024;
    size_t num_chunks = (size + chunk_size - 1) / chunk_size;

    aes_parallel_chunk_arg_t worker_arg = {
        .initial_iv = iv_vec,
        .src = src,
        .dst = dst,
        .size = size,
        .chunk_size = chunk_size
    };
    memcpy(worker_arg.drk, drk, sizeof(drk));

    ttzip_parallel_for_qos(ttzip_threadpool_shared_p(), num_chunks, aes_parallel_chunk_worker, &worker_arg, TTZIP_QOS_PERFORMANCE);
    return 0;
#else
    return -1;
#endif
}
