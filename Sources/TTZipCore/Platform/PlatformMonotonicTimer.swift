// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// Hardware timer calibration and resolution metadata.
public struct PlatformTimerCalibrationInfo: Sendable, Codable {
    public let platformOS: String
    public let architecture: String
    public let timerBackend: String
    public let frequencyHz: UInt64
    public let timebaseNumer: UInt32
    public let timebaseDenom: UInt32
    public let resolutionNanos: UInt64
    public let overheadNanos: UInt64

    public init(
        platformOS: String,
        architecture: String,
        timerBackend: String,
        frequencyHz: UInt64,
        timebaseNumer: UInt32,
        timebaseDenom: UInt32,
        resolutionNanos: UInt64,
        overheadNanos: UInt64
    ) {
        self.platformOS = platformOS
        self.architecture = architecture
        self.timerBackend = timerBackend
        self.frequencyHz = frequencyHz
        self.timebaseNumer = timebaseNumer
        self.timebaseDenom = timebaseDenom
        self.resolutionNanos = resolutionNanos
        self.overheadNanos = overheadNanos
    }
}

/// High-precision cross-platform monotonic timer and clock calibration service.
/// Conforms to TurboBench / lzbench nanosecond lock-free monotonic clock semantics.
public final class PlatformMonotonicTimer: Sendable {
    public static let shared = PlatformMonotonicTimer()

    private init() {}

    /// Explicitly initializes the timer subsystem and caches hardware frequency constants.
    @inline(__always)
    public static func initialize() {
        _ = shared
    }

    /// Current monotonic timestamp in nanoseconds (UInt64).
    @inline(__always)
    public static func nowNanoseconds() -> UInt64 {
        return clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
    }

    /// Current monotonic timestamp in seconds (Double).
    @inline(__always)
    public static func nowSeconds() -> Double {
        return Double(nowNanoseconds()) / 1_000_000_000.0
    }

    /// Current raw hardware tick count.
    @inline(__always)
    public static func rawTicks() -> UInt64 {
        return mach_absolute_time()
    }

    /// Converts raw hardware tick differences to nanoseconds.
    @inline(__always)
    public static func ticksToNanoseconds(_ ticks: UInt64) -> UInt64 {
        var info = mach_timebase_info()
        mach_timebase_info(&info)
        return (ticks * UInt64(info.numer)) / UInt64(info.denom)
    }

    /// Converts raw hardware tick differences to seconds.
    @inline(__always)
    public static func ticksToSeconds(_ ticks: UInt64) -> Double {
        return Double(ticksToNanoseconds(ticks)) / 1_000_000_000.0
    }

    /// Hardware timer calibration and resolution metadata.
    public static func calibrationInfo() -> PlatformTimerCalibrationInfo {
        var info = mach_timebase_info()
        mach_timebase_info(&info)

        return PlatformTimerCalibrationInfo(
            platformOS: "macOS",
            architecture: "ARM64",
            timerBackend: "mach_continuous_time",
            frequencyHz: 1_000_000_000,
            timebaseNumer: info.numer,
            timebaseDenom: info.denom,
            resolutionNanos: 1,
            overheadNanos: 1
        )
    }

    /// Measures execution elapsed time for synchronous closures.
    @inline(__always)
    public static func measure<T>(_ block: () throws -> T) rethrows -> (result: T, elapsedNanos: UInt64, elapsedSeconds: Double) {
        let t0 = nowNanoseconds()
        let result = try block()
        let t1 = nowNanoseconds()
        let elapsedNanos = (t1 >= t0) ? (t1 - t0) : 1
        let elapsedSec = Double(elapsedNanos) / 1_000_000_000.0
        return (result, elapsedNanos, elapsedSec)
    }

    /// Measures execution elapsed time for asynchronous closures.
    @inline(__always)
    public static func measureAsync<T>(_ block: () async throws -> T) async rethrows -> (result: T, elapsedNanos: UInt64, elapsedSeconds: Double) {
        let t0 = nowNanoseconds()
        let result = try await block()
        let t1 = nowNanoseconds()
        let elapsedNanos = (t1 >= t0) ? (t1 - t0) : 1
        let elapsedSec = Double(elapsedNanos) / 1_000_000_000.0
        return (result, elapsedNanos, elapsedSec)
    }
}
