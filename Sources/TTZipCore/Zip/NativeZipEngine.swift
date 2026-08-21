// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

private final class MmapZipAccumulator: @unchecked Sendable {
    var entries: [ArchiveEntry] = []
}

/// Unified facade for native parallel ZIP compression, decompression, and memory-mapped inspection.
public final class NativeZipEngine: @unchecked Sendable {
    public static let shared = NativeZipEngine()
    
    private init() {}
    
    // MARK: - 1. Zero-Copy mmap Central Directory Inspection (<1ms table lookup)
    
    public func inspectZip(archivePath: String) -> [ArchiveEntry]? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: archivePath), options: .alwaysMapped) else {
            return nil
        }
        return data.withUnsafeBytes { rawIn -> [ArchiveEntry]? in
            guard let bytePtr = rawIn.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return nil }
            guard let descs = ZipCentralDirectoryReader.shared.readDescriptors(from: bytePtr, fileSize: data.count, skipMacJunk: false) else {
                return nil
            }
            return descs.map { d in
                ArchiveEntry(
                    path: d.path,
                    uncompressedSize: d.uncompressedSize,
                    isDirectory: d.isDirectory,
                    detectedEncoding: "UTF-8",
                    isEncrypted: d.isEncrypted
                )
            }
        }
    }
    
    // MARK: - 2. Multi-Core Parallel libdeflate Decompression Engine
    
    public func extractZipParallel(
        archivePath: String,
        destinationDir: String,
        password: String? = nil,
        skipMacJunk: Bool = true,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws -> Bool {
        return try ZipParallelExtractor.shared.extract(
            archivePath: archivePath,
            destinationDir: destinationDir,
            password: password,
            skipMacJunk: skipMacJunk,
            progressHandler: progressHandler
        )
    }
    
    // MARK: - 3. Multi-Core Parallel libdeflate Compression Engine
    
    public func createZipParallel(
        outputPath: String,
        inputPaths: [String],
        level: ArchiveCompressionLevel = .normal,
        skipMacJunk: Bool = true,
        password: String? = nil,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws -> Bool {
        return try ZipParallelWriter.shared.createArchive(
            outputPath: outputPath,
            inputPaths: inputPaths,
            level: level,
            skipMacJunk: skipMacJunk,
            password: password,
            progressHandler: progressHandler
        )
    }
}
