/**
 * @file CTTZipPlatformTimer.h
 * @brief 跨平台纳秒级单调硬件计时器与时钟校准接口
 * @details 对标 powturbo/TurboBench 与 inikep/lzbench 的硬件时钟抽象，
 *          macOS 直通 mach_absolute_time() 与 mach_timebase_info，
 *          Windows 直通 QueryPerformanceCounter 与 QueryPerformanceFrequency，
 *          POSIX 直通 clock_gettime(CLOCK_MONOTONIC_RAW)。
 * @version 1.0
 * @author TTZip Core Engineering Team
 */

#ifndef CTTZIP_PLATFORM_TIMER_H
#define CTTZIP_PLATFORM_TIMER_H

#include "ttzip_platform.h"
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief 平台硬件时钟校准信息结构体
 */
typedef struct {
    const char* platform_os;        /**< 操作系统标识 ("macOS", "Windows", "Linux") */
    const char* architecture;       /**< 处理器架构 ("arm64", "x86_64") */
    const char* timer_backend;      /**< 底层时钟接口名 */
    uint64_t    frequency_hz;       /**< 基础时钟频率 (Hz) */
    uint32_t    timebase_numer;     /**< 时基缩放分子 */
    uint32_t    timebase_denom;     /**< 时基缩放分母 */
    double      resolution_nanos;   /**< 单 tick 理论分辨率 (ns) */
    double      overhead_nanos;     /**< 单次计时函数调用平均开销 (ns) */
} ttzip_timer_calibration_t;

/**
 * @brief 初始化硬件计时器并缓存时钟频率与时基缩放比
 * @note 进程启动时调用一次，线程安全且幂等
 */
TTZIP_API void ttzip_platform_timer_init(void);

/**
 * @brief 获取当前绝对单调时间戳（纳秒）
 * @details 保证单调递增，无系统调用上下文切换，内部使用 128 位宽乘法防溢出
 * @return 自系统启动或固定时钟源以来的纳秒计数值
 */
TTZIP_API uint64_t ttzip_platform_monotonic_nanos(void);

/**
 * @brief 获取当前原始硬件 Tick 计数值
 * @return 原始 CPU / 系统计数器值 (mach ticks / QPC ticks)
 */
TTZIP_API uint64_t ttzip_platform_raw_ticks(void);

/**
 * @brief 将原始硬件 Tick 差值转换为纳秒
 * @param[in] ticks 硬件计数器差值 (t1 - t0)
 * @return 纳秒计数值
 */
TTZIP_API uint64_t ttzip_platform_ticks_to_nanos(uint64_t ticks);

/**
 * @brief 获取当前平台的硬件时钟校准诊断信息
 * @param[out] out_calib 指向接收校准信息的结构体指针
 */
TTZIP_API void ttzip_platform_timer_get_calibration(ttzip_timer_calibration_t* out_calib);

#ifdef __cplusplus
}
#endif

#endif /* CTTZIP_PLATFORM_TIMER_H */
