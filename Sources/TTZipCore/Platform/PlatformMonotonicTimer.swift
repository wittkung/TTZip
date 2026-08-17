import Foundation
import CTTZipBridge

/// 跨平台高精度单调硬件计时器与时钟校准服务
/// 对标 TurboBench / lzbench 纳秒级无锁单调时钟规范，彻底替代 QuartzCore `CACurrentMediaTime()`。
public final class PlatformMonotonicTimer: Sendable {
    public static let shared = PlatformMonotonicTimer()

    private init() {
        ttzip_platform_timer_init()
    }

    /// 强制执行时钟系统初始化并缓存硬件时钟基准
    @inline(__always)
    public static func initialize() {
        _ = shared
    }

    /// 获取当前单调时间戳（纳秒，UInt64）
    @inline(__always)
    public static func nowNanoseconds() -> UInt64 {
        return ttzip_platform_monotonic_nanos()
    }

    /// 获取当前单调时间戳（秒，Double，纳秒精度浮点）
    @inline(__always)
    public static func nowSeconds() -> Double {
        return Double(ttzip_platform_monotonic_nanos()) / 1_000_000_000.0
    }

    /// 获取当前底层硬件原始 Tick 计数
    @inline(__always)
    public static func rawTicks() -> UInt64 {
        return ttzip_platform_raw_ticks()
    }

    /// 将硬件原始 Tick 差值转换为纳秒
    @inline(__always)
    public static func ticksToNanoseconds(_ ticks: UInt64) -> UInt64 {
        return ttzip_platform_ticks_to_nanos(ticks)
    }

    /// 将硬件原始 Tick 差值转换为秒
    @inline(__always)
    public static func ticksToSeconds(_ ticks: UInt64) -> Double {
        return Double(ttzip_platform_ticks_to_nanos(ticks)) / 1_000_000_000.0
    }

    /// 获取当前宿主平台的硬件时钟校准与精度诊断信息
    public static func calibrationInfo() -> PlatformTimerCalibrationInfo {
        initialize()
        var calib = ttzip_timer_calibration_t()
        ttzip_platform_timer_get_calibration(&calib)

        let osStr = calib.platform_os != nil ? String(cString: calib.platform_os) : "Unknown"
        let archStr = calib.architecture != nil ? String(cString: calib.architecture) : "Unknown"
        let backendStr = calib.timer_backend != nil ? String(cString: calib.timer_backend) : "Unknown"

        return PlatformTimerCalibrationInfo(
            platformOS: osStr,
            architecture: archStr,
            timerBackend: backendStr,
            frequencyHz: calib.frequency_hz,
            timebaseNumer: calib.timebase_numer,
            timebaseDenom: calib.timebase_denom,
            resolutionNanos: calib.resolution_nanos,
            overheadNanos: calib.overhead_nanos
        )
    }

    /// 同步代码块的高精度纳秒测时
    @inline(__always)
    public static func measure<T>(_ block: () throws -> T) rethrows -> (result: T, elapsedNanos: UInt64, elapsedSeconds: Double) {
        let t0 = ttzip_platform_monotonic_nanos()
        let result = try block()
        let t1 = ttzip_platform_monotonic_nanos()
        let elapsedNanos = (t1 >= t0) ? (t1 - t0) : 1
        let elapsedSec = Double(elapsedNanos) / 1_000_000_000.0
        return (result, elapsedNanos, elapsedSec)
    }

    /// 异步代码块的高精度纳秒测时
    @inline(__always)
    public static func measureAsync<T>(_ block: () async throws -> T) async rethrows -> (result: T, elapsedNanos: UInt64, elapsedSeconds: Double) {
        let t0 = ttzip_platform_monotonic_nanos()
        let result = try await block()
        let t1 = ttzip_platform_monotonic_nanos()
        let elapsedNanos = (t1 >= t0) ? (t1 - t0) : 1
        let elapsedSec = Double(elapsedNanos) / 1_000_000_000.0
        return (result, elapsedNanos, elapsedSec)
    }
}
