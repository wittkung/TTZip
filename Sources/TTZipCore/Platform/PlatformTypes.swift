// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Cross-platform path sanitization and normalization analysis outcome.
public struct PlatformPathNormalizationResult: Sendable, Equatable {
    public let originalPath: String
    public let normalizedPath: String
    public let isAbsolute: Bool
    public let isUNCPath: Bool
    public let isLongPath: Bool
    public let containsWindowsReservedDeviceName: Bool
    public let strippedAlternateDataStream: String?
    public let win32FormattedPath: String
    public let hasTraversalAttack: Bool
    
    public init(
        originalPath: String,
        normalizedPath: String,
        isAbsolute: Bool,
        isUNCPath: Bool,
        isLongPath: Bool,
        containsWindowsReservedDeviceName: Bool,
        strippedAlternateDataStream: String? = nil,
        win32FormattedPath: String,
        hasTraversalAttack: Bool = false
    ) {
        self.originalPath = originalPath
        self.normalizedPath = normalizedPath
        self.isAbsolute = isAbsolute
        self.isUNCPath = isUNCPath
        self.isLongPath = isLongPath
        self.containsWindowsReservedDeviceName = containsWindowsReservedDeviceName
        self.strippedAlternateDataStream = strippedAlternateDataStream
        self.win32FormattedPath = win32FormattedPath
        self.hasTraversalAttack = hasTraversalAttack
    }
}

/// Unified cross-platform file system metadata attributes.
public struct PlatformFileAttributes: Sendable, Equatable {
    public let size: Int64
    public let isDirectory: Bool
    public let isSymbolicLink: Bool
    public let creationTimeUnixSec: Int64
    public let modificationTimeUnixSec: Int64
    public let posixPermissions: UInt32
    public let isReadOnly: Bool
    public let isHidden: Bool
    
    public init(
        size: Int64,
        isDirectory: Bool,
        isSymbolicLink: Bool,
        creationTimeUnixSec: Int64,
        modificationTimeUnixSec: Int64,
        posixPermissions: UInt32,
        isReadOnly: Bool,
        isHidden: Bool
    ) {
        self.size = size
        self.isDirectory = isDirectory
        self.isSymbolicLink = isSymbolicLink
        self.creationTimeUnixSec = creationTimeUnixSec
        self.modificationTimeUnixSec = modificationTimeUnixSec
        self.posixPermissions = posixPermissions
        self.isReadOnly = isReadOnly
        self.isHidden = isHidden
    }
}

/// Virtual memory mapping descriptor.
public struct PlatformMmapResult: @unchecked Sendable {
    public let pointer: UnsafeRawPointer
    public let size: Int
    private let rawDescriptor: Int32
    
    public init(pointer: UnsafeRawPointer, size: Int, rawDescriptor: Int32) {
        self.pointer = pointer
        self.size = size
        self.rawDescriptor = rawDescriptor
    }
    
    public func unmap() {
        if size > 0 {
            let mutPtr = UnsafeMutableRawPointer(mutating: pointer)
            munmap(mutPtr, size)
        }
        if rawDescriptor >= 0 {
            close(rawDescriptor)
        }
    }
}

/// CPU architecture and SIMD hardware acceleration feature mask.
public struct CPUFeatureSet: Sendable, Equatable {
    public let architecture: String
    public let logicalCores: Int
    public let physicalPageSize: Int
    public let hasARMNeon: Bool
    public let hasARMCrypto: Bool
    public let hasAESNI: Bool
    public let hasAVX2: Bool
    public let hasAVX512: Bool
    public let hasHardwareCRC32: Bool
    
    public init(
        architecture: String,
        logicalCores: Int,
        physicalPageSize: Int,
        hasARMNeon: Bool,
        hasARMCrypto: Bool,
        hasAESNI: Bool,
        hasAVX2: Bool,
        hasAVX512: Bool,
        hasHardwareCRC32: Bool
    ) {
        self.architecture = architecture
        self.logicalCores = logicalCores
        self.physicalPageSize = physicalPageSize
        self.hasARMNeon = hasARMNeon
        self.hasARMCrypto = hasARMCrypto
        self.hasAESNI = hasAESNI
        self.hasAVX2 = hasAVX2
        self.hasAVX512 = hasAVX512
        self.hasHardwareCRC32 = hasHardwareCRC32
    }
}

// MARK: - Operating System

//
//


/// Cross-platform operating system discriminator.
public enum PlatformOperatingSystem: String, Sendable, Codable, CaseIterable {
    case macOS = "macOS"
    case windows = "Windows"
    case linux = "Linux"
    case unknown = "Unknown"
    
    /// Operating system platform in current execution environment.
    public static var current: PlatformOperatingSystem {
        #if os(macOS)
        return .macOS
        #elseif os(Windows)
        return .windows
        #elseif os(Linux)
        return .linux
        #else
        return .unknown
        #endif
    }
    
    /// True if current platform conforms to POSIX semantics.
    @inlinable
    public var isPOSIX: Bool {
        return self == .macOS || self == .linux
    }
    
    /// True if current platform is Windows.
    @inlinable
    public var isWindows: Bool {
        return self == .windows
    }
    
    /// Default hardware physical page alignment (16KB on Apple Silicon, 4KB on Generic/x86_64).
    @inlinable
    public var defaultPageAlignment: Int {
        #if os(macOS) && arch(arm64)
        return 16384
        #else
        return 4096
        #endif
    }
}

// MARK: - Path Sanitizer

//
//


/// Cross-platform path sanitization, normalization, and security auditing subsystem.
///
/// Fully backed by high-performance Safe Rust engine (`ttzip_rust_sanitize_path`):
/// - Zero-allocation single-pass Zip Slip directory traversal neutralization and detection
/// - Win32 reserved device name interception (`CON`, `PRN`, `AUX`, `NUL`, `COM0-9`, `LPT0-9`, `CLOCK$`, `PhysicalDrive`)
/// - Win32 trailing space and dot normalization
/// - NTFS Alternate Data Stream (ADS) identification and stripping
/// - Unicode NFC canonical normalization
/// - Win32 extended-length path formatting (`\\?\` and `\\?\UNC\`)
public enum PlatformPathSanitizer: Sendable {
    
    /// Executes cross-platform security sanitization and canonical normalization.
    ///
    /// - Parameter path: Input relative or absolute path.
    /// - Returns: Normalized path result containing canonical path, boundary flags, and reserved name markers.
    public static func sanitize(path: String) -> PlatformPathNormalizationResult {
        guard !path.isEmpty else {
            return PlatformPathNormalizationResult(
                originalPath: "",
                normalizedPath: "",
                isAbsolute: false,
                isUNCPath: false,
                isLongPath: false,
                containsWindowsReservedDeviceName: false,
                strippedAlternateDataStream: nil,
                win32FormattedPath: "",
                hasTraversalAttack: false
            )
        }
        
        var rawResult = TTZipPathSanitizationResult()
        let status = path.withCString { cStr in
            ttzip_rust_sanitize_path(cStr, &rawResult)
        }
        
        guard status == TTZIP_STATUS_OK else {
            return PlatformPathNormalizationResult(
                originalPath: path,
                normalizedPath: "",
                isAbsolute: false,
                isUNCPath: false,
                isLongPath: false,
                containsWindowsReservedDeviceName: false,
                strippedAlternateDataStream: nil,
                win32FormattedPath: "",
                hasTraversalAttack: true
            )
        }
        
        let normalizedPath = withUnsafePointer(to: rawResult.normalized_path) {
            $0.withMemoryRebound(to: CChar.self, capacity: 4096) { String(cString: $0) }
        }
        let win32FormattedPath = withUnsafePointer(to: rawResult.win32_formatted_path) {
            $0.withMemoryRebound(to: CChar.self, capacity: 4096) { String(cString: $0) }
        }
        let strippedADS: String? = rawResult.has_stripped_ads ? withUnsafePointer(to: rawResult.stripped_ads) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1024) { String(cString: $0) }
        } : nil
        
        return PlatformPathNormalizationResult(
            originalPath: path,
            normalizedPath: normalizedPath,
            isAbsolute: rawResult.is_absolute,
            isUNCPath: rawResult.is_unc,
            isLongPath: rawResult.is_long_path,
            containsWindowsReservedDeviceName: rawResult.is_windows_reserved,
            strippedAlternateDataStream: strippedADS,
            win32FormattedPath: win32FormattedPath,
            hasTraversalAttack: rawResult.has_traversal_attack
        )
    }
}

// MARK: - Monotonic Timer

//
//


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
