// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CryptoKit
import CTTZipBridge

/// High-performance multi-format archive compression engine.
public final class ArchiveWriter: ArchiveWriting, @unchecked Sendable {
    internal let zipEngine: ZipEngineProtocol
    internal let sevenZipEngine: SevenZipEngineProtocol
    internal let zstdEngine: ZstdEngineProtocol
    internal let hardwareTuner: HardwareTunerProtocol
    public let targetFormat: ArchiveCompressionFormat?
    
    public init(
        zipEngine: ZipEngineProtocol = NativeZipEngine.shared,
        sevenZipEngine: SevenZipEngineProtocol = SevenZipParallelWriter.shared,
        zstdEngine: ZstdEngineProtocol = NativeZstdEngine.shared,
        hardwareTuner: HardwareTunerProtocol = ArchiveEngineFamilyProvider.shared.currentFactory.tuner,
        targetFormat: ArchiveCompressionFormat? = nil
    ) {
        self.zipEngine = zipEngine
        self.sevenZipEngine = sevenZipEngine
        self.zstdEngine = zstdEngine
        self.hardwareTuner = hardwareTuner
        self.targetFormat = targetFormat
    }
    
    /// Asynchronously compresses files and directories into an archive with validation and progress tracking.
    public func createArchive(
        outputPath: String,
        format: ArchiveCompressionFormat = .zip,
        level: ArchiveCompressionLevel = .normal,
        inputPaths: [String],
        options: ArchiveFilterOptions = .defaultClean,
        splitVolumeSizeBytes: Int64? = nil,
        password: String? = nil,
        advancedOptions: ArchiveAdvancedOptions = .defaultOptions,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) async throws {
        guard !inputPaths.isEmpty else {
            throw ArchiveError.readFailed(code: -10)
        }
        
        let valCtx = ArchiveValidationContext.forCompress(
            sourcePaths: inputPaths,
            destinationPath: outputPath,
            format: format,
            level: level,
            password: password,
            splitSize: splitVolumeSizeBytes,
            options: ArchiveValidationOptions(
                isSplit: splitVolumeSizeBytes != nil && splitVolumeSizeBytes! > 0,
                splitVolumeSizeBytes: splitVolumeSizeBytes,
                isEncrypted: password != nil && !password!.isEmpty,
                compressionLevel: level,
                skipMacJunk: options.skipMacJunk,
                format: format
            )
        )
        try ArchiveValidationPipeline.buildDefaultCompressPipeline().validateOrThrow(context: valCtx)
        
        if level == .ultra && !LicenseManager.shared.canUseFeature(.ultraCompression) {
            throw ArchiveError.readFailed(code: -403)
        }
        
        try Task.checkCancellation()
        
        try await Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            try self.createArchiveSync(
                outputPath: outputPath,
                format: format,
                level: level,
                inputPaths: inputPaths,
                options: options,
                password: password,
                splitVolumeSizeBytes: splitVolumeSizeBytes,
                advancedOptions: advancedOptions,
                progressHandler: progressHandler
            )
        }.value
    }

    /// Synchronously creates an archive bypassing Task queue context-switches.
    @inline(__always)
    public func createArchiveSync(
        outputPath: String,
        format: ArchiveCompressionFormat = .zip,
        level: ArchiveCompressionLevel = .normal,
        inputPaths: [String],
        options: ArchiveFilterOptions = .defaultClean,
        password: String? = nil,
        splitVolumeSizeBytes: Int64? = nil,
        advancedOptions: ArchiveAdvancedOptions = .defaultOptions,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws {
        guard !inputPaths.isEmpty else {
            throw ArchiveError.readFailed(code: -10)
        }

        let startTime = Date()
        let totalBytes = inputPaths.reduce(Int64(0)) { $0 + Self.recursivePathSize(at: $1) }

        try createArchiveInternal(
            outputPath: outputPath,
            format: format,
            level: level,
            inputPaths: inputPaths,
            options: options,
            splitVolumeSizeBytes: splitVolumeSizeBytes,
            password: password,
            advancedOptions: advancedOptions,
            progressHandler: progressHandler,
            startTime: startTime,
            totalBytes: totalBytes
        )
    }

    /// Template Method Pattern execution of archive compression workflow.
    public func createArchiveViaTemplate(
        outputPath: String,
        format: ArchiveCompressionFormat = .zip,
        level: ArchiveCompressionLevel = .normal,
        inputPaths: [String],
        options: ArchiveFilterOptions = .defaultClean,
        splitVolumeSizeBytes: Int64? = nil,
        password: String? = nil,
        advancedOptions: ArchiveAdvancedOptions = .defaultOptions,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws -> WorkflowResult {
        let context = ArchiveTemplateContext(
            operation: .compress,
            archivePath: outputPath,
            inputPaths: inputPaths,
            format: format,
            level: level,
            password: password,
            options: options,
            advancedOptions: advancedOptions,
            splitVolumeSizeBytes: splitVolumeSizeBytes,
            progressHandler: progressHandler
        )
        let template = ArchiveEngineTemplateRegistry.shared.template(for: format)
        return try template.performWorkflow(context: context)
    }

    // MARK: - Format Mappings

    internal static func mapFormat(_ format: ArchiveCompressionFormat) -> TTZipArchiveFormat {
        switch format {
        case .sevenZip: return TTZIP_ARCHIVE_FORMAT_SEVEN_ZIP
        case .zip: return TTZIP_ARCHIVE_FORMAT_ZIP
        case .tar: return TTZIP_ARCHIVE_FORMAT_TAR
        case .tarGz, .gz: return TTZIP_ARCHIVE_FORMAT_TAR_GZ
        case .tarBz2, .bz2: return TTZIP_ARCHIVE_FORMAT_TAR_BZ2
        case .tarXz, .xz: return TTZIP_ARCHIVE_FORMAT_TAR_XZ
        case .tarZst, .zst: return TTZIP_ARCHIVE_FORMAT_TAR_ZSTD
        case .dmg: return TTZIP_ARCHIVE_FORMAT_DMG
        case .snappy: return TTZIP_ARCHIVE_FORMAT_SNAPPY
        default: return TTZIP_ARCHIVE_FORMAT_ZIP
        }
    }

    internal static func mapLevel(_ level: ArchiveCompressionLevel) -> TTZipCompressionLevel {
        switch level {
        case .store: return TTZIP_COMPRESSION_LEVEL_STORE
        case .fastest: return TTZIP_COMPRESSION_LEVEL_FASTEST
        case .fast: return TTZIP_COMPRESSION_LEVEL_FAST
        case .normal: return TTZIP_COMPRESSION_LEVEL_NORMAL
        case .maximum: return TTZIP_COMPRESSION_LEVEL_MAXIMUM
        case .ultra: return TTZIP_COMPRESSION_LEVEL_ULTRA
        default: return TTZIP_COMPRESSION_LEVEL_NORMAL
        }
    }
}
