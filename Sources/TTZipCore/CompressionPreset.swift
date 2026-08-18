// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Value type representing a reusable user-defined compression preset configuration.
public struct CompressionPreset: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var format: ArchiveCompressionFormat
    public var level: ArchiveCompressionLevel
    public var splitVolumeSizeBytes: Int64? // nil means no multi-volume split (e.g. 20 * 1024 * 1024 * 1024 for 20GB)
    public var defaultPassword: String?
    public var skipMacJunk: Bool
    public var skipGitDirectory: Bool
    
    public init(
        id: UUID = UUID(),
        name: String,
        format: ArchiveCompressionFormat,
        level: ArchiveCompressionLevel,
        splitVolumeSizeBytes: Int64? = nil,
        defaultPassword: String? = nil,
        skipMacJunk: Bool = true,
        skipGitDirectory: Bool = false
    ) {
        self.id = id
        self.name = name
        self.format = format
        self.level = level
        self.splitVolumeSizeBytes = splitVolumeSizeBytes
        self.defaultPassword = defaultPassword
        self.skipMacJunk = skipMacJunk
        self.skipGitDirectory = skipGitDirectory
    }
    
    public var splitVolumeDescription: String {
        guard let bytes = splitVolumeSizeBytes, bytes > 0 else {
            return "Single Volume"
        }
        let gb = Double(bytes) / (1024.0 * 1024.0 * 1024.0)
        if gb >= 1.0 {
            return String(format: "%.0f GB Volume", gb)
        }
        let mb = Double(bytes) / (1024.0 * 1024.0)
        return String(format: "%.0f MB Volume", mb)
    }
}

// MARK: - PrototypeCopyable Prototype Pattern Extension
extension CompressionPreset: PrototypeCopyable {
    /// Creates an independent clone with a new UUID.
    public func clone() -> CompressionPreset {
        return clone(newId: UUID(), newName: nil)
    }
    
    /// Prototype copy with custom ID and optional new name.
    public func clone(newId: UUID = UUID(), newName: String? = nil) -> CompressionPreset {
        return CompressionPreset(
            id: newId,
            name: newName ?? self.name,
            format: self.format,
            level: self.level,
            splitVolumeSizeBytes: self.splitVolumeSizeBytes,
            defaultPassword: self.defaultPassword,
            skipMacJunk: self.skipMacJunk,
            skipGitDirectory: self.skipGitDirectory
        )
    }
}
