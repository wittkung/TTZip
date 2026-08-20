// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_platform.h
 * @brief Cross-platform system abstraction layer, page alignment, and symbol export macros.
 * @details Aligned with libarchive archive_platform.h conventions across macOS, Linux, and Windows.
 */

#ifndef TTZIP_PLATFORM_H
#define TTZIP_PLATFORM_H

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include <string.h>
#include <errno.h>

#if defined(_WIN32) || defined(__WIN32__) || defined(WIN32)
  #define TTZIP_OS_WINDOWS 1
  #ifndef WIN32_LEAN_AND_MEAN
    #define WIN32_LEAN_AND_MEAN
  #endif
  #include <windows.h>
  #include <io.h>
  #include <direct.h>
  #include <basetsd.h>
  #include "ttzip_windows.h"
#elif defined(__APPLE__) && defined(__MACH__)
  #define TTZIP_OS_MACOS 1
  #include <unistd.h>
  #include <sys/stat.h>
  #include <sys/types.h>
  #include <sys/mman.h>
  #include <fcntl.h>
  #include <time.h>
#elif defined(__linux__)
  #define TTZIP_OS_LINUX 1
  #include <unistd.h>
  #include <sys/stat.h>
  #include <sys/types.h>
  #include <sys/mman.h>
  #include <fcntl.h>
  #include <time.h>
#else
  #define TTZIP_OS_GENERIC 1
#endif

/* ============================================================================
 * 1. Dynamic Library Export and Calling Convention Macros
 * ============================================================================ */

#if defined(TTZIP_OS_WINDOWS)
  #if defined(TTZIP_BUILD_SHARED) || defined(CTTZipBridge_EXPORTS)
    #define TTZIP_API __declspec(dllexport)
  #elif defined(TTZIP_USE_SHARED)
    #define TTZIP_API __declspec(dllimport)
  #else
    #define TTZIP_API
  #endif
  #define TTZIP_CALL __cdecl
  #define TTZIP_CDECL __cdecl
  #define TTZIP_INLINE __forceinline
#else
  #if defined(__GNUC__) || defined(__clang__)
    #define TTZIP_API __attribute__((visibility("default")))
    #define TTZIP_INLINE __attribute__((always_inline)) inline
  #else
    #define TTZIP_API
    #define TTZIP_INLINE inline
  #endif
  #define TTZIP_CALL
  #define TTZIP_CDECL
#endif

/* ============================================================================
 * 2. Thread-Local Storage (TLS) Macros
 * ============================================================================ */

#if defined(_MSC_VER)
  #define TTZIP_THREAD_LOCAL __declspec(thread)
#elif defined(__STDC_VERSION__) && (__STDC_VERSION__ >= 201112L) && !defined(__STDC_NO_THREADS__)
  #define TTZIP_THREAD_LOCAL _Thread_local
#elif defined(__GNUC__) || defined(__clang__)
  #define TTZIP_THREAD_LOCAL __thread
#elif defined(__cplusplus) && (__cplusplus >= 201103L)
  #define TTZIP_THREAD_LOCAL thread_local
#else
  #define TTZIP_THREAD_LOCAL __thread
#endif

/* ============================================================================
 * 3. Cross-Platform Data Types and Limits
 * ============================================================================ */

#if defined(_MSC_VER)
  typedef SSIZE_T ssize_t;
  #ifndef SSIZE_MAX
    #define SSIZE_MAX INTPTR_MAX
  #endif
  #ifndef O_BINARY
    #define O_BINARY _O_BINARY
  #endif
  #ifndef O_RDONLY
    #define O_RDONLY _O_RDONLY
  #endif
  #ifndef O_WRONLY
    #define O_WRONLY _O_WRONLY
  #endif
  #ifndef O_RDWR
    #define O_RDWR _O_RDWR
  #endif
  #ifndef O_CREAT
    #define O_CREAT _O_CREAT
  #endif
  #ifndef O_TRUNC
    #define O_TRUNC _O_TRUNC
  #endif
  #ifndef O_NOFOLLOW
    #define O_NOFOLLOW 0
  #endif
#else
  #ifndef O_BINARY
    #define O_BINARY 0
  #endif
#endif

typedef int64_t ttzip_off_t;

/* ============================================================================
 * 4. Page Alignment Constants (Apple Silicon 16KB vs Generic 4KB)
 * ============================================================================ */

#if defined(TTZIP_OS_MACOS) && defined(__aarch64__)
  #define TTZIP_PAGE_ALIGN_BYTES 16384
#else
  #define TTZIP_PAGE_ALIGN_BYTES 4096
#endif

/* ============================================================================
 * 5. Status Codes (Libarchive 6-Level Hierarchy)
 * ============================================================================ */

#ifndef TTZIP_STATUS_EOF
#define TTZIP_STATUS_EOF          1   /**< End of Archive */
#endif
#ifndef TTZIP_STATUS_OK
#define TTZIP_STATUS_OK           0   /**< Success */
#endif
#define TTZIP_STATUS_RETRY     (-10)  /**< Transient Retry */
#define TTZIP_STATUS_WARN      (-20)  /**< Recoverable Warning */
#define TTZIP_STATUS_FAILED    (-25)  /**< Item Error (Recoverable) */
#define TTZIP_STATUS_FATAL     (-30)  /**< Fatal Unrecoverable Error */

#ifdef __cplusplus
extern "C" {
#endif

/* ============================================================================
 * 6. High-Precision Microsecond / Millisecond Sleep
 * ============================================================================ */

static inline void ttzip_sleep_ms(uint32_t ms) {
#if defined(TTZIP_OS_WINDOWS)
    Sleep((DWORD)ms);
#elif defined(_POSIX_C_SOURCE) && (_POSIX_C_SOURCE >= 199309L)
    struct timespec ts;
    ts.tv_sec = (time_t)(ms / 1000);
    ts.tv_nsec = (long)((ms % 1000) * 1000000L);
    nanosleep(&ts, NULL);
#else
    usleep((useconds_t)ms * 1000);
#endif
}

static inline void ttzip_sleep_us(uint32_t us) {
#if defined(TTZIP_OS_WINDOWS)
    if (us >= 1000) {
        Sleep((DWORD)(us / 1000));
    } else if (us > 0) {
        Sleep(1);
    }
#elif defined(_POSIX_C_SOURCE) && (_POSIX_C_SOURCE >= 199309L)
    struct timespec ts;
    ts.tv_sec = (time_t)(us / 1000000);
    ts.tv_nsec = (long)((us % 1000000) * 1000L);
    nanosleep(&ts, NULL);
#else
    usleep((useconds_t)us);
#endif
}

/* ============================================================================
 * 7. Prefetch and Branch Prediction Hints
 * ============================================================================ */

#if defined(_MSC_VER)
  #include <intrin.h>
  #if defined(_M_IX86) || defined(_M_X64)
    #define TTZIP_PREFETCH(addr) _mm_prefetch((const char*)(addr), _MM_HINT_T0)
  #else
    #define TTZIP_PREFETCH(addr) ((void)0)
  #endif
  #define __builtin_expect(exp, c) (exp)
#elif defined(__GNUC__) || defined(__clang__)
  #define TTZIP_PREFETCH(addr) __builtin_prefetch((addr), 0, 3)
#else
  #define TTZIP_PREFETCH(addr) ((void)0)
  #define __builtin_expect(exp, c) (exp)
#endif

/* ============================================================================
 * 8. Page-Aligned Memory Allocation Primitives
 * ============================================================================ */

static inline void* ttzip_platform_aligned_alloc(size_t alignment, size_t size) {
#if defined(TTZIP_OS_WINDOWS)
    return _aligned_malloc(size, alignment);
#elif defined(TTZIP_OS_MACOS) || defined(TTZIP_OS_LINUX)
    void* ptr = NULL;
    if (posix_memalign(&ptr, alignment, size) != 0) {
        return NULL;
    }
    return ptr;
#else
    return malloc(size);
#endif
}

static inline void ttzip_platform_aligned_free(void* ptr) {
    if (!ptr) return;
#if defined(TTZIP_OS_WINDOWS)
    _aligned_free(ptr);
#else
    free(ptr);
#endif
}

#ifdef __cplusplus
}
#endif

#endif /* TTZIP_PLATFORM_H */
