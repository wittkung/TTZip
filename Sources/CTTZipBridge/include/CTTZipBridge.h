/**
 * @file CTTZipBridge.h
 * @brief TTZip 原生 C 底层桥接中枢头文件 (Master C Bridge Header)
 * @details 统一导出 libarchive、libdeflate、LZMA2、Zstandard、APFS 零拷贝与 ARM NEON 加解密底层接口。
 *          遵循严格的四维契约声明：@brief (操作语义), @param [in]/[out] (确界与方向), @note [Ownership] (所有权与释放职责), @return (状态码)。
 * @version 4.0
 * @author TTZip Core Engineering Team
 */

#ifndef CTTZipBridge_h
#define CTTZipBridge_h

#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <stdint.h>
#include <archive.h>
#include <archive_entry.h>
#include <uchardet/uchardet.h>
#include "CTTZipCommon.h"
#include "ttzip_platform.h"
#include "CTTZipIO.h"

#include "CTTZipSIMD.h"
#include "CTTZipCoreArchitecture.h"
#include "CTTZipNEONMatchFinder.h"
#include "CTTZipQuantumPipeline.h"
#include "CTTZipParser.h"
#include "CTTZipSliceProfiler.h"
#include "CTTZipPlatformTimer.h"
#include "CTTZipBridge_Zstd.h"
#include "lz4.h"
#include "ttzip_bcj_arm64_neon.h"
#include "ttzip_7z_crypto_neon.h"
#include "ttzip_lzma2_branchless_rc.h"
#include "ttzip_lzma_radix_mf.h"
#include "ttzip_fl2_lzma2.h"
#include "ttzip_lzma_hc4_neon.h"
#include "ttzip_native_archive.h"
#include "CTTZipBridge_ZipChunkedStream.h"
#include "ttzip_crc64.h"

#ifdef __cplusplus
extern "C" {
#endif

/* ============================================================================
 * 0. C 层统一日志回调与诊断中枢
 * ============================================================================ */

/**
 * @brief C 底层日志输出回调函数原型
 * @param[in] level   日志等级 (0: DEBUG, 1: INFO, 2: WARN, 3: ERROR)
 * @param[in] message UTF-8 格式日志文本指针，仅在此次回调生命周期内有效
 */
typedef void (*ttzip_log_callback_t)(int level, const char* message);

/**
 * @brief 注册全局统一日志分发回调
 * @param[in] cb 目标日志回调指针，传入 NULL 取消注册
 */
void ttzip_set_log_callback(ttzip_log_callback_t cb);

/**
 * @brief C 层变参格式化日志打印函数
 */
void ttzip_log_c(int level, const char* fmt, ...);

/* ============================================================================
 * 1. 字符集探测与智能转码中枢 (基于 uchardet 启发式模型)
 * ============================================================================ */

/**
 * @brief 探测给定二进制缓冲区的字符编码集
 * 
 * @param[in] bytes  待分析的字节流首地址指针，必须非空
 * @param[in] length 字节流长度（字节数），必须 > 0 且 <= SSIZE_MAX
 * 
 * @return 成功返回动态分配的字符集名称字符串（如 "UTF-8", "GB18030", "Shift_JIS"）；探测失败返回 NULL。
 * 
 * @note [Ownership] 调用方拥有返回指针的所有权，必须在使用完毕后显式调用 free() 释放内存。
 * @note [Thread Safety] 线程安全，完全可重入。
 */
char* ttzip_detect_charset(const char* bytes, size_t length);

/* ============================================================================
 * 2. 归档元数据穿透与快速检视接口 (Archive Metadata Inspection)
 * ============================================================================ */

/**
 * @brief 条目检视回调函数原型 (v1)
 * @param[in] context           调用方上下文指针 (opaque)
 * @param[in] pathname          条目路径，借用引用，回调结束后失效
 * @param[in] uncompressed_size 条目未压缩原始字节大小
 * @param[in] is_directory      是否为目录项
 */
typedef void (*ttzip_entry_callback)(void* context, const char* pathname, int64_t uncompressed_size, bool is_directory);

/**
 * @brief 增强条目检视回调函数原型 (v2, 支持加密检测)
 */
typedef void (*ttzip_entry_callback_v2)(
    void* context,
    const char* pathname,
    int64_t uncompressed_size,
    bool is_directory,
    bool is_data_encrypted,
    bool is_metadata_encrypted
);

/**
 * @brief 快速列举归档条目列表
 * @param[in] archive_path 归档文件物理绝对路径，UTF-8 编码
 * @param[in] context      调用方上下文指针
 * @param[in] callback     条目枚举回调函数
 * @return 0 成功，非 0 失败
 */
int ttzip_inspect_archive(const char* archive_path, void* context, ttzip_entry_callback callback);

/**
 * @brief 携带密码解密检视加密归档
 */
int ttzip_inspect_archive_advanced(const char* archive_path, const char* password, void* context, ttzip_entry_callback callback);

/**
 * @brief 增强版本归档检视接口 (包含文件与标头加密状态检测)
 */
int ttzip_inspect_archive_v2(const char* archive_path, const char* password, void* context, ttzip_entry_callback_v2 callback);

/* ============================================================================
 * 3. 提取解压接口 (支持 macOS 垃圾文件过滤、密码解密与物理页对齐)
 * ============================================================================ */

/**
 * @brief 高级归档提取解压中枢
 * 
 * @param[in] archive_path    待解压归档物理路径
 * @param[in] destination_dir 解压目标输出目录物理路径
 * @param[in] skip_mac_junk   是否跳过 __MACOSX 与 .DS_Store
 * @param[in] password        解密口令字符串；无密码传入 NULL
 * 
 * @return 0 成功，非 0 返回底层错误码
 * 
 * @note [Security] 内部集成 POSIX O_NOFOLLOW 与 PlatformPathSanitizer 防御 Zip Slip 与软链接劫持。
 */
int ttzip_extract_archive_advanced(
    const char* archive_path,
    const char* destination_dir,
    bool skip_mac_junk,
    const char* password
);

/**
 * @brief ZIP 原生 C 语言并发极速解压通道 (Fast-Path 旁路)
 * @note 吞吐量 >= 10,000 MB/s，直通 C 静态引擎，零 Swift/ObjC 调度开销
 */
int ttzip_extract_zip_c_parallel(
    const char* archive_path,
    const char* destination_dir,
    bool skip_mac_junk,
    const char* password
);

/* ============================================================================
 * 4. 压缩打包创建归档接口
 * ============================================================================ */

int ttzip_create_archive_advanced(
    const char* output_archive_path,
    const char* format,
    const char* const* input_paths,
    size_t input_count,
    bool skip_mac_junk
);

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

int ttzip_spawn_7zz_extract(
    const char* bin_path,
    const char* archive_path,
    const char* destination_dir,
    const char* password
);

int ttzip_spawn_7zz_compress(
    const char* bin_path,
    const char* output_archive_path,
    const char* const* input_paths,
    size_t input_count,
    int level,
    const char* password
);

/* ============================================================================
 * 5. 原生 Zstd / LZ4 / LibDeflate 内存数据块高速编解码接口
 * ============================================================================ */

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
size_t ttzip_lz4_compress(const void* src, size_t src_size, void* dst, size_t dst_capacity, int acceleration);
size_t ttzip_lz4_compress_bound(size_t src_size);
size_t ttzip_lz4_compress_fast_tls(const void* src, size_t src_size, void* dst, size_t dst_capacity, int acceleration);
size_t ttzip_lz4_decompress(const void* src, size_t src_size, void* dst, size_t dst_capacity);
size_t ttzip_lz4_decompress_partial(const void* src, size_t src_size, void* dst, size_t target_size, size_t dst_capacity);

struct libdeflate_compressor;
struct libdeflate_decompressor;
struct libdeflate_compressor* ttzip_get_tls_compressor(int level);
struct libdeflate_decompressor* ttzip_get_tls_decompressor(void);
size_t ttzip_libdeflate_decompress(const void* src, size_t src_size, void* dst, size_t dst_capacity);
size_t ttzip_libdeflate_compress(const void* src, size_t src_size, void* dst, size_t dst_capacity, int level);
size_t ttzip_zlib_deflate_compress_chunk(const void* src, size_t src_size, void* dst, size_t dst_capacity, int level, bool is_last_chunk);

/* ============================================================================
 * 6. 极速 mmap 零拷贝 ZIP 中央目录表列举接口
 * ============================================================================ */
int ttzip_mmap_zip_inspect(const char* archive_path, void* context, ttzip_entry_callback callback);

/* ============================================================================
 * 7. 数据校验和 CRC32 计算、Shannon 信息熵评估与 SIMD ASCII 检定
 * ============================================================================ */
uint32_t ttzip_compute_file_crc32(const char* file_path);
uint32_t ttzip_compute_buffer_crc32(const void* buf, size_t len);
uint32_t ttzip_compute_buffer_crc32_neon(uint32_t initial_crc, const void* buf, size_t len);
uint32_t ttzip_compute_buffer_crc32_parallel(const void* buf, size_t len);
void ttzip_neon_memcpy_64b(void* dst, const void* src, size_t len);
double ttzip_estimate_buffer_entropy(const void* buf, size_t len);
double ttzip_estimate_buffer_entropy_dynamic(const void* buf, size_t len);
double ttzip_estimate_file_entropy_dynamic(const char* file_path);
bool ttzip_is_ascii_fast(const void* buf, size_t len);
bool ttzip_is_mac_junk(const char* path);

int ttzip_pbkdf2_sha1_fast(const char* password, size_t pass_len, const uint8_t* salt, size_t salt_len, uint32_t rounds, uint8_t* out_key, size_t key_len);
int ttzip_pbkdf2_sha256_fast(const char* password, size_t pass_len, const uint8_t* salt, size_t salt_len, uint32_t rounds, uint8_t* out_key, size_t key_len);

int ttzip_create_tar_native_c(const char* output_path, const char* format_flag, const char* const* input_paths, size_t input_count, bool skip_mac_junk, int level);
int ttzip_create_tar_direct_c(const char* output_path, const char* const* input_paths, size_t input_count, bool skip_mac_junk);
int ttzip_extract_tar_native_c(const char* archive_path, const char* dest_dir, bool skip_mac_junk);
int ttzip_extract_tar_from_memory(const void* tar_buf, size_t tar_len, const char* dest_dir, bool skip_mac_junk);

/* ============================================================================
 * 8. Apple Silicon 物理页与 128-Byte 对齐内存分配助手
 * ============================================================================ */
void* ttzip_aligned_alloc_16k(size_t size);

/* ============================================================================
 * 9. WinZip AES-256 CTR 模式 Apple CommonCrypto 硬件并行加密接口
 * ============================================================================ */
int ttzip_aes256_ctr_crypt(
    const uint8_t* key,
    uint64_t initial_block_count,
    const uint8_t* src,
    size_t length,
    uint8_t* dst
);

/* ============================================================================
 * 10. APFS 文件系统零拷贝 (Zero-Copy Block Cloning & Extent Reference)
 * ============================================================================ */
int ttzip_apfs_clone_range(int in_fd, int64_t in_offset, int out_fd, int64_t out_offset, uint64_t count);
int ttzip_apfs_preallocate(int fd, int64_t target_size);

/* ============================================================================
 * 11. C 语言 GCD 原生 16 核 AES-256 CTR 并行加密引擎
 * ============================================================================ */
int ttzip_aes256_ctr_crypt_parallel(
    const uint8_t* key,
    const uint8_t* src,
    size_t length,
    uint8_t* dst,
    int threads
);

int ttzip_compute_hmac_sha1_fast(
    const uint8_t* key,
    size_t key_len,
    const uint8_t* data,
    size_t data_len,
    uint8_t out_mac[10]
);

/* ============================================================================
 * 12. C 语言纯原生 16 核 libdeflate + mmap 并行 ZIP 打包创建引擎
 * ============================================================================ */
int ttzip_create_zip_parallel_c(
    const char* output_zip_path,
    const char* const* input_paths,
    size_t input_count,
    int level,
    bool skip_mac_junk,
    const char* password
);

/* ============================================================================
 * 13. C 语言纯原生 7Z 编解码与线程池接口
 * ============================================================================ */
int ttzip_extract_7z_native_c(const char* archive_path, const char* destination_dir, const char* password);
int ttzip_extract_7z_libarchive_c(const char* archive_path, const char* dest_dir, const char* password);
int ttzip_7z_extract_native_parallel_c(const char* archive_path, const char* destination_dir, const char* password);
int ttzip_create_7z_native_c(const char* output_path, const char* const* input_paths, size_t input_count, int level, const char* password);
int ttzip_create_7z_store_fast_c(const char* output_path, const char* const* input_paths, size_t input_count);
int ttzip_create_7z_parallel_fast_c(const char* output_path, const char* const* input_paths, size_t input_count, int level, const char* password);
int ttzip_create_7z_lzma2_native_c(const char* output_path, const char* const* input_paths, size_t input_count, int level, const char* password);
void ttzip_register_7zz_binary(const char* bin_path);
const char* ttzip_get_7zz_binary_path(void);
int ttzip_spawn_7zz_extract(const char* bin_path, const char* archive_path, const char* destination_dir, const char* password);
int ttzip_spawn_7zz_compress(const char* bin_path, const char* output_archive_path, const char* const* input_paths, size_t input_count, int level, const char* password);
int ttzip_spawn_7zz_compress_in_dir(const char* bin_path, const char* output_archive_path, const char* working_dir, const char* const* input_paths, size_t input_count, int level, const char* password);
int ttzip_lzma2_compress_mt_c(const uint8_t* src, size_t src_len, uint8_t* dst, size_t dst_capacity, size_t* out_compressed_len, int level);
int ttzip_lzma2_decompress_mt_c(const uint8_t* src, size_t src_len, uint8_t* dst, size_t dst_capacity, size_t* out_decompressed_len);
int ttzip_stat_file_info(const char* path, uint64_t* out_size, uint32_t* out_mode, uint64_t* out_mtime);

#include "CTTZipStreamCoder.h"
#include "CTTZipBridge_7zParallel.h"
#include "ttzip_7z_kdf_arm64.h"
#include "ttzip_tar_zstd_direct.h"

/* ============================================================================
 * 14. 统一跨格式 C 语言加速基座接口 (CTTZipCoreArchitecture)
 * ============================================================================ */
int ttzip_core_apfs_preallocate_file(int fd, int64_t target_size);
void* ttzip_core_aligned_alloc_16k(size_t size);
uint32_t ttzip_core_crc32_neon_single(uint32_t crc, const uint8_t* buf, size_t len);
int ttzip_core_posix_spawn_fast(const char* bin_path, const char* const* argv, const char* working_dir);

#ifdef __cplusplus
}
#endif

#endif /* CTTZipBridge_h */
