/**
 * @file ttzip_7z_block_decoder.h
 * @brief 7z 载荷分块并发解码器与过滤器调度抽象
 * @details 对标 libarchive `archive_read_support_format_7zip.c`，
 *          支持 LZMA2, Zstd, Direct Copy 分块流式解码与原子错误传播。
 * @version 4.0
 * @author TTZip Core Engineering Team
 */

#ifndef TTZIP_7Z_BLOCK_DECODER_H
#define TTZIP_7Z_BLOCK_DECODER_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    const uint8_t* pack_ptr;
    size_t pack_size;
    size_t unpack_offset;
    size_t unpack_size;
} ttzip_7z_dec_chunk_t;

/**
 * @brief 执行 7Z 载荷多块并发解压 (支持 LZMA2 / Zstd / Direct Copy)
 * 
 * @param[in]  payload_start          压缩载荷起始数据指针
 * @param[in]  payload_len            压缩载荷字节长度
 * @param[in]  primary_method_id      主解码方法 ID (0x00=Copy, 0x21=LZMA2, 0x04F71101=Zstd)
 * @param[in]  stream_sizes           各流未压缩尺寸数组 (可选，无则传 NULL)
 * @param[in]  num_stream_sizes       流尺寸数组元素个数
 * @param[in]  coder_unpack_sizes     Coder 声明的未压缩尺寸数组 (可选)
 * @param[in]  num_coder_unpack_sizes Coder 尺寸数组元素个数
 * @param[out] out_unpack_buf         解压后连续缓冲区输出指针
 * @param[out] out_total_unpacked     实际解压出的总字节数
 * 
 * @return TTZIP_OK (0) 成功；负数表示错误码
 * 
 * @note [Ownership] 调用方拥有 `*out_unpack_buf` 的所有权，必须调用 `ttzip_platform_aligned_free()` 释放
 */
int ttzip_7z_decode_payload_parallel(
    const uint8_t* payload_start,
    size_t payload_len,
    uint64_t primary_method_id,
    const uint8_t* coder_props,
    size_t coder_props_len,
    const uint64_t* stream_sizes,
    size_t num_stream_sizes,
    const uint64_t* coder_unpack_sizes,
    size_t num_coder_unpack_sizes,
    uint8_t** out_unpack_buf,
    size_t* out_total_unpacked
);

#ifdef __cplusplus
}
#endif

#endif /* TTZIP_7Z_BLOCK_DECODER_H */
