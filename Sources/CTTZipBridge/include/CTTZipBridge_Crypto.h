#ifndef CTTZipBridge_Crypto_h
#define CTTZipBridge_Crypto_h

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

int ttzip_pbkdf2_sha1_fast(
    const char* password,
    size_t pass_len,
    const uint8_t* salt,
    size_t salt_len,
    uint32_t rounds,
    uint8_t* out_key,
    size_t key_len
);

int ttzip_pbkdf2_sha256_fast(
    const char* password,
    size_t pass_len,
    const uint8_t* salt,
    size_t salt_len,
    uint32_t rounds,
    uint8_t* out_key,
    size_t key_len
);

int ttzip_aes256_ctr_crypt(
    const uint8_t* key,
    uint64_t initial_block_count,
    const uint8_t* src,
    size_t length,
    uint8_t* dst
);

int ttzip_aes256_ctr_crypt_parallel(
    const uint8_t* key,
    const uint8_t* src,
    size_t length,
    uint8_t* dst,
    int threads
);

int ttzip_compute_hmac_sha1_fast(
    const uint8_t* key,
    size_t key_len,
    const uint8_t* data,
    size_t data_len,
    uint8_t out_mac[10]
);

int ttzip_aes256_encrypt_and_hmac_fused(
    const uint8_t derived_keys[66],
    const uint8_t* src,
    size_t length,
    uint8_t* dst_cipher,
    uint8_t out_mac[10]
);

int ttzip_aes256_decrypt_and_verify(
    const char* password,
    const uint8_t* enc_payload,
    size_t payload_size,
    uint8_t* out_plain,
    size_t* out_plain_len
);

int ttzip_aes256_cbc_decrypt_neon(
    const uint8_t* key,
    const uint8_t iv[16],
    const uint8_t* src,
    size_t length,
    uint8_t* dst
);

int ttzip_aes256_cbc_encrypt(
    const uint8_t* key,
    const uint8_t iv[16],
    const uint8_t* src,
    size_t length,
    uint8_t* dst
);

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

#endif // CTTZipBridge_Crypto_h
