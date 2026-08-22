// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

extension ArchiveWriter {
    /// Dispatches compression requests targeting the ZIP archive format directly via Rust C-ABI.
    /// - Returns: `true` if the archive creation was handled and completed successfully, `false` otherwise.
    internal func dispatchZipCreation(
        outputPath: String,
        level: ArchiveCompressionLevel,
        inputPaths: [String],
        options: ArchiveFilterOptions,
        splitVolumeSizeBytes: Int64?,
        password: String?,
        advancedOptions: ArchiveAdvancedOptions,
        startTime: Date,
        totalBytes: Int64,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)?
    ) throws -> Bool {
        return createArchiveWithRust(
            outputPath: outputPath,
            format: .zip,
            inputPaths: inputPaths,
            level: level,
            password: password,
            splitVolumeSizeBytes: splitVolumeSizeBytes,
            skipMacJunk: options.skipMacJunk,
            startTime: startTime,
            totalBytes: totalBytes,
            progressHandler: progressHandler
        )
    }
}
