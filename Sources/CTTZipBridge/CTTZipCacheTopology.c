// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/CTTZipCacheTopology.h"
#include <unistd.h>
#include <stdatomic.h>

#if defined(__APPLE__)
#include <sys/sysctl.h>
#endif

static atomic_size_t g_l1d_size = 0;
static atomic_size_t g_l2_size = 0;
static atomic_size_t g_cacheline_size = 0;

static void ttzip_cache_init_once(void) {
    if (atomic_load_explicit(&g_l1d_size, memory_order_relaxed) != 0) {
        return;
    }

    size_t l1d = 0;
    size_t l2 = 0;
    size_t cacheline = 0;

#if defined(__APPLE__)
    uint64_t val = 0;
    size_t len = sizeof(val);

    if (sysctlbyname("hw.l1dcachesize", &val, &len, NULL, 0) == 0 && val > 0) {
        l1d = (size_t)val;
    }
    
    val = 0;
    len = sizeof(val);
    if (sysctlbyname("hw.l2cachesize", &val, &len, NULL, 0) == 0 && val > 0) {
        l2 = (size_t)val;
    }

    val = 0;
    len = sizeof(val);
    if (sysctlbyname("hw.cachelinesize", &val, &len, NULL, 0) == 0 && val > 0) {
        cacheline = (size_t)val;
    }
#elif defined(_SC_LEVEL1_DCACHE_SIZE)
    long sc_l1 = sysconf(_SC_LEVEL1_DCACHE_SIZE);
    if (sc_l1 > 0) l1d = (size_t)sc_l1;
    long sc_l2 = sysconf(_SC_LEVEL2_CACHE_SIZE);
    if (sc_l2 > 0) l2 = (size_t)sc_l2;
    long sc_cl = sysconf(_SC_LEVEL1_DCACHE_LINESIZE);
    if (sc_cl > 0) cacheline = (size_t)sc_cl;
#endif

    // Safe fallbacks for ARM64 vs x86_64
    if (l1d == 0) {
#if defined(__aarch64__) || defined(__arm64__)
        l1d = 131072; // 128KB (Apple Silicon P-Core)
#else
        l1d = 32768;  // 32KB (Standard x86)
#endif
    }

    if (l2 == 0) {
#if defined(__aarch64__) || defined(__arm64__)
        l2 = 16777216; // 16MB (Apple Silicon Cluster)
#else
        l2 = 1048576;  // 1MB
#endif
    }

    if (cacheline == 0) {
#if defined(__aarch64__) || defined(__arm64__)
        cacheline = 128; // Apple Silicon 128B cache line
#else
        cacheline = 64;  // Standard 64B cache line
#endif
    }

    atomic_store_explicit(&g_l1d_size, l1d, memory_order_release);
    atomic_store_explicit(&g_l2_size, l2, memory_order_release);
    atomic_store_explicit(&g_cacheline_size, cacheline, memory_order_release);
}

size_t ttzip_cache_get_l1d_size(void) {
    size_t val = atomic_load_explicit(&g_l1d_size, memory_order_relaxed);
    if (__builtin_expect(val == 0, 0)) {
        ttzip_cache_init_once();
        val = atomic_load_explicit(&g_l1d_size, memory_order_relaxed);
    }
    return val;
}

size_t ttzip_cache_get_l2_size(void) {
    size_t val = atomic_load_explicit(&g_l2_size, memory_order_relaxed);
    if (__builtin_expect(val == 0, 0)) {
        ttzip_cache_init_once();
        val = atomic_load_explicit(&g_l2_size, memory_order_relaxed);
    }
    return val;
}

size_t ttzip_cache_get_cacheline_size(void) {
    size_t val = atomic_load_explicit(&g_cacheline_size, memory_order_relaxed);
    if (__builtin_expect(val == 0, 0)) {
        ttzip_cache_init_once();
        val = atomic_load_explicit(&g_cacheline_size, memory_order_relaxed);
    }
    return val;
}

size_t ttzip_cache_get_optimal_batch_size(void) {
    size_t l1d = ttzip_cache_get_l1d_size();
    // Use full L1 Data Cache capacity as the primary unit
    if (l1d >= 131072) {
        return 131072; // 128 KB
    } else if (l1d >= 65536) {
        return 65536;  // 64 KB
    } else {
        return 32768;  // 32 KB
    }
}

size_t ttzip_cache_get_optimal_max_files(void) {
    size_t l1d = ttzip_cache_get_l1d_size();
    if (l1d >= 131072) {
        return 64;
    } else {
        return 32;
    }
}
