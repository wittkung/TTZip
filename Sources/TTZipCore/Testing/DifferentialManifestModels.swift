// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - Manifest Entry Types

/// File system entry type for manifest modeling.
public enum EntryType: String, Sendable, Equatable, Codable {
    case regularFile = "regular"
    case directory = "directory"
    case symbolicLink = "symlink"
    case hardLink = "hardlink"
}

/// Single record in a file tree manifest.
public struct ManifestEntry: Sendable, Equatable, Codable {
    public let relativePath: String
    public let entryType: EntryType
    public let byteSize: Int64
    public let sha256Checksum: String
    public let posixMode: UInt16
    public let symlinkTarget: String?

    public init(
        relativePath: String,
        entryType: EntryType,
        byteSize: Int64,
        sha256Checksum: String,
        posixMode: UInt16,
        symlinkTarget: String? = nil
    ) {
        self.relativePath = relativePath
        self.entryType = entryType
        self.byteSize = byteSize
        self.sha256Checksum = sha256Checksum
        self.posixMode = posixMode
        self.symlinkTarget = symlinkTarget
    }
}

// MARK: - File Tree Manifest

/// Complete manifest snapshot of an extracted directory tree for 1:1 bidirectional differential verification.
public struct FileTreeManifest: Sendable, Equatable, Codable {
    public let rootDirectory: String
    public let entries: [String: ManifestEntry]
    public let totalByteSize: Int64
    public let totalFileCount: Int
    public let totalDirectoryCount: Int
    public let totalSymlinkCount: Int

    public init(
        rootDirectory: String,
        entries: [String: ManifestEntry],
        totalByteSize: Int64,
        totalFileCount: Int,
        totalDirectoryCount: Int,
        totalSymlinkCount: Int
    ) {
        self.rootDirectory = rootDirectory
        self.entries = entries
        self.totalByteSize = totalByteSize
        self.totalFileCount = totalFileCount
        self.totalDirectoryCount = totalDirectoryCount
        self.totalSymlinkCount = totalSymlinkCount
    }
}

// MARK: - Differential Test Report

/// Bidirectional differential test execution report.
public struct DifferentialTestReport: Sendable, Equatable, Codable {
    public let format: ArchiveCompressionFormat
    public let targetOracle: String
    public let isPassed: Bool
    public let ttzipManifest: FileTreeManifest
    public let oracleManifest: FileTreeManifest
    public let divergenceErrors: [String]
    public let hexDiffOutput: String?

    public init(
        format: ArchiveCompressionFormat,
        targetOracle: String,
        isPassed: Bool,
        ttzipManifest: FileTreeManifest,
        oracleManifest: FileTreeManifest,
        divergenceErrors: [String],
        hexDiffOutput: String? = nil
    ) {
        self.format = format
        self.targetOracle = targetOracle
        self.isPassed = isPassed
        self.ttzipManifest = ttzipManifest
        self.oracleManifest = oracleManifest
        self.divergenceErrors = divergenceErrors
        self.hexDiffOutput = hexDiffOutput
    }
}
