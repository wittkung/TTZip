// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// Fast parallel 7z archive creation facade directly interfacing with native C/Rust engine.
public final class SevenZipParallelWriter: @unchecked Sendable {
    public static let shared = SevenZipParallelWriter()
    
    private init() {}
    
    /// Creates a 7z archive directly via `SevenZipCAdapter`.
    @inline(__always)
    public func createArchive(
        outputPath: String,
        inputPaths: [String],
        level: ArchiveCompressionLevel = .normal,
        password: String? = nil,
        useZstd: Bool = false,
        solidBlockSizeMb: Int = 128,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws -> Bool {
        return try SevenZipCAdapter.shared.createArchive(
            outputPath: outputPath,
            inputPaths: inputPaths,
            level: level,
            password: password,
            useZstd: useZstd,
            solidBlockSizeMb: solidBlockSizeMb,
            progressHandler: progressHandler
        )
    }
    
    /// Extracts a 7z archive directly via `SevenZipCAdapter`.
    @inline(__always)
    public func extractArchive(
        archivePath: String,
        destinationDir: String,
        password: String? = nil
    ) throws -> Bool {
        return try SevenZipCAdapter.shared.extractArchive(
            archivePath: archivePath,
            destinationDir: destinationDir,
            skipMacJunk: true,
            password: password
        )
    }
}
