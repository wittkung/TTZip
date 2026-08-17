#ifndef TTZIP_TAR_ZSTD_DIRECT_H
#define TTZIP_TAR_ZSTD_DIRECT_H

#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// 100% In-Process Native Direct mmap TAR.ZST 压缩写入器
// 彻底绕过 libarchive，直接以零拷贝方式向 ZSTD_compressStream2 注入 mmap 数据
int ttzip_create_tar_zstd_direct_c(
    const char* output_path,
    const char* const* input_paths,
    size_t input_count,
    int level,
    bool skip_mac_junk
);

// 100% In-Process Native Direct TAR.ZST 极速流式解压器
int ttzip_extract_tar_zstd_direct_c(
    const char* archive_path,
    const char* dest_dir,
    bool skip_mac_junk
);

#ifdef __cplusplus
}
#endif

#endif // TTZIP_TAR_ZSTD_DIRECT_H
