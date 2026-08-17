#ifndef TTZIP_BCJ_ARM64_NEON_H
#define TTZIP_BCJ_ARM64_NEON_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/// ARM64 NEON 向量化 BCJ 编码过滤器 (将相对 B/BL 跳转转换为绝对 PC 偏移)
size_t ttzip_arm64_bcj_encode_neon(uint8_t* data, size_t size, uint32_t ip);

/// ARM64 NEON 向量化 BCJ 解码过滤器 (将绝对 PC 偏移还原为相对 B/BL 跳转)
size_t ttzip_arm64_bcj_decode_neon(uint8_t* data, size_t size, uint32_t ip);

#ifdef __cplusplus
}
#endif

#endif // TTZIP_BCJ_ARM64_NEON_H
