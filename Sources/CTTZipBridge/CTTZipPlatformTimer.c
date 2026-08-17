/**
 * @file CTTZipPlatformTimer.c
 * @brief 跨平台纳秒级单调硬件计时器与时钟校准实现
 * @details 采用零系统调用、128 位宽整数防溢出与静态时基缓存架构，
 *          完全对齐 TurboBench 与 lzbench 高精度单调时钟规范。
 * @version 1.0
 * @author TTZip Core Engineering Team
 */

#include "include/CTTZipPlatformTimer.h"

#if defined(TTZIP_OS_MACOS)
  #include <mach/mach_time.h>
  #include <sys/sysctl.h>
  #include <time.h>
#elif defined(TTZIP_OS_WINDOWS)
  #include <windows.h>
#elif defined(TTZIP_OS_LINUX)
  #include <time.h>
#endif

/* 静态全局时钟配置与校准缓存 */
static bool                      g_timer_initialized = false;
static ttzip_timer_calibration_t g_calibration_cache = {
    .platform_os = "Unknown",
    .architecture = "Unknown",
    .timer_backend = "Unknown",
    .frequency_hz = 1000000000ULL,
    .timebase_numer = 1,
    .timebase_denom = 1,
    .resolution_nanos = 1.0,
    .overhead_nanos = 0.0
};

#if defined(TTZIP_OS_MACOS)
static mach_timebase_info_data_t g_darwin_tb = {0, 0};
#elif defined(TTZIP_OS_WINDOWS)
static uint64_t g_win_qpc_freq = 0;
#endif

void ttzip_platform_timer_init(void) {
    if (g_timer_initialized) {
        return;
    }

#if defined(TTZIP_OS_MACOS)
    g_calibration_cache.platform_os = "macOS";
    #if defined(__aarch64__)
        g_calibration_cache.architecture = "arm64";
    #elif defined(__x86_64__)
        g_calibration_cache.architecture = "x86_64";
    #else
        g_calibration_cache.architecture = "unknown";
    #endif

    mach_timebase_info(&g_darwin_tb);
    if (g_darwin_tb.denom == 0) {
        g_darwin_tb.numer = 1;
        g_darwin_tb.denom = 1;
    }
    g_calibration_cache.timebase_numer = g_darwin_tb.numer;
    g_calibration_cache.timebase_denom = g_darwin_tb.denom;
    g_calibration_cache.timer_backend = "mach_absolute_time";

    /* 计算时钟基础频率 (Hz) */
    /* 1,000,000,000 * denom / numer */
    uint64_t freq = (1000000000ULL * (uint64_t)g_darwin_tb.denom) / (uint64_t)g_darwin_tb.numer;
    g_calibration_cache.frequency_hz = freq;
    g_calibration_cache.resolution_nanos = (double)g_darwin_tb.numer / (double)g_darwin_tb.denom;

#elif defined(TTZIP_OS_WINDOWS)
    g_calibration_cache.platform_os = "Windows";
    #if defined(_M_ARM64) || defined(__aarch64__)
        g_calibration_cache.architecture = "arm64";
    #elif defined(_M_X64) || defined(__x86_64__)
        g_calibration_cache.architecture = "x86_64";
    #else
        g_calibration_cache.architecture = "x86";
    #endif

    LARGE_INTEGER freq;
    QueryPerformanceFrequency(&freq);
    g_win_qpc_freq = (uint64_t)freq.QuadPart;
    if (g_win_qpc_freq == 0) {
        g_win_qpc_freq = 10000000ULL;
    }
    g_calibration_cache.frequency_hz = g_win_qpc_freq;
    g_calibration_cache.timebase_numer = 1000000000U;
    g_calibration_cache.timebase_denom = (uint32_t)g_win_qpc_freq;
    g_calibration_cache.timer_backend = "QueryPerformanceCounter";
    g_calibration_cache.resolution_nanos = 1000000000.0 / (double)g_win_qpc_freq;

#elif defined(TTZIP_OS_LINUX)
    g_calibration_cache.platform_os = "Linux";
    #if defined(__aarch64__)
        g_calibration_cache.architecture = "arm64";
    #elif defined(__x86_64__)
        g_calibration_cache.architecture = "x86_64";
    #else
        g_calibration_cache.architecture = "unknown";
    #endif

    g_calibration_cache.frequency_hz = 1000000000ULL;
    g_calibration_cache.timebase_numer = 1;
    g_calibration_cache.timebase_denom = 1;
    g_calibration_cache.timer_backend = "clock_gettime_CLOCK_MONOTONIC_RAW";
    g_calibration_cache.resolution_nanos = 1.0;
#else
    g_calibration_cache.platform_os = "Generic";
    g_calibration_cache.architecture = "generic";
    g_calibration_cache.frequency_hz = 1000000000ULL;
    g_calibration_cache.timebase_numer = 1;
    g_calibration_cache.timebase_denom = 1;
    g_calibration_cache.timer_backend = "generic_clock";
    g_calibration_cache.resolution_nanos = 1.0;
#endif

    /* 测算单次调用平均开销 (Overhead) */
    g_timer_initialized = true;
    uint64_t t_start = ttzip_platform_monotonic_nanos();
    const int probe_count = 1000;
    for (int i = 0; i < probe_count; ++i) {
        (void)ttzip_platform_monotonic_nanos();
    }
    uint64_t t_end = ttzip_platform_monotonic_nanos();
    g_calibration_cache.overhead_nanos = (double)(t_end - t_start) / (double)(probe_count + 1);
}

uint64_t ttzip_platform_raw_ticks(void) {
#if defined(TTZIP_OS_MACOS)
    return mach_absolute_time();
#elif defined(TTZIP_OS_WINDOWS)
    LARGE_INTEGER counter;
    QueryPerformanceCounter(&counter);
    return (uint64_t)counter.QuadPart;
#elif defined(TTZIP_OS_LINUX)
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC_RAW, &ts);
    return ((uint64_t)ts.tv_sec * 1000000000ULL) + (uint64_t)ts.tv_nsec;
#else
    return 0;
#endif
}

uint64_t ttzip_platform_ticks_to_nanos(uint64_t ticks) {
    if (!g_timer_initialized) {
        ttzip_platform_timer_init();
    }

#if defined(TTZIP_OS_MACOS)
    #if defined(__SIZEOF_INT128__)
        return (uint64_t)((((unsigned __int128)ticks) * g_darwin_tb.numer) / g_darwin_tb.denom);
    #else
        return (ticks / g_darwin_tb.denom) * g_darwin_tb.numer +
               ((ticks % g_darwin_tb.denom) * g_darwin_tb.numer) / g_darwin_tb.denom;
    #endif
#elif defined(TTZIP_OS_WINDOWS)
    #if defined(__SIZEOF_INT128__)
        return (uint64_t)((((unsigned __int128)ticks) * 1000000000ULL) / g_win_qpc_freq);
    #else
        return (ticks / g_win_qpc_freq) * 1000000000ULL +
               ((ticks % g_win_qpc_freq) * 1000000000ULL) / g_win_qpc_freq;
    #endif
#elif defined(TTZIP_OS_LINUX)
    return ticks;
#else
    return ticks;
#endif
}

uint64_t ttzip_platform_monotonic_nanos(void) {
#if defined(TTZIP_OS_MACOS)
    if (__builtin_expect(g_darwin_tb.denom == 0, 0)) {
        ttzip_platform_timer_init();
    }
    uint64_t ticks = mach_absolute_time();
    #if defined(__SIZEOF_INT128__)
        return (uint64_t)((((unsigned __int128)ticks) * g_darwin_tb.numer) / g_darwin_tb.denom);
    #else
        return (ticks / g_darwin_tb.denom) * g_darwin_tb.numer +
               ((ticks % g_darwin_tb.denom) * g_darwin_tb.numer) / g_darwin_tb.denom;
    #endif
#elif defined(TTZIP_OS_WINDOWS)
    if (g_win_qpc_freq == 0) {
        ttzip_platform_timer_init();
    }
    LARGE_INTEGER counter;
    QueryPerformanceCounter(&counter);
    uint64_t ticks = (uint64_t)counter.QuadPart;
    #if defined(__SIZEOF_INT128__)
        return (uint64_t)((((unsigned __int128)ticks) * 1000000000ULL) / g_win_qpc_freq);
    #else
        return (ticks / g_win_qpc_freq) * 1000000000ULL +
               ((ticks % g_win_qpc_freq) * 1000000000ULL) / g_win_qpc_freq;
    #endif
#elif defined(TTZIP_OS_LINUX)
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC_RAW, &ts);
    return ((uint64_t)ts.tv_sec * 1000000000ULL) + (uint64_t)ts.tv_nsec;
#else
    return 0;
#endif
}

void ttzip_platform_timer_get_calibration(ttzip_timer_calibration_t* out_calib) {
    if (!g_timer_initialized) {
        ttzip_platform_timer_init();
    }
    if (out_calib) {
        *out_calib = g_calibration_cache;
    }
}
