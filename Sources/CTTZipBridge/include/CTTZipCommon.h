/**
 * @file CTTZipCommon.h
 * @brief TTZip C 语言通用基础设施、错误码与防御性系统宏定义
 * @details 对标 libarchive `archive_platform.h` 与 `archive_private.h`，
 *          提供生命周期魔数、6 级错误状态码、防 DSE 物理内存清零与 64 位 Clamp 确界保护。
 * @version 4.0
 * @author TTZip Core Engineering Team
 */

#ifndef CTTZipCommon_h
#define CTTZipCommon_h

#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>
#include <stdarg.h>
#include <errno.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <limits.h>

#include "ttzip_platform.h"

#ifdef __cplusplus
extern "C" {
#endif

/* ============================================================================
 * 1. 结构体生命周期魔数哨兵 (对标 libarchive a->magic Invariant)
 * ============================================================================ */

/**
 * @brief 句柄有效性魔数哨兵，分配时置入，释放前清零以免疫 Use-After-Free (UAF)
 */
#define TTZIP_STRUCT_MAGIC 0x545A4950U /* 'TZIP' */

/* ============================================================================
 * 2. 统一工业级 C 语言错误码定义
 * ============================================================================ */

typedef enum ttzip_error_t {
    TTZIP_OK                      = 0,   /**< 成功 (Success) */
    TTZIP_ERR_INVALID_PARAM       = -1,  /**< 参数非法或指针为空 (Invalid Parameter) */
    TTZIP_ERR_FILE_NOT_FOUND      = -2,  /**< 文件未找到 (File Not Found) */
    TTZIP_ERR_MMAP_FAILED         = -3,  /**< 虚拟内存映射失败 (mmap Failed) */
    TTZIP_ERR_CORRUPT_HEADER      = -4,  /**< 标头损坏或魔数不匹配 (Corrupt Header) */
    TTZIP_ERR_INVALID_OFFSET      = -5,  /**< 偏移量非法或超出边界 (Invalid Offset) */
    TTZIP_ERR_ARCHIVE_INIT_FAILED = -6,  /**< 归档句柄初始化失败 (Init Failed) */
    TTZIP_ERR_OPEN_FAILED         = -7,  /**< 文件打开失败 (Open Failed) */
    TTZIP_ERR_PATH_TOO_LONG       = -8,  /**< 路径长度超过系统限制 (Path Too Long) */
    TTZIP_ERR_OUT_OF_MEMORY       = -9,  /**< 内存分配不足 (Out Of Memory) */
    TTZIP_ERR_INVALID_PASSWORD    = -10, /**< 密码错误或解密校验和失败 (Invalid Password) */
    TTZIP_ERR_SECURITY_VIOLATION  = -30, /**< 安全越界违反 Zip Slip / ADS 拦截 (Security Violation) */
    TTZIP_ERR_UNSUPPORTED_FILTER  = -99  /**< 不支持的压缩算法或格式 (Unsupported Filter) */
} ttzip_error_t;

/* ============================================================================
 * 3. 敏感内存物理擦除 (防 Clang/LLVM 死存储消除 DSE)
 * ============================================================================ */

/**
 * @brief 强制物理清零敏感内存区域
 * 
 * @param[in,out] ptr 待清零的内存起始指针
 * @param[in]     len 待清零的字节长度
 * 
 * @note [DSE Immunity] 内部使用 memset_s 或 volatile 内存写屏障，确保在 Release 优化下不被编译器丢弃
 */
static inline void ttzip_secure_zero(void* ptr, size_t len) {
    if (!ptr || len == 0) return;
#if defined(__APPLE__) || defined(__STDC_LIB_EXT1__)
    memset_s(ptr, len, 0, len);
#else
    volatile unsigned char* p = (volatile unsigned char*)ptr;
    while (len--) *p++ = 0;
#endif
}

/* ============================================================================
 * 4. 跨架构 64 位整数向 size_t 转换上限 Clamp 保护
 * ============================================================================ */

/**
 * @brief 将 64 位无符号整数安全截断至当前架构下的有效 size_t 确界
 * @param[in] val 64 位整型数值
 * @return 经过 SSIZE_MAX 保护后的 size_t 尺寸
 */
static inline size_t ttzip_clamp_size(uint64_t val) {
#if defined(SSIZE_MAX)
    return (val > (uint64_t)SSIZE_MAX) ? (size_t)SSIZE_MAX : (size_t)val;
#elif defined(SIZE_MAX)
    return (val > (uint64_t)SIZE_MAX) ? (size_t)SIZE_MAX : (size_t)val;
#else
    return (size_t)val;
#endif
}

/**
 * @brief 将 64 位带符号整数安全截断至当前架构下的有效 ssize_t 确界
 * @param[in] val 64 位带符号整型数值
 * @return 经过 SSIZE_MAX 保护后的 ssize_t 尺寸
 */
static inline ssize_t ttzip_clamp_ssize(int64_t val) {
#if defined(SSIZE_MAX)
    if (val < 0) return -1;
    return (val > (int64_t)SSIZE_MAX) ? SSIZE_MAX : (ssize_t)val;
#else
    return (val < 0) ? -1 : (ssize_t)val;
#endif
}

/* ============================================================================
 * 5. C 引擎结构化日志 Sinks 接口
 * ============================================================================ */

typedef void (*ttzip_log_handler_t)(int level, const char* message);
void ttzip_set_log_handler(ttzip_log_handler_t handler);
void ttzip_log(int level, const char* fmt, ...);

/* ============================================================================
 * 6. 路径与系统目录操作
 * ============================================================================ */

/**
 * @brief 递归创建目录 (等价于 mkdir -p)
 * @param[in] dir 目标目录绝对或相对路径，UTF-8 编码
 * @return 0 成功，-1 失败
 */
int ttzip_common_mkdir_p(const char* dir);

/**
 * @brief 防溢出的安全路径拼接
 * @param[out] dst      目标缓冲区指针
 * @param[in]  dst_size 目标缓冲区最大字节容量
 * @param[in]  base     基础路径前缀
 * @param[in]  rel      追加的相对路径
 * @return 0 成功，-1 溢出或参数非法
 */
int ttzip_common_join_path(char* dst, size_t dst_size, const char* base, const char* rel);

/**
 * @brief APFS 物理空间高效预分配句柄
 * @param[in] fd   目标文件描述符
 * @param[in] size 需要预分配的字节大小
 * @return 0 成功，-1 失败
 */
int ttzip_common_apfs_preallocate(int fd, int64_t size);

/**
 * @brief APFS 零拷贝可配置全局开关
 */
void ttzip_set_enable_apfs_zero_copy(bool enable);
bool ttzip_get_enable_apfs_zero_copy(void);

#ifdef __cplusplus
}
#endif

#endif /* CTTZipCommon_h */
