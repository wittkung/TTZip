#ifndef TTZIP_LZMA_RADIX_MF_H
#define TTZIP_LZMA_RADIX_MF_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    uint32_t len;
    uint32_t dist;
} ttzip_match_pair_t;

typedef struct {
    uint32_t* head;         // Radix 16-bit prefix table (65536 entries)
    uint32_t* prev;         // Circular offset chain
    uint32_t dict_size;
    uint32_t mask;
    const uint8_t* buffer;
    size_t buf_size;
} ttzip_radix_mf_t;

/// 初始化 Radix 快速匹配查找器
int ttzip_radix_mf_init(ttzip_radix_mf_t* mf, uint32_t dict_size);

/// 释放 Radix 查找器内存
void ttzip_radix_mf_free(ttzip_radix_mf_t* mf);

/// 针对当前 pos 查找最长匹配 (Level 1 极速模式：深度 2，NEON SIMD 比对)
ttzip_match_pair_t ttzip_radix_mf_find_fast(
    ttzip_radix_mf_t* mf,
    const uint8_t* src,
    size_t cur_pos,
    size_t max_len
);

#ifdef __cplusplus
}
#endif

#endif // TTZIP_LZMA_RADIX_MF_H
