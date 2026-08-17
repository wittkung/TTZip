#ifndef TTZIP_LZMA2_DEC_NATIVE_H
#define TTZIP_LZMA2_DEC_NATIVE_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// 自研 Native Range Coder 解码状态机 (Thread-Local 栈内存对齐)
#define TTZIP_LZMA2_PROBS_COUNT 16384

typedef struct {
    uint16_t probs[TTZIP_LZMA2_PROBS_COUNT];
    uint32_t range;
    uint32_t code;
    uint32_t state;
    uint32_t rep[4];
} ttzip_lzma2_dec_state_t;

// 自研 NEON 向量化 LZMA2 块解码主入口
int ttzip_lzma2_decode_block_native(
    const uint8_t* src,
    size_t src_len,
    uint8_t* dst,
    size_t dst_capacity,
    size_t* out_decompressed_len
);

#ifdef __cplusplus
}
#endif

#endif // TTZIP_LZMA2_DEC_NATIVE_H
