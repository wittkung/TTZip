// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// High-performance multi-core block-parallel ZIP archive creation engine.
///
/// Integrates with ZipCompressionProfile and native C bridge for maximum throughput.
public final class ZipExtremeBlockWriter: @unchecked Sendable {
    public static let shared = ZipExtremeBlockWriter()
    
    public static let defaultBlockSize: Int = 1024 * 1024 // 1 MB per chunk
    
    private init() {}
    
    /// Creates a ZIP archive using multi-core block parallelism for large files with a strong-typed profile.
    public func createExtremeArchive(
        outputPath: String,
        inputPath: String,
        profile: ZipCompressionProfile,
        blockSize: Int = 0
    ) throws -> Bool {
        return try createExtremeArchive(
            outputPath: outputPath,
            inputPath: inputPath,
            level: profile.level,
            customProfile: profile,
            blockSize: blockSize
        )
    }

    /// Creates a ZIP archive using multi-core parallelism for files.
    public func createExtremeArchive(
        outputPath: String,
        inputPath: String,
        level: ArchiveCompressionLevel = .fastest,
        customProfile: ZipCompressionProfile? = nil,
        blockSize: Int = 0 // 0 = 基于香农熵与硬件缓存自适应推导
    ) throws -> Bool {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: inputPath) else { return false }
        
        let activeProfile = customProfile ?? level.zipProfile
        return try ZipParallelWriter.shared.createArchive(
            outputPath: outputPath,
            inputPaths: [inputPath],
            level: activeProfile.level
        )
    }
}
