// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/CTTZipBridge_Crypto.h"
#include "include/CTTZipBridge.h"
#include "include/CTTZipCommon.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <CommonCrypto/CommonCrypto.h>
#include <CommonCrypto/CommonKeyDerivation.h>
#include "include/ttzip_threadpool.h"

#if defined(__ARM_NEON) || defined(__ARM_NEON__) || defined(__aarch64__)
#include <arm_neon.h>
static const uint8_t TTZIP_RCON[15] = { 0x00, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1B, 0x36, 0x6C, 0xD8, 0xAB, 0x4D };

static const uint8_t TTZIP_SBOX[256] = {
    0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b, 0xfe, 0xd7, 0xab, 0x76,
    0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0, 0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0,
    0xb7, 0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15,
    0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80, 0xe2, 0xeb, 0x27, 0xb2, 0x75,
    0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0, 0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84,
    0x53, 0xd1, 0x00, 0xed, 0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf,
    0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f, 0x50, 0x3c, 0x9f, 0xa8,
    0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5, 0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2,
    0xcd, 0x0c, 0x13, 0xec, 0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73,
    0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8, 0x14, 0xde, 0x5e, 0x0b, 0xdb,
    0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5c, 0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79,
    0xe7, 0xc8, 0x37, 0x6d, 0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08,
    0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f, 0x4b, 0xbd, 0x8b, 0x8a,
    0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e,
    0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf,
    0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f, 0xb0, 0x54, 0xbb, 0x16
};
static inline uint32_t ttzip_sub_word(uint32_t w) {
    return ((uint32_t)TTZIP_SBOX[w & 0xFF]) |
           (((uint32_t)TTZIP_SBOX[(w >> 8) & 0xFF]) << 8) |
           (((uint32_t)TTZIP_SBOX[(w >> 16) & 0xFF]) << 16) |
           (((uint32_t)TTZIP_SBOX[(w >> 24) & 0xFF]) << 24);
}
static inline uint32_t ttzip_rot_word(uint32_t w) {
    return (w >> 8) | (w << 24);
}
static inline void ttzip_aes256_expand_keys(const uint8_t* key, uint8x16_t rk[15]) {
    uint32_t w[60];
    for (int i = 0; i < 8; i++) {
        w[i] = ((uint32_t)key[i*4]) | (((uint32_t)key[i*4+1]) << 8) | (((uint32_t)key[i*4+2]) << 16) | (((uint32_t)key[i*4+3]) << 24);
    }
    for (int i = 8; i < 60; i++) {
        uint32_t temp = w[i - 1];
        if (i % 8 == 0) {
            temp = ttzip_sub_word(ttzip_rot_word(temp)) ^ (uint32_t)TTZIP_RCON[i / 8];
        } else if (i % 8 == 4) {
            temp = ttzip_sub_word(temp);
        }
        w[i] = w[i - 8] ^ temp;
    }
    for (int i = 0; i < 15; i++) {
        uint32_t raw_rk[4] = { w[i*4], w[i*4+1], w[i*4+2], w[i*4+3] };
        rk[i] = vld1q_u8((const uint8_t*)raw_rk);
    }
}

static void ttzip_aes256_ctr_neon_chunk(
    const uint8x16_t rk[15],
    uint64_t initial_counter,
    const uint8_t* src,
    size_t len,
    uint8_t* dst,
    size_t start_block,
    size_t count_blocks
) {
    size_t byte_offset = start_block * 16;
    const uint8_t* s_ptr = src + byte_offset;
    uint8_t* d_ptr = dst + byte_offset;

    size_t i = 0;
    for (; i + 8 <= count_blocks; i += 8) {
        uint64_t c0 = initial_counter + start_block + i;
        uint64_t c1 = initial_counter + start_block + i + 1;
        uint64_t c2 = initial_counter + start_block + i + 2;
        uint64_t c3 = initial_counter + start_block + i + 3;
        uint64_t c4 = initial_counter + start_block + i + 4;
        uint64_t c5 = initial_counter + start_block + i + 5;
        uint64_t c6 = initial_counter + start_block + i + 6;
        uint64_t c7 = initial_counter + start_block + i + 7;

        uint64_t ctr0[2] = { c0, 0 };
        uint64_t ctr1[2] = { c1, 0 };
        uint64_t ctr2[2] = { c2, 0 };
        uint64_t ctr3[2] = { c3, 0 };
        uint64_t ctr4[2] = { c4, 0 };
        uint64_t ctr5[2] = { c5, 0 };
        uint64_t ctr6[2] = { c6, 0 };
        uint64_t ctr7[2] = { c7, 0 };

        uint8x16_t b0 = vld1q_u8((const uint8_t*)ctr0);
        uint8x16_t b1 = vld1q_u8((const uint8_t*)ctr1);
        uint8x16_t b2 = vld1q_u8((const uint8_t*)ctr2);
        uint8x16_t b3 = vld1q_u8((const uint8_t*)ctr3);
        uint8x16_t b4 = vld1q_u8((const uint8_t*)ctr4);
        uint8x16_t b5 = vld1q_u8((const uint8_t*)ctr5);
        uint8x16_t b6 = vld1q_u8((const uint8_t*)ctr6);
        uint8x16_t b7 = vld1q_u8((const uint8_t*)ctr7);

        for (int r = 0; r < 13; r++) {
            b0 = vaesmcq_u8(vaeseq_u8(b0, rk[r]));
            b1 = vaesmcq_u8(vaeseq_u8(b1, rk[r]));
            b2 = vaesmcq_u8(vaeseq_u8(b2, rk[r]));
            b3 = vaesmcq_u8(vaeseq_u8(b3, rk[r]));
            b4 = vaesmcq_u8(vaeseq_u8(b4, rk[r]));
            b5 = vaesmcq_u8(vaeseq_u8(b5, rk[r]));
            b6 = vaesmcq_u8(vaeseq_u8(b6, rk[r]));
            b7 = vaesmcq_u8(vaeseq_u8(b7, rk[r]));
        }

        b0 = veorq_u8(vaeseq_u8(b0, rk[13]), rk[14]);
        b1 = veorq_u8(vaeseq_u8(b1, rk[13]), rk[14]);
        b2 = veorq_u8(vaeseq_u8(b2, rk[13]), rk[14]);
        b3 = veorq_u8(vaeseq_u8(b3, rk[13]), rk[14]);
        b4 = veorq_u8(vaeseq_u8(b4, rk[13]), rk[14]);
        b5 = veorq_u8(vaeseq_u8(b5, rk[13]), rk[14]);
        b6 = veorq_u8(vaeseq_u8(b6, rk[13]), rk[14]);
        b7 = veorq_u8(vaeseq_u8(b7, rk[13]), rk[14]);

        size_t block_offset = i * 16;
        size_t rem = (byte_offset + block_offset + 128 <= len) ? 128 : (len - (byte_offset + block_offset));

        if (rem == 128) {
            uint8x16_t s0 = vld1q_u8(s_ptr + block_offset);
            uint8x16_t s1 = vld1q_u8(s_ptr + block_offset + 16);
            uint8x16_t s2 = vld1q_u8(s_ptr + block_offset + 32);
            uint8x16_t s3 = vld1q_u8(s_ptr + block_offset + 48);
            uint8x16_t s4 = vld1q_u8(s_ptr + block_offset + 64);
            uint8x16_t s5 = vld1q_u8(s_ptr + block_offset + 80);
            uint8x16_t s6 = vld1q_u8(s_ptr + block_offset + 96);
            uint8x16_t s7 = vld1q_u8(s_ptr + block_offset + 112);

            vst1q_u8(d_ptr + block_offset, veorq_u8(s0, b0));
            vst1q_u8(d_ptr + block_offset + 16, veorq_u8(s1, b1));
            vst1q_u8(d_ptr + block_offset + 32, veorq_u8(s2, b2));
            vst1q_u8(d_ptr + block_offset + 48, veorq_u8(s3, b3));
            vst1q_u8(d_ptr + block_offset + 64, veorq_u8(s4, b4));
            vst1q_u8(d_ptr + block_offset + 80, veorq_u8(s5, b5));
            vst1q_u8(d_ptr + block_offset + 96, veorq_u8(s6, b6));
            vst1q_u8(d_ptr + block_offset + 112, veorq_u8(s7, b7));
        } else {
            uint8_t ks[128];
            vst1q_u8(ks, b0);
            vst1q_u8(ks + 16, b1);
            vst1q_u8(ks + 32, b2);
            vst1q_u8(ks + 48, b3);
            vst1q_u8(ks + 64, b4);
            vst1q_u8(ks + 80, b5);
            vst1q_u8(ks + 96, b6);
            vst1q_u8(ks + 112, b7);
            for (size_t k = 0; k < rem; k++) {
                d_ptr[block_offset + k] = s_ptr[block_offset + k] ^ ks[k];
            }
        }
    }

    for (; i < count_blocks; i++) {
        uint64_t c0 = initial_counter + start_block + i;
        uint64_t ctr0[2] = { c0, 0 };
        uint8x16_t b0 = vld1q_u8((const uint8_t*)ctr0);
        for (int r = 0; r < 13; r++) {
            b0 = vaesmcq_u8(vaeseq_u8(b0, rk[r]));
        }
        b0 = veorq_u8(vaeseq_u8(b0, rk[13]), rk[14]);

        size_t block_offset = i * 16;
        size_t rem = (byte_offset + block_offset + 16 <= len) ? 16 : (len - (byte_offset + block_offset));
        if (rem == 16) {
            uint8x16_t s0 = vld1q_u8(s_ptr + block_offset);
            vst1q_u8(d_ptr + block_offset, veorq_u8(s0, b0));
        } else {
            uint8_t ks[16];
            vst1q_u8(ks, b0);
            for (size_t k = 0; k < rem; k++) {
                d_ptr[block_offset + k] = s_ptr[block_offset + k] ^ ks[k];
            }
        }
    }
}
#endif

int ttzip_pbkdf2_sha1_fast(
    const char* password,
    size_t pass_len,
    const uint8_t* salt,
    size_t salt_len,
    uint32_t rounds,
    uint8_t* out_key,
    size_t key_len
) {
    if (!password || !salt || !out_key || key_len == 0 || rounds == 0) return TTZIP_ERR_INVALID_PARAM;

    uint8_t k_ipad[64];
    uint8_t k_opad[64];
    memset(k_ipad, 0x36, 64);
    memset(k_opad, 0x5c, 64);

    uint8_t key_pad[64];
    memset(key_pad, 0, 64);
    if (pass_len > 64) {
        CC_SHA1(password, (CC_LONG)pass_len, key_pad);
    } else {
        memcpy(key_pad, password, pass_len);
    }

    for (int i = 0; i < 64; i++) {
        k_ipad[i] ^= key_pad[i];
        k_opad[i] ^= key_pad[i];
    }

    CC_SHA1_CTX pre_ipad;
    CC_SHA1_Init(&pre_ipad);
    CC_SHA1_Update(&pre_ipad, k_ipad, 64);

    CC_SHA1_CTX pre_opad;
    CC_SHA1_Init(&pre_opad);
    CC_SHA1_Update(&pre_opad, k_opad, 64);

    size_t blocks_needed = (key_len + 19) / 20;
    uint8_t u_digest[20];
    uint8_t t_digest[20];

    for (uint32_t block_idx = 1; block_idx <= (uint32_t)blocks_needed; block_idx++) {
        uint8_t be_block[4];
        be_block[0] = (uint8_t)((block_idx >> 24) & 0xff);
        be_block[1] = (uint8_t)((block_idx >> 16) & 0xff);
        be_block[2] = (uint8_t)((block_idx >> 8) & 0xff);
        be_block[3] = (uint8_t)(block_idx & 0xff);

        CC_SHA1_CTX inner = pre_ipad;
        CC_SHA1_Update(&inner, salt, (CC_LONG)salt_len);
        CC_SHA1_Update(&inner, be_block, 4);
        uint8_t inner_hash[20];
        CC_SHA1_Final(inner_hash, &inner);

        CC_SHA1_CTX outer = pre_opad;
        CC_SHA1_Update(&outer, inner_hash, 20);
        CC_SHA1_Final(u_digest, &outer);

        memcpy(t_digest, u_digest, 20);

        uint8_t inner_block[64];
        memset(inner_block, 0, 64);
        inner_block[20] = 0x80;
        inner_block[62] = 0x02;
        inner_block[63] = 0xa0;

        uint8_t outer_block[64];
        memset(outer_block, 0, 64);
        outer_block[20] = 0x80;
        outer_block[62] = 0x02;
        outer_block[63] = 0xa0;

        for (uint32_t r = 1; r < rounds; r++) {
            memcpy(inner_block, u_digest, 20);
            CC_SHA1_CTX inner = pre_ipad;
            CC_SHA1_Update(&inner, inner_block, 64);
            
            *(uint32_t*)(outer_block + 0)  = __builtin_bswap32(inner.h0);
            *(uint32_t*)(outer_block + 4)  = __builtin_bswap32(inner.h1);
            *(uint32_t*)(outer_block + 8)  = __builtin_bswap32(inner.h2);
            *(uint32_t*)(outer_block + 12) = __builtin_bswap32(inner.h3);
            *(uint32_t*)(outer_block + 16) = __builtin_bswap32(inner.h4);

            CC_SHA1_CTX outer = pre_opad;
            CC_SHA1_Update(&outer, outer_block, 64);

            *(uint32_t*)(u_digest + 0)  = __builtin_bswap32(outer.h0);
            *(uint32_t*)(u_digest + 4)  = __builtin_bswap32(outer.h1);
            *(uint32_t*)(u_digest + 8)  = __builtin_bswap32(outer.h2);
            *(uint32_t*)(u_digest + 12) = __builtin_bswap32(outer.h3);
            *(uint32_t*)(u_digest + 16) = __builtin_bswap32(outer.h4);

            for (int k = 0; k < 20; k++) {
                t_digest[k] ^= u_digest[k];
            }
        }

        size_t offset = (block_idx - 1) * 20;
        size_t copy_bytes = (offset + 20 <= key_len) ? 20 : (key_len - offset);
        memcpy(out_key + offset, t_digest, copy_bytes);
    }

    ttzip_secure_zero(key_pad, sizeof(key_pad));
    ttzip_secure_zero(k_ipad, sizeof(k_ipad));
    ttzip_secure_zero(k_opad, sizeof(k_opad));
    ttzip_secure_zero(u_digest, sizeof(u_digest));
    ttzip_secure_zero(t_digest, sizeof(t_digest));

    return TTZIP_OK;
}

int ttzip_pbkdf2_sha256_fast(
    const char* password,
    size_t pass_len,
    const uint8_t* salt,
    size_t salt_len,
    uint32_t rounds,
    uint8_t* out_key,
    size_t key_len
) {
    if (!password || !salt || !out_key || key_len == 0 || rounds == 0) return TTZIP_ERR_INVALID_PARAM;
    int status = CCKeyDerivationPBKDF(
        kCCPBKDF2,
        password,
        pass_len,
        salt,
        salt_len,
        kCCPRFHmacAlgSHA256,
        rounds,
        out_key,
        key_len
    );
    return (status == kCCSuccess) ? TTZIP_OK : TTZIP_ERR_INVALID_PARAM;
}

#if defined(__ARM_NEON) || defined(__ARM_NEON__) || defined(__aarch64__)
typedef struct {
    const uint8x16_t* rk_ptr;
    uint64_t initial_block_count;
    const uint8_t* src;
    size_t length;
    uint8_t* dst;
    size_t chunk_blocks;
    size_t num_blocks;
} aes_ctr_arg_t;

static void aes_ctr_chunk_worker(size_t chunk_idx, void* user_data) {
    aes_ctr_arg_t* ctx = (aes_ctr_arg_t*)user_data;
    size_t start = chunk_idx * ctx->chunk_blocks;
    size_t count = (start + ctx->chunk_blocks <= ctx->num_blocks) ? ctx->chunk_blocks : (ctx->num_blocks - start);
    ttzip_aes256_ctr_neon_chunk(ctx->rk_ptr, ctx->initial_block_count, ctx->src, ctx->length, ctx->dst, start, count);
}
#endif

int ttzip_aes256_ctr_crypt(
    const uint8_t* key,
    uint64_t initial_block_count,
    const uint8_t* src,
    size_t length,
    uint8_t* dst
) {
    if (!key || !src || !dst || length == 0) return TTZIP_ERR_INVALID_PARAM;
    
#if defined(__ARM_NEON) || defined(__ARM_NEON__) || defined(__aarch64__)
    uint8x16_t rk[15];
    ttzip_aes256_expand_keys(key, rk);
    const uint8x16_t* rk_ptr = rk;

    size_t num_blocks = (length + 15) / 16;
    size_t chunk_blocks = 4096; // 64KB chunks for optimal CPU multi-core scaling and L1/L2 cache locality
    size_t total_chunks = (num_blocks + chunk_blocks - 1) / chunk_blocks;

    if (total_chunks <= 1) {
        ttzip_aes256_ctr_neon_chunk(rk_ptr, initial_block_count, src, length, dst, 0, num_blocks);
    } else {
        aes_ctr_arg_t arg = {
            .rk_ptr = rk_ptr,
            .initial_block_count = initial_block_count,
            .src = src,
            .length = length,
            .dst = dst,
            .chunk_blocks = chunk_blocks,
            .num_blocks = num_blocks
        };

        ttzip_parallel_for(ttzip_threadpool_shared(), total_chunks, aes_ctr_chunk_worker, &arg);
    }
    return TTZIP_OK;
#else
    return TTZIP_ERR_INVALID_PARAM;
#endif
}

int ttzip_aes256_ctr_crypt_parallel(
    const uint8_t* key,
    const uint8_t* src,
    size_t length,
    uint8_t* dst,
    int threads
) {
    (void)threads;
    return ttzip_aes256_ctr_crypt(key, 1, src, length, dst);
}

int ttzip_compute_hmac_sha1_fast(
    const uint8_t* key,
    size_t key_len,
    const uint8_t* data,
    size_t data_len,
    uint8_t out_mac[10]
) {
    if (!key || !data || !out_mac) return TTZIP_ERR_INVALID_PARAM;
    uint8_t full_mac[20];
    CCHmac(kCCHmacAlgSHA1, key, key_len, data, data_len, full_mac);
    memcpy(out_mac, full_mac, 10);
    return TTZIP_OK;
}

int ttzip_aes256_encrypt_and_hmac_fused(
    const uint8_t derived_keys[66],
    const uint8_t* src,
    size_t length,
    uint8_t* dst_cipher,
    uint8_t out_mac[10]
) {
    if (!derived_keys || !src || !dst_cipher || !out_mac) return TTZIP_ERR_INVALID_PARAM;
    int res = ttzip_aes256_ctr_crypt(derived_keys, 1, src, length, dst_cipher);
    if (res != TTZIP_OK) return res;
    return ttzip_compute_hmac_sha1_fast(derived_keys + 32, 32, dst_cipher, length, out_mac);
}

typedef struct {
    uint8_t salt[16];
    uint32_t pwd_hash;
    uint8_t derived_keys[66];
    bool valid;
} ttzip_tls_key_cache_t;

static __thread ttzip_tls_key_cache_t s_tls_kcache[8];
static __thread size_t s_tls_kcache_pos = 0;

static inline uint32_t ttzip_quick_pwd_hash(const char* s, size_t len) {
    uint32_t h = 2166136261u;
    for (size_t i = 0; i < len; i++) {
        h = (h ^ (uint8_t)s[i]) * 16777619u;
    }
    return h;
}

int ttzip_aes256_decrypt_and_verify(
    const char* password,
    const uint8_t* enc_payload,
    size_t payload_size,
    uint8_t* out_plain,
    size_t* out_plain_len
) {
    if (!password || !enc_payload || payload_size < 28 || !out_plain) return TTZIP_ERR_INVALID_PARAM;
    const uint8_t* salt = enc_payload;
    uint8_t pwd_check_stored[2] = { enc_payload[16], enc_payload[17] };
    size_t cipher_len = payload_size - 18 - 10;
    const uint8_t* ciphertext = enc_payload + 18;
    const uint8_t* mac_stored = enc_payload + 18 + cipher_len;

    uint8_t derived_keys[66];
    size_t pass_len = strlen(password);
    uint32_t phash = ttzip_quick_pwd_hash(password, pass_len);
    bool cache_hit = false;
    for (int ci = 0; ci < 8; ci++) {
        if (s_tls_kcache[ci].valid && s_tls_kcache[ci].pwd_hash == phash && memcmp(s_tls_kcache[ci].salt, salt, 16) == 0) {
            memcpy(derived_keys, s_tls_kcache[ci].derived_keys, 66);
            cache_hit = true;
            break;
        }
    }

    if (!cache_hit) {
        if (ttzip_pbkdf2_sha1_fast(password, pass_len, salt, 16, 1000, derived_keys, 66) != 0) {
            return TTZIP_ERR_INVALID_PASSWORD;
        }
        size_t slot = (s_tls_kcache_pos++) & 7;
        memcpy(s_tls_kcache[slot].salt, salt, 16);
        s_tls_kcache[slot].pwd_hash = phash;
        memcpy(s_tls_kcache[slot].derived_keys, derived_keys, 66);
        s_tls_kcache[slot].valid = true;
    }

    if (derived_keys[64] != pwd_check_stored[0] || derived_keys[65] != pwd_check_stored[1]) {
        ttzip_secure_zero(derived_keys, sizeof(derived_keys));
        return TTZIP_ERR_INVALID_PASSWORD;
    }

    uint8_t mac_computed[10];
    if (ttzip_compute_hmac_sha1_fast(derived_keys + 32, 32, ciphertext, cipher_len, mac_computed) != 0) {
        ttzip_secure_zero(derived_keys, sizeof(derived_keys));
        return TTZIP_ERR_CORRUPT_HEADER;
    }
    if (memcmp(mac_computed, mac_stored, 10) != 0) {
        ttzip_secure_zero(derived_keys, sizeof(derived_keys));
        return TTZIP_ERR_CORRUPT_HEADER;
    }

    int res = ttzip_aes256_ctr_crypt(derived_keys, 1, ciphertext, cipher_len, out_plain);
    ttzip_secure_zero(derived_keys, sizeof(derived_keys));
    if (res == TTZIP_OK && out_plain_len) {
        *out_plain_len = cipher_len;
    }
    return res;
}

int ttzip_aes256_cbc_decrypt_neon(
    const uint8_t* key,
    const uint8_t iv[16],
    const uint8_t* src,
    size_t length,
    uint8_t* dst
) {
    if (!key || !src || !dst || (length % 16 != 0)) return TTZIP_ERR_INVALID_PARAM;
    size_t out_moved = 0;
    CCCryptorStatus status = CCCrypt(
        kCCDecrypt,
        kCCAlgorithmAES,
        0, // No padding (raw CBC)
        key,
        kCCKeySizeAES256,
        iv,
        src,
        length,
        dst,
        length,
        &out_moved
    );
    return (status == kCCSuccess) ? TTZIP_OK : TTZIP_ERR_INVALID_PARAM;
}

int ttzip_aes256_cbc_encrypt(
    const uint8_t* key,
    const uint8_t iv[16],
    const uint8_t* src,
    size_t length,
    uint8_t* dst
) {
    if (!key || !src || !dst || (length % 16 != 0)) return TTZIP_ERR_INVALID_PARAM;
    size_t out_moved = 0;
    CCCryptorStatus status = CCCrypt(
        kCCEncrypt,
        kCCAlgorithmAES,
        0, // No padding (raw CBC)
        key,
        kCCKeySizeAES256,
        iv,
        src,
        length,
        dst,
        length,
        &out_moved
    );
    return (status == kCCSuccess) ? TTZIP_OK : TTZIP_ERR_INVALID_PARAM;
}

static uint8_t* convert_utf8_to_utf16le(const char* utf8, size_t* out_bytes) {
    if (!utf8) return NULL;
    size_t len = strlen(utf8);
    uint16_t* utf16_buf = (uint16_t*)malloc(sizeof(uint16_t) * (len * 2 + 2));
    if (!utf16_buf) return NULL;

    size_t out_len = 0;
    const uint8_t* p = (const uint8_t*)utf8;
    while (*p) {
        uint32_t cp = 0;
        if ((*p & 0x80) == 0) {
            cp = *p++;
        } else if ((*p & 0xE0) == 0xC0) {
            cp = (*p++ & 0x1F) << 6;
            if (*p) cp |= (*p++ & 0x3F);
        } else if ((*p & 0xF0) == 0xE0) {
            cp = (*p++ & 0x0F) << 12;
            if (*p) cp |= (*p++ & 0x3F) << 6;
            if (*p) cp |= (*p++ & 0x3F);
        } else if ((*p & 0xF8) == 0xF0) {
            cp = (*p++ & 0x07) << 18;
            if (*p) cp |= (*p++ & 0x3F) << 12;
            if (*p) cp |= (*p++ & 0x3F) << 6;
            if (*p) cp |= (*p++ & 0x3F);
        } else {
            p++;
            continue;
        }

        if (cp < 0x10000) {
            utf16_buf[out_len++] = (uint16_t)cp;
        } else {
            cp -= 0x10000;
            utf16_buf[out_len++] = (uint16_t)(0xD800 + (cp >> 10));
            utf16_buf[out_len++] = (uint16_t)(0xDC00 + (cp & 0x3FF));
        }
    }

    size_t byte_count = out_len * 2;
    uint8_t* res = (uint8_t*)malloc(byte_count > 0 ? byte_count : 2);
    if (!res) {
        free(utf16_buf);
        return NULL;
    }
    for (size_t i = 0; i < out_len; i++) {
        uint16_t val = utf16_buf[i];
        res[i * 2] = (uint8_t)(val & 0xFF);
        res[i * 2 + 1] = (uint8_t)((val >> 8) & 0xFF);
    }
    memset_s(utf16_buf, sizeof(uint16_t) * (len * 2 + 2), 0, sizeof(uint16_t) * (len * 2 + 2));
    free(utf16_buf);
    *out_bytes = byte_count;
    return res;
}

int ttzip_7z_kdf_sha256(
    const char* password,
    const uint8_t* salt,
    size_t salt_len,
    uint32_t num_cycles_power,
    uint8_t out_key[32]
) {
    if (!password || !out_key) return TTZIP_ERR_INVALID_PARAM;
    size_t utf16_len = 0;
    uint8_t* utf16_pass = convert_utf8_to_utf16le(password, &utf16_len);
    if (!utf16_pass) return TTZIP_ERR_INVALID_PARAM;

    uint64_t num_cycles = (1ULL << num_cycles_power);
    CC_SHA256_CTX ctx;
    CC_SHA256_Init(&ctx);

    size_t buf_len = salt_len + utf16_len;
    uint8_t* buf = (uint8_t*)malloc(buf_len > 0 ? buf_len : 1);
    if (!buf) {
        memset_s(utf16_pass, utf16_len, 0, utf16_len);
        free(utf16_pass);
        return TTZIP_ERR_INVALID_PARAM;
    }
    if (salt_len > 0 && salt) {
        memcpy(buf, salt, salt_len);
    }
    if (utf16_len > 0) {
        memcpy(buf + salt_len, utf16_pass, utf16_len);
    }

    for (uint64_t i = 0; i < num_cycles; i++) {
        CC_SHA256_Update(&ctx, buf, buf_len);
        uint8_t counter[8];
        counter[0] = (uint8_t)(i & 0xFF);
        counter[1] = (uint8_t)((i >> 8) & 0xFF);
        counter[2] = (uint8_t)((i >> 16) & 0xFF);
        counter[3] = (uint8_t)((i >> 24) & 0xFF);
        counter[4] = (uint8_t)((i >> 32) & 0xFF);
        counter[5] = (uint8_t)((i >> 40) & 0xFF);
        counter[6] = (uint8_t)((i >> 48) & 0xFF);
        counter[7] = (uint8_t)((i >> 56) & 0xFF);
        CC_SHA256_Update(&ctx, counter, 8);
    }
    CC_SHA256_Final(out_key, &ctx);

    memset_s(utf16_pass, utf16_len, 0, utf16_len);
    free(utf16_pass);
    memset_s(buf, buf_len, 0, buf_len);
    free(buf);
    return TTZIP_OK;
}
