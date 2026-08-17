#ifndef TTZIP_LZMA2_ENC_NATIVE_H
#define TTZIP_LZMA2_ENC_NATIVE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// 原生进程内 LZMA2 压缩 + 7z 容器组装 (替代 ttzip_spawn_7zz_compress)
/// @param output_path   输出 .7z 文件路径
/// @param input_paths   输入文件/目录路径数组
/// @param input_count   输入路径数量
/// @param level         压缩级别 1-9
/// @return              0=成功, 非0=错误码
int ttzip_create_7z_lzma2_native_c(
    const char* output_path,
    const char* const* input_paths,
    size_t input_count,
    int level,
    const char* password
);

#ifdef __cplusplus
}
#endif

#endif // TTZIP_LZMA2_ENC_NATIVE_H
