#ifndef TTZIP_7Z_HEADER_PARSER_H
#define TTZIP_7Z_HEADER_PARSER_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    char rel_path[1024];
    uint64_t file_size;
    bool is_dir;
    bool is_empty_stream;
} ttzip_7z_file_meta_t;

typedef struct {
    uint64_t primary_method_id;
    uint64_t total_folders;
    size_t payload_offset;
    size_t payload_len;
    
    // 加密信息 (AES-256)
    bool is_encrypted;
    uint32_t aes_num_cycles_power;
    uint8_t aes_salt[16];
    size_t aes_salt_len;
    uint8_t aes_iv[16];
    size_t aes_iv_len;

    // 编码器属性 (LZMA1 5-byte properties 等)
    uint8_t coder_props[32];
    size_t coder_props_len;

    // 文件与流尺寸元数据
    ttzip_7z_file_meta_t* files;
    size_t num_files;
    uint64_t* stream_sizes;
    size_t num_stream_sizes;
    uint64_t* coder_unpack_sizes;
    size_t num_coder_unpack_sizes;
    uint32_t* stream_crcs;
    size_t num_stream_crcs;
} ttzip_7z_header_info_t;

/// 读取 7z 变长整数 (varint)
size_t ttzip_7z_read_varint(const uint8_t* buf, size_t len, uint64_t* val);

/// 解析 7z 归档头部与完整元数据
int ttzip_7z_parse_header_metadata(
    const uint8_t* mapped_data,
    size_t file_size,
    ttzip_7z_header_info_t* out_info
);

/// 释放 7z 头部元数据结构体资源
void ttzip_7z_free_header_info(ttzip_7z_header_info_t* info);

#ifdef __cplusplus
}
#endif

#endif // TTZIP_7Z_HEADER_PARSER_H
