// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Unified facade for 7z native parallel compression and decompression operations.
public final class NativeSevenZipEngine: @unchecked Sendable {
    public static let shared = NativeSevenZipEngine()
    
    private init() {}
    
    /// Parses 7z archive header and returns entry descriptors.
    public func inspectSevenZip(archivePath: String, password: String? = nil) -> [ArchiveEntry]? {
        let fd = open(archivePath, O_RDONLY)
        if fd < 0 { return nil }
        defer { close(fd) }
        
        var st = stat()
        if fstat(fd, &st) != 0 || st.st_size < 32 { return nil }
        let fileSize = size_t(st.st_size)
        
        guard let mapped = mmap(nil, fileSize, PROT_READ, MAP_SHARED, fd, 0), mapped != MAP_FAILED else {
            return nil
        }
        let bytePtr = mapped.assumingMemoryBound(to: UInt8.self)
        defer { munmap(mapped, fileSize) }
        
        guard let descriptors = SevenZipHeaderReader.shared.readDescriptors(from: bytePtr, fileSize: fileSize) else {
            return nil
        }
        
        return descriptors.map { desc in
            ArchiveEntry(
                path: desc.path,
                uncompressedSize: desc.uncompressedSize,
                isDirectory: desc.isDirectory,
                detectedEncoding: "UTF-8",
                modificationDate: Date()
            )
        }
    }
    
    /// Extracts 7z archive using multi-core solid block zero-copy pipeline.
    public func extractSevenZipParallel(
        archivePath: String,
        destinationDir: String,
        password: String? = nil,
        skipMacJunk: Bool = true,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws -> Bool {
        return try SevenZipParallelExtractor.shared.extract(
            archivePath: archivePath,
            destinationDir: destinationDir,
            password: password,
            skipMacJunk: skipMacJunk,
            progressHandler: progressHandler
        )
    }
    
    /// Compresses input paths into 7z archive using multi-core solid block pipeline.
    public func createSevenZipParallel(
        outputPath: String,
        inputPaths: [String],
        level: ArchiveCompressionLevel = .normal,
        password: String? = nil,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws -> Bool {
        return try SevenZipParallelWriter.shared.createArchive(
            outputPath: outputPath,
            inputPaths: inputPaths,
            level: level,
            password: password,
            progressHandler: progressHandler
        )
    }
}
