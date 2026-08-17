/**
 * @file CTTZipBridge_Archive.h
 * @brief TTZip 通用归档编解码、条目检视、密码穿透与硬件 SIMD 辅助函数接口
 * @details 对标 libarchive `archive_read.c` 与 `archive_write.c`，
 *          提供多格式统一解压、结构检视、字符集自动探测与 ARM NEON 硬件加速。
 * @version 4.0
 * @author TTZip Core Engineering Team
 */

#ifndef CTTZipBridge_Archive_h
#define CTTZipBridge_Archive_h

#include "CTTZipBridge.h"
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief 检视归档内部文件结构与元数据
 * 
 * @param[in] archive_path 目标归档文件绝对路径
 * @param[in] context      透传给回调函数的用户上下文指针
 * @param[in] callback     逐条目回调函数指针
 * 
 * @return 0 成功；非 0 表示打开或解析失败
 */
int ttzip_inspect_archive(const char* archive_path, void* context, ttzip_entry_callback callback);

/**
 * @brief 解压归档文件（支持密码解密与 macOS 垃圾文件过滤）
 * 
 * @param[in] archive_path    源归档绝对路径
 * @param[in] destination_dir 目标输出目录绝对路径
 * @param[in] skip_mac_junk   是否跳过 __MACOSX / .DS_Store 等垃圾文件
 * @param[in] password        解密密码（无密码传入 NULL）
 * 
 * @return 0 成功；非 0 失败
 */
int ttzip_extract_archive_advanced(const char* archive_path, const char* destination_dir, bool skip_mac_junk, const char* password);

/**
 * @brief 解压归档文件（无密码默认配置）
 */
int ttzip_extract_archive(const char* archive_path, const char* destination_dir);

/**
 * @brief 专用于 7z 格式的 libarchive 原生 C 解压
 */
int ttzip_extract_7z_libarchive_c(const char* archive_path, const char* dest_dir, const char* password);

/**
 * @brief 高级参数调优归档压缩中枢
 */
int ttzip_create_archive_tuned(
    const char* output_archive_path,
    const char* format,
    const char* const* input_paths,
    size_t input_count,
    bool skip_mac_junk,
    int zstd_level,
    int zstd_long_window_log,
    int cpu_threads,
    const char* password
);

/**
 * @brief 标准多文件打包中枢
 */
int ttzip_create_archive_advanced(
    const char* output_archive_path,
    const char* format,
    const char* const* input_paths,
    size_t input_count,
    bool skip_mac_junk
);

/**
 * @brief 基础多文件打包中枢
 */
int ttzip_create_archive(
    const char* output_archive_path,
    const char* format,
    const char* const* input_paths,
    size_t input_count
);

/**
 * @brief 申请 16KB 页对齐内存
 * @note [Ownership] Caller owns the memory, must free via ttzip_platform_aligned_free()
 */
void* ttzip_aligned_alloc_16k(size_t size);
void ttzip_aligned_free_16k(void* ptr);

/**
 * @brief 探测字节流字符集编码
 * @note [Ownership] Caller owns the returned C string, must free via free()
 */
char* ttzip_detect_charset(const char* bytes, size_t length);

/**
 * @brief 计算缓冲区 CRC32 校验和
 */
uint32_t ttzip_compute_buffer_crc32(const void* buf, size_t len);

/**
 * @brief ARM NEON 硬件加速 CRC32 增量计算
 */
uint32_t ttzip_compute_buffer_crc32_neon(uint32_t initial_crc, const void* buf, size_t len);

/**
 * @brief ARM NEON 64 字节对齐快速内存拷贝
 */
void ttzip_neon_memcpy_64b(void* dst, const void* src, size_t len);

/**
 * @brief 计算物理文件完整 CRC32 校验和
 */
uint32_t ttzip_compute_file_crc32(const char* file_path);

/**
 * @brief 香农熵快速估算 (判断数据是否已被高度压缩或加密)
 */
double ttzip_estimate_buffer_entropy(const void* buf, size_t len);

/**
 * @brief SIMD 极速 ASCII 字符串判定
 */
bool ttzip_is_ascii_fast(const void* buf, size_t len);

#ifdef __cplusplus
}
#endif

#endif /* CTTZipBridge_Archive_h */
