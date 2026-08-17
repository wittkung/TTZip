#ifndef CTTZipBridge_Zstd_h
#define CTTZipBridge_Zstd_h

#include "CTTZipBridge.h"
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

size_t ttzip_zstd_compress(const void* src, size_t src_size, void* dst, size_t dst_capacity, int compression_level);
size_t ttzip_zstd_decompress(const void* src, size_t src_size, void* dst, size_t dst_capacity);

size_t ttzip_zstd_compress_advanced(
    const void* src, size_t src_size,
    void* dst, size_t dst_capacity,
    int level, int nb_workers, int job_size_mb, int overlap_log, int window_log, bool enable_ldm
);

int ttzip_zstd_compress_file_stream(
    const char* src_path,
    const char* dst_path,
    int level, int nb_workers, int job_size_mb, int overlap_log, int window_log, bool enable_ldm,
    const char* dict_path
);

int ttzip_zstd_decompress_file_stream(
    const char* src_path,
    const char* dst_path,
    const char* dict_path
);

#ifdef __cplusplus
}
#endif

#endif // CTTZipBridge_Zstd_h
