// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Unified 6-level archive operation status code hierarchy matching libarchive standard (`archive.h`).
public enum TTZipStatus: Int32, Sendable, Codable, Equatable {
    /// End of archive reached (`ARCHIVE_EOF`).
    case eof = 1
    
    /// Operation succeeded (`ARCHIVE_OK`).
    case ok = 0
    
    /// Transient retry requested (`ARCHIVE_RETRY`).
    case retry = -10
    
    /// Non-fatal warning (`ARCHIVE_WARN`).
    case warn = -20
    
    /// Non-fatal entry error with possible stream recovery (`ARCHIVE_FAILED`).
    case failed = -25
    
    /// Fatal unrecoverable error (`ARCHIVE_FATAL`).
    case fatal = -30
    
    public var isFatal: Bool {
        return self == .fatal
    }
    
    public var allowsDataRecovery: Bool {
        return self == .warn || self == .failed
    }
}

/// Archive engine internal lifecycle state machine flags.
public struct TTZipEngineState: OptionSet, Sendable {
    public let rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    public static let initial      = TTZipEngineState(rawValue: 1 << 0) // New handle
    public static let header       = TTZipEngineState(rawValue: 1 << 1) // Reading/writing entry header
    public static let data         = TTZipEngineState(rawValue: 1 << 2) // Reading/writing payload data
    public static let dataRecovery = TTZipEngineState(rawValue: 1 << 3) // Skipping damaged blocks in recovery mode
    public static let eof          = TTZipEngineState(rawValue: 1 << 4) // End of archive reached
    public static let closed       = TTZipEngineState(rawValue: 1 << 5) // Handle safely closed
    public static let fatalError   = TTZipEngineState(rawValue: 1 << 15) // Fatal error lock
}
