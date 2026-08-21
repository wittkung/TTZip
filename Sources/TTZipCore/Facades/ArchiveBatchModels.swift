// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - Batch Task Models

/// Batch compression task specification.
public struct BatchCompressTask: Identifiable, Sendable {
    public let id: UUID
    public let inputs: [String]
    public let outputPath: String
    public let format: ArchiveCompressionFormat
    public let level: ArchiveCompressionLevel
    public let password: String?
    public let splitSize: Int64?
    
    public init(
        id: UUID = UUID(),
        inputs: [String],
        outputPath: String,
        format: ArchiveCompressionFormat = .zip,
        level: ArchiveCompressionLevel = .normal,
        password: String? = nil,
        splitSize: Int64? = nil
    ) {
        self.id = id
        self.inputs = inputs
        self.outputPath = outputPath
        self.format = format
        self.level = level
        self.password = password
        self.splitSize = splitSize
    }
}

/// Batch extraction task specification.
public struct BatchExtractTask: Identifiable, Sendable {
    public let id: UUID
    public let archivePath: String
    public let destinationDir: String
    public let password: String?
    
    public init(
        id: UUID = UUID(),
        archivePath: String,
        destinationDir: String,
        password: String? = nil
    ) {
        self.id = id
        self.archivePath = archivePath
        self.destinationDir = destinationDir
        self.password = password
    }
}

/// Outcome payload for a batch task execution.
public struct BatchTaskResult: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let success: Bool
    public let targetPath: String
    public let durationSeconds: Double
    public let errorMessage: String?
    
    public init(
        id: UUID,
        success: Bool,
        targetPath: String,
        durationSeconds: Double,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.success = success
        self.targetPath = targetPath
        self.durationSeconds = durationSeconds
        self.errorMessage = errorMessage
    }
}
