// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file CTTZipCommon.h
 * @brief Common infrastructure, error codes, and defensive system macros.
 * @details Provides magic sentinels, 6-level error status codes, dead-store elimination
 *          immunity, and 64-bit clamp protections.
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
 * 1. Struct Lifetime Magic Sentinels & Free-Poisoning
 * ============================================================================ */

#define TTZIP_STRUCT_MAGIC 0x545A4950U /**< 'TZIP' Valid Live Sentinel */
#define TTZIP_POISON_FREE  0xDEADBEEFU /**< Freed Poison Sentinel (UAF Detector) */

/* ============================================================================
 * 2. Multicore Cacheline Alignment (False Sharing Prevention)
 * ============================================================================ */

#if defined(__APPLE__) && defined(__aarch64__)
#define TTZIP_CACHELINE_SIZE 128 /**< Apple Silicon M-series L2 Cacheline Size */
#else
#define TTZIP_CACHELINE_SIZE 64  /**< Standard x86_64 / ARM64 L1/L2 Cacheline Size */
#endif

#define TTZIP_CACHELINE_ALIGNED __attribute__((aligned(TTZIP_CACHELINE_SIZE)))

/* ============================================================================
 * 3. Arithmetic Integer Overflow Checking
 * ============================================================================ */

#if defined(__has_builtin) && __has_builtin(__builtin_add_overflow)
#define ttzip_add_overflow(a, b, res) __builtin_add_overflow((a), (b), (res))
#define ttzip_mul_overflow(a, b, res) __builtin_mul_overflow((a), (b), (res))
#define ttzip_sub_overflow(a, b, res) __builtin_sub_overflow((a), (b), (res))
#else
#define ttzip_add_overflow(a, b, res) (*(res) = (a) + (b), (*(res) < (a)))
#define ttzip_mul_overflow(a, b, res) (*(res) = (a) * (b), ((a) != 0 && *(res) / (a) != (b)))
#define ttzip_sub_overflow(a, b, res) (*(res) = (a) - (b), (*(res) > (a)))
#endif

/* ============================================================================
 * 4. Unified C Status and Error Codes
 * ============================================================================ */

typedef enum ttzip_error_t {
    TTZIP_OK                      = 0,   /**< Success */
    TTZIP_ERR_INVALID_PARAM       = -1,  /**< Invalid parameter */
    TTZIP_ERR_FILE_NOT_FOUND      = -2,  /**< File not found */
    TTZIP_ERR_MMAP_FAILED         = -3,  /**< Virtual memory mapping failed */
    TTZIP_ERR_CORRUPT_HEADER      = -4,  /**< Corrupt header or magic mismatch */
    TTZIP_ERR_INVALID_OFFSET      = -5,  /**< Invalid offset or out of bounds */
    TTZIP_ERR_ARCHIVE_INIT_FAILED = -6,  /**< Archive handle initialization failed */
    TTZIP_ERR_OPEN_FAILED         = -7,  /**< File open failed */
    TTZIP_ERR_PATH_TOO_LONG       = -8,  /**< Path length exceeds system limits */
    TTZIP_ERR_OUT_OF_MEMORY       = -9,  /**< Out of memory */
    TTZIP_ERR_INVALID_PASSWORD    = -10, /**< Invalid password or checksum failure */
    TTZIP_ERR_SECURITY_VIOLATION  = -30, /**< Security violation (Zip Slip / ADS) */
    TTZIP_ERR_UNSUPPORTED_FILTER  = -99  /**< Unsupported compression algorithm */
} ttzip_error_t;

/* ============================================================================
 * 5. Sensitive Memory Physical Eradication (DSE Immunity)
 * ============================================================================ */

/**
 * @brief Zero out sensitive memory securely with compiler barrier.
 * @param[in,out] ptr Starting pointer.
 * @param[in]     len Byte length.
 */
static inline void ttzip_secure_zero(void* ptr, size_t len) {
    if (!ptr || len == 0) return;
#if defined(__APPLE__) || defined(__STDC_LIB_EXT1__)
    memset_s(ptr, len, 0, len);
#elif defined(_WIN32)
    SecureZeroMemory(ptr, len);
#elif defined(__linux__) && defined(_GNU_SOURCE)
    explicit_bzero(ptr, len);
#else
    volatile unsigned char* p = (volatile unsigned char*)ptr;
    while (len--) *p++ = 0;
#endif
#if defined(__GNUC__) || defined(__clang__)
    __asm__ __volatile__("" : : "r"(ptr) : "memory");
#endif
}

/* ============================================================================
 * 4. Cross-Architecture Integer Clamping
 * ============================================================================ */

static inline size_t ttzip_clamp_size(uint64_t val) {
#if defined(SSIZE_MAX)
    return (val > (uint64_t)SSIZE_MAX) ? (size_t)SSIZE_MAX : (size_t)val;
#elif defined(SIZE_MAX)
    return (val > (uint64_t)SIZE_MAX) ? (size_t)SIZE_MAX : (size_t)val;
#else
    return (size_t)val;
#endif
}

static inline ssize_t ttzip_clamp_ssize(int64_t val) {
#if defined(SSIZE_MAX)
    if (val < 0) return -1;
    return (val > (int64_t)SSIZE_MAX) ? SSIZE_MAX : (ssize_t)val;
#else
    return (val < 0) ? -1 : (ssize_t)val;
#endif
}

/* ============================================================================
 * 5. Logging Sinks
 * ============================================================================ */

typedef void (*ttzip_log_handler_t)(int level, const char* message);
void ttzip_set_log_handler(ttzip_log_handler_t handler);
void ttzip_log(int level, const char* fmt, ...);

/* ============================================================================
 * 6. Path and System Directory Operations
 * ============================================================================ */

int ttzip_common_mkdir_p(const char* dir);
int ttzip_common_join_path(char* dst, size_t dst_size, const char* base, const char* rel);
int ttzip_common_apfs_preallocate(int fd, int64_t size);
void ttzip_set_enable_apfs_zero_copy(bool enable);
bool ttzip_get_enable_apfs_zero_copy(void);

#ifdef __cplusplus
}
#endif

#endif /* CTTZipCommon_h */
