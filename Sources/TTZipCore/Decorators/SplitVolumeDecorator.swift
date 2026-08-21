// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Concrete decorator adding multi-volume archive slice management.
open class SplitVolumeDecorator: ArchiveOperationDecorator, @unchecked Sendable {
    public var splitVolumeSizeBytes: Int64?

    public init(inner: ArchiveEngineImplementorProtocol, splitVolumeSizeBytes: Int64? = nil) {
        self.splitVolumeSizeBytes = splitVolumeSizeBytes
        super.init(inner: inner)
    }

    open override func compressStream(
        inputPaths: [String],
        outputPath: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64 {
        guard let splitSize = splitVolumeSizeBytes, splitSize > 0 else {
            return try await super.compressStream(
                inputPaths: inputPaths,
                outputPath: outputPath,
                options: options
            )
        }

        TTLogger.debug("[SplitVolumeDecorator] Activating split-volume mode (max segment size: \(splitSize) B)...")

        let bytesWritten = try await super.compressStream(
            inputPaths: inputPaths,
            outputPath: outputPath,
            options: options
        )

        if bytesWritten > splitSize && FileManager.default.fileExists(atPath: outputPath) {
            TTLogger.debug("[SplitVolumeDecorator] Output size exceeds single volume limit (\(bytesWritten) B > \(splitSize) B). Slicing archive...")
            try ArchiveWriter.sliceArchiveIfNeeded(archivePath: outputPath, splitSizeBytes: splitSize)
        }

        return bytesWritten
    }

    open override func extractStream(
        archivePath: String,
        destinationDir: String,
        options: ArchiveAdvancedOptions
    ) async throws -> Int64 {
        let isMultiVolume = checkIsMultiVolume(archivePath: archivePath)
        if isMultiVolume {
            TTLogger.debug("[SplitVolumeDecorator] Multi-volume archive detected: \(archivePath)")
        }
        return try await super.extractStream(
            archivePath: archivePath,
            destinationDir: destinationDir,
            options: options
        )
    }

    private func checkIsMultiVolume(archivePath: String) -> Bool {
        let path = archivePath.lowercased()
        return path.contains(".7z.001") || path.contains(".z01") || path.contains(".part1.")
    }
}
