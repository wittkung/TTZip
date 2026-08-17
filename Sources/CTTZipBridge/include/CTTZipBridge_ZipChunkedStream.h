/**
 * @file CTTZipBridge_ZipChunkedStream.h
 * @brief TTZip 大文件 1MB 分块流式多线程 DEFLATE 压缩器接口
 * @details 采用 RFC 1951 字节对齐同步块拼接，配合 32 槽位有界内存池，确保常驻内存 <= 64MB。
 */

#ifndef CTTZIP_BRIDGE_ZIP_CHUNKED_STREAM_H
#define CTTZIP_BRIDGE_ZIP_CHUNKED_STREAM_H

#include "CTTZipPlatform.h"
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

#define TTZIP_CHUNK_SIZE_BYTES (1024 * 1024)  /* 1MB */
#define TTZIP_CHUNK_MAX_IN_FLIGHT 32          /* 32 槽位 -> 最大 64MB RSS */

typedef struct ttzip_zip_chunked_stream ttzip_zip_chunked_stream_t;

/**
 * @brief 初始化分块流式压缩器
 * @param out_fd 目标 ZIP 文件的写入文件描述符 (需具备写权限)
 * @param level libdeflate 压缩级别 (1 ~ 12，默认 6)
 * @return 成功返回不透明句柄指针，失败返回 NULL
 */
TTZIP_API ttzip_zip_chunked_stream_t* ttzip_zip_chunked_stream_create(int out_fd, int level);

/**
 * @brief 向流式管道压入数据
 * @param stream 压缩器句柄
 * @param data 待写入原始数据指针
 * @param size 待写入数据字节数
 * @return 成功返回写入字节数，失败返回负数错误码
 */
TTZIP_API int64_t ttzip_zip_chunked_stream_write(ttzip_zip_chunked_stream_t* stream, const void* data, size_t size);

/**
 * @brief 结束流式压缩并冲刷全部在途分块，写入 DEFLATE 终结标记
 * @param stream 压缩器句柄
 * @param out_total_compressed 传出参数，接收最终压缩后总字节数 (可为 NULL)
 * @param out_final_crc32 传出参数，接收全文件最终 CRC-32 校验和 (可为 NULL)
 * @return 成功返回 0，失败返回负数错误码
 */
TTZIP_API int ttzip_zip_chunked_stream_finish(ttzip_zip_chunked_stream_t* stream, uint64_t* out_total_compressed, uint32_t* out_final_crc32);

/**
 * @brief 销毁压缩器句柄并释放所有环形缓冲槽位
 * @param stream 压缩器句柄
 */
TTZIP_API void ttzip_zip_chunked_stream_destroy(ttzip_zip_chunked_stream_t* stream);

#ifdef __cplusplus
}
#endif

#endif /* CTTZIP_BRIDGE_ZIP_CHUNKED_STREAM_H */
