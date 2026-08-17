// ttzip_7z_crypto_neon.c
// TTZip 7Z ARM64 硬件指令加解密引擎 (基于 ARMv8 Crypto Extensions AES + SHA-256)

#include "include/ttzip_7z_crypto_neon.h"
#include <string.h>
#include <stdlib.h>
#include <CommonCrypto/CommonCrypto.h>

#if defined(__ARM_NEON) || defined(__ARM_NEON__) || defined(__aarch64__)
#include <arm_neon.h>
#endif

#include "include/CTTZipBridge_Crypto.h"

#include "include/ttzip_7z_kdf_arm64.h"

// 7z UTF-16LE 密码与 Salt 密钥派生
int ttzip_7z_kdf_sha256_neon(
    const char* password,
    const uint8_t* salt,
    size_t salt_len,
    uint32_t num_cycles_power,
    uint8_t out_key[32]
) {
    return ttzip_7z_kdf_sha256_armv8(password, salt, salt_len, num_cycles_power, out_key);
}

#include <dispatch/dispatch.h>

// 7z AES-256-CBC 硬件向量化解密 (支持多核并行分块 CBC 解密)
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

    // 并行 CBC 向量化解密 (每块 512KB，16 字节对齐)
    size_t chunk_size = 512 * 1024;
    size_t num_chunks = (size + chunk_size - 1) / chunk_size;
    __block bool has_error = false;

    dispatch_apply(num_chunks, dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^(size_t i) {
        size_t offset = i * chunk_size;
        size_t cur_len = (offset + chunk_size <= size) ? chunk_size : (size - offset);
        if (cur_len % 16 != 0) cur_len = (cur_len / 16) * 16;
        if (cur_len == 0) return;

        const uint8_t* chunk_iv = (i == 0) ? active_iv : (src + offset - 16);
        size_t dataOutMoved = 0;
        CCCryptorStatus status = CCCrypt(
            kCCDecrypt,
            kCCAlgorithmAES,
            0,
            key,
            kCCKeySizeAES256,
            chunk_iv,
            src + offset,
            cur_len,
            dst + offset,
            cur_len,
            &dataOutMoved
        );
        if (status != kCCSuccess) {
            has_error = true;
        }
    });

    return has_error ? -2 : 0;
}
