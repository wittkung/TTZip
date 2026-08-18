// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Archive operation type for validation dispatch.
public enum ArchiveValidationOperation: String, Sendable, Codable, Equatable {
    case compress
    case extract
    case inspect
    case repair
}

/// Archive validation options configuration.
public struct ArchiveValidationOptions: Sendable, Equatable {
    public var isSplit: Bool
    public var splitVolumeSizeBytes: Int64?
    public var isEncrypted: Bool
    public var compressionLevel: ArchiveCompressionLevel
    public var skipMacJunk: Bool
    public var format: ArchiveCompressionFormat?
    
    public init(
        isSplit: Bool = false,
        splitVolumeSizeBytes: Int64? = nil,
        isEncrypted: Bool = false,
        compressionLevel: ArchiveCompressionLevel = .normal,
        skipMacJunk: Bool = true,
        format: ArchiveCompressionFormat? = nil
    ) {
        self.isSplit = isSplit || (splitVolumeSizeBytes != nil && splitVolumeSizeBytes! > 0)
        self.splitVolumeSizeBytes = splitVolumeSizeBytes
        self.isEncrypted = isEncrypted
        self.compressionLevel = compressionLevel
        self.skipMacJunk = skipMacJunk
        self.format = format
    }
}

/// Payload context passed across Chain of Responsibility validation handlers.
public struct ArchiveValidationContext: Sendable {
    public let sourcePaths: [String]
    public let destinationPath: String?
    public let operation: ArchiveValidationOperation
    public let format: ArchiveCompressionFormat?
    public let estimatedUncompressedSize: UInt64?
    public let password: String?
    public let options: ArchiveValidationOptions
    public var metadata: [String: String]
    
    public init(
        sourcePaths: [String],
        destinationPath: String? = nil,
        operation: ArchiveValidationOperation,
        format: ArchiveCompressionFormat? = nil,
        estimatedUncompressedSize: UInt64? = nil,
        password: String? = nil,
        options: ArchiveValidationOptions = ArchiveValidationOptions(),
        metadata: [String: String] = [:]
    ) {
        self.sourcePaths = sourcePaths
        self.destinationPath = destinationPath
        self.operation = operation
        self.format = format ?? options.format
        self.estimatedUncompressedSize = estimatedUncompressedSize
        self.password = password
        var updatedOptions = options
        if password != nil && !password!.isEmpty {
            updatedOptions.isEncrypted = true
        }
        if format != nil {
            updatedOptions.format = format
        }
        self.options = updatedOptions
        self.metadata = metadata
    }
    
    /// Factory for compression validation context.
    public static func forCompress(
        sourcePaths: [String],
        destinationPath: String,
        format: ArchiveCompressionFormat = .zip,
        level: ArchiveCompressionLevel = .normal,
        password: String? = nil,
        splitSize: Int64? = nil,
        options: ArchiveValidationOptions = ArchiveValidationOptions()
    ) -> ArchiveValidationContext {
        var opts = options
        opts.compressionLevel = level
        opts.splitVolumeSizeBytes = splitSize
        opts.isSplit = splitSize != nil && splitSize! > 0
        opts.isEncrypted = password != nil && !password!.isEmpty
        opts.format = format
        
        return ArchiveValidationContext(
            sourcePaths: sourcePaths,
            destinationPath: destinationPath,
            operation: .compress,
            format: format,
            password: password,
            options: opts
        )
    }
    
    /// Factory for extraction validation context.
    public static func forExtract(
        archivePath: String,
        destinationDir: String,
        password: String? = nil,
        estimatedSize: UInt64? = nil
    ) -> ArchiveValidationContext {
        return ArchiveValidationContext(
            sourcePaths: [archivePath],
            destinationPath: destinationDir,
            operation: .extract,
            estimatedUncompressedSize: estimatedSize,
            password: password
        )
    }
    
    /// Factory for inspection validation context.
    public static func forInspect(
        archivePath: String,
        password: String? = nil
    ) -> ArchiveValidationContext {
        return ArchiveValidationContext(
            sourcePaths: [archivePath],
            operation: .inspect,
            password: password
        )
    }
    
    /// Factory for repair validation context.
    public static func forRepair(
        damagedPath: String,
        outputPath: String
    ) -> ArchiveValidationContext {
        return ArchiveValidationContext(
            sourcePaths: [damagedPath],
            destinationPath: outputPath,
            operation: .repair
        )
    }
}
