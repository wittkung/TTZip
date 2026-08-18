// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// High-precision cross-platform monotonic timer and clock calibration service.
/// Conforms to TurboBench / lzbench nanosecond lock-free monotonic clock semantics.
public final class PlatformMonotonicTimer: Sendable {
    public static let shared = PlatformMonotonicTimer()

    private init() {
        ttzip_platform_timer_init()
    }

    /// Explicitly initializes the timer subsystem and caches hardware frequency constants.
    @inline(__always)
    public static func initialize() {
        _ = shared
    }

    /// Current monotonic timestamp in nanoseconds (UInt64).
    @inline(__always)
    public static func nowNanoseconds() -> UInt64 {
        return ttzip_platform_monotonic_nanos()
    }

    /// Current monotonic timestamp in seconds (Double).
    @inline(__always)
    public static func nowSeconds() -> Double {
        return Double(ttzip_platform_monotonic_nanos()) / 1_000_000_000.0
    }

    /// Current raw hardware tick count.
    @inline(__always)
    public static func rawTicks() -> UInt64 {
        return ttzip_platform_raw_ticks()
    }

    /// Converts raw hardware tick differences to nanoseconds.
    @inline(__always)
    public static func ticksToNanoseconds(_ ticks: UInt64) -> UInt64 {
        return ttzip_platform_ticks_to_nanos(ticks)
    }

    /// Converts raw hardware tick differences to seconds.
    @inline(__always)
    public static func ticksToSeconds(_ ticks: UInt64) -> Double {
        return Double(ttzip_platform_ticks_to_nanos(ticks)) / 1_000_000_000.0
    }

    /// Hardware timer calibration and resolution metadata.
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

    /// Measures execution elapsed time for synchronous closures.
    @inline(__always)
    public static func measure<T>(_ block: () throws -> T) rethrows -> (result: T, elapsedNanos: UInt64, elapsedSeconds: Double) {
        let t0 = ttzip_platform_monotonic_nanos()
        let result = try block()
        let t1 = ttzip_platform_monotonic_nanos()
        let elapsedNanos = (t1 >= t0) ? (t1 - t0) : 1
        let elapsedSec = Double(elapsedNanos) / 1_000_000_000.0
        return (result, elapsedNanos, elapsedSec)
    }

    /// Measures execution elapsed time for asynchronous closures.
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
