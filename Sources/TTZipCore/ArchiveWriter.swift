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
        
        let template = ArchiveEngineTemplateRegistry.shared.template(for: format)
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
        _ = try await template.performWorkflowAsync(context: context)
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
        let template = ArchiveEngineTemplateRegistry.shared.template(for: format)
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
        _ = try template.performWorkflow(context: context)
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
}
