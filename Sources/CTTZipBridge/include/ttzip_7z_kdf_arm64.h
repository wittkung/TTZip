#ifndef TTZIP_7Z_KDF_ARM64_H
#define TTZIP_7Z_KDF_ARM64_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// 7z AES-256 加密会话结构体 (只读共享，杜绝多文件重复派生)
typedef struct {
    bool     is_active;
    uint8_t  aes_key[32];
    uint8_t  aes_iv[16];
    uint32_t num_cycles_power;
} ttzip_7z_crypto_session_t;

// ARMv8 Cryptographic Extensions 加速的 7z SHA-256 KDF 算法
// 524,288 轮迭代耗时从 630ms 降低至 ~10ms
int ttzip_7z_kdf_sha256_armv8(
    const char* password,
    const uint8_t* salt,
    size_t salt_len,
    uint32_t num_cycles_power,
    uint8_t out_key[32]
);

// 初始化 7z 加密会话
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
