// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// High-performance multi-format archive compression engine (Ultra-Thin Rust C-ABI Facade).
public final class ArchiveWriter: ArchiveWriting, @unchecked Sendable {
    internal let hardwareTuner: HardwareTunerProtocol
    public let targetFormat: ArchiveCompressionFormat?

    public init(
        hardwareTuner: HardwareTunerProtocol = ArchiveEngineFamilyProvider.shared.currentFactory.tuner,
        targetFormat: ArchiveCompressionFormat? = nil
    ) {
        self.hardwareTuner = hardwareTuner
        self.targetFormat = targetFormat
    }

    /// Backward-compatible initializer accepting legacy engine parameters.
    public convenience init(
        zipEngine: Any? = nil,
        sevenZipEngine: Any? = nil,
        zstdEngine: Any? = nil,
        hardwareTuner: HardwareTunerProtocol = ArchiveEngineFamilyProvider.shared.currentFactory.tuner,
        targetFormat: ArchiveCompressionFormat? = nil
    ) {
        self.init(hardwareTuner: hardwareTuner, targetFormat: targetFormat)
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
        if (level == .ultra || level.rawValue >= 9) && !LicenseManager.shared.isPro {
            throw ArchiveError.readFailed(code: -403)
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
        case .aar: return TTZIP_ARCHIVE_FORMAT_LZFSE
        default: return TTZIP_ARCHIVE_FORMAT_ZIP
        }
    }

    internal static func mapLevel(_ level: ArchiveCompressionLevel) -> TTZipCompressionLevel {
        switch level {
        case .store: return TTZIP_COMPRESSION_LEVEL_STORE
        case .fastest, .fast: return TTZIP_COMPRESSION_LEVEL_FASTEST
        case .normal: return TTZIP_COMPRESSION_LEVEL_NORMAL
        case .maximum: return TTZIP_COMPRESSION_LEVEL_MAXIMUM
        case .ultra: return TTZIP_COMPRESSION_LEVEL_ULTRA
        default: return TTZIP_COMPRESSION_LEVEL_NORMAL
        }
    }
}
