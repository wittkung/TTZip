// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

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
