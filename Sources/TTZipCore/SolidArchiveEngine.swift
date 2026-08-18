// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// 7-Zip solid archiving and solid block optimization engine.
public final class SolidArchiveEngine: @unchecked Sendable {
    public init() {}
    
    /// Packs homogeneous input files into a unified solid archive block to eliminate cross-file redundancy.
    public func createSolidArchive(
        outputPath: String,
        inputPaths: [String],
        format: ArchiveCompressionFormat = .sevenZip,
        dictionarySizeMB: Int = 1024
    ) async throws {
        guard !inputPaths.isEmpty else {
            throw ArchiveError.readFailed(code: -10)
        }
        
        let writer = ArchiveEngineFactory.makeWriter(for: format)
        _ = try await ArchivePipelineBuilder()
            .withWriter(writer)
            .withOutputPath(outputPath)
            .withFormat(format)
            .withLevel(.ultra)
            .withInputPaths(inputPaths)
            .configureOptions { builder in
                builder = builder
                    .withAlgorithm("LZMA2")
                    .withDictionarySizeMB(dictionarySizeMB)
                    .withCpuThreads(AppleSiliconTuner.shared.optimalBurstThreads)
                    .withSolidArchive(true)
                    .withEncryptFileNames(false)
                    .withZstdLevel(3)
                    .withZstdEnableLDM(true)
            }
            .executeCreate()
    }
}
