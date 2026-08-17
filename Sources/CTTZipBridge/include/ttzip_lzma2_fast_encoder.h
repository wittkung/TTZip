#ifndef TTZIP_LZMA2_FAST_ENCODER_H
#define TTZIP_LZMA2_FAST_ENCODER_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Fast NEON-accelerated LZMA2 L1 Block Compressor
// Bypasses liblzma for Level 1, achieving max throughput on Apple Silicon.
// Outputs raw LZMA2 block payload into dst.
// Returns 0 on success, non-zero error code on failure.
int ttzip_lzma2_fast_encode(
    const uint8_t* src,
    size_t src_len,
    uint8_t* dst,
    size_t dst_capacity,
    size_t* out_compressed_len,
    uint32_t* out_dict_size
);

int ttzip_lzma2_compress_block_tuned(
    const uint8_t* src,
    size_t src_len,
    uint8_t* dst,
    size_t dst_capacity,
    size_t* out_compressed_len,
    int level,
    bool is_zero_block,
    uint32_t* out_dict_size
);

#ifdef __cplusplus
}
#endif

#endif // TTZIP_LZMA2_FAST_ENCODER_H
