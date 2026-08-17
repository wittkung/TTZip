#ifndef TTZIP_FL2_LZMA2_H
#define TTZIP_FL2_LZMA2_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

#define TTZIP_FL2C_MAGIC 0x464C3243U /* "FL2C" */
#define TTZIP_FL2S_MAGIC 0x464C3253U /* "FL2S" */

/**
 * High-performance Fast-LZMA2 Multi-Threaded Block Compressor.
 * 
 * Routes Level 1 to handwritten ARM64 NEON Fast-Path, and Level 3~9 to Fast-LZMA2 Radix-MF.
 * 
 * @param src Pointer to input data
 * @param src_len Input data length in bytes
 * @param dst Pointer to destination buffer
 * @param dst_capacity Capacity of destination buffer
 * @param out_compressed_len Pointer to store output compressed size
 * @param level Compression level (1 to 9)
 * @param is_zero_block Hint whether input is all zeros (triggers NEON zero-chunk fast path)
 * @param out_dict_size Output pointer for effective dictionary size
 * @param thread_count Number of threads (0 for auto P-Core detection)
 * @return 0 on success, negative error code on failure
 */
int ttzip_fl2_compress_block(
    const uint8_t* src,
    size_t src_len,
    uint8_t* dst,
    size_t dst_capacity,
    size_t* out_compressed_len,
    int level,
    bool is_zero_block,
    uint32_t* out_dict_size,
    int thread_count
);

/**
 * Fast-LZMA2 Streaming Compression API for XZ and TAR.XZ pipelines.
 */
typedef struct ttzip_fl2_stream_ctx_s ttzip_fl2_stream_ctx_t;

ttzip_fl2_stream_ctx_t* ttzip_fl2_stream_create(int level, uint32_t dict_size, int thread_count);

int ttzip_fl2_stream_process(
    ttzip_fl2_stream_ctx_t* ctx,
    const uint8_t* in_data,
    size_t in_size,
    size_t* in_consumed,
    uint8_t* out_buf,
    size_t out_capacity,
    size_t* out_produced,
    bool is_end
);

void ttzip_fl2_stream_free(ttzip_fl2_stream_ctx_t* ctx);

bool ttzip_fl2_is_supported(void);

#ifdef __cplusplus
}
#endif

#endif /* TTZIP_FL2_LZMA2_H */
