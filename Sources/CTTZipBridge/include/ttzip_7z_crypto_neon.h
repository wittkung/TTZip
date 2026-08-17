#ifndef TTZIP_7Z_CRYPTO_NEON_H
#define TTZIP_7Z_CRYPTO_NEON_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/// 7z 专属 ARM64 硬件 SHA-256 密钥派生 (Key Derivation Function)
/// 将 UTF-16LE 密码与 Salt 经过 2^num_cycles_power 次 SHA-256 迭代派生出 32 字节 AES-256 Key
int ttzip_7z_kdf_sha256_neon(
    const char* password,
    const uint8_t* salt,
    size_t salt_len,
    uint32_t num_cycles_power,
    uint8_t out_key[32]
);

/// 7z 专属 ARM64 硬件 AES-256-CBC 向量化高速解密
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
