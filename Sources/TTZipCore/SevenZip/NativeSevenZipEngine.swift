// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

private final class SevenZipEntryAccumulator: @unchecked Sendable {
    var entries: [ArchiveEntry] = []
}

private func nativeSevenZipEntryCallback(
    context: UnsafeMutableRawPointer?,
    cPathname: UnsafePointer<CChar>?,
    size: Int64,
    isDir: Bool
) {
    guard let context = context, let cPathname = cPathname else { return }
    let acc = Unmanaged<SevenZipEntryAccumulator>.fromOpaque(context).takeUnretainedValue()
    let rawLen = strlen(cPathname)
    let pathData = Data(bytes: cPathname, count: rawLen)
    let sanitizedPath = CharsetDetector.sanitizeFilename(bytes: pathData)
    let lastComp = (sanitizedPath as NSString).lastPathComponent
    if lastComp.hasPrefix("._") || lastComp == ".DS_Store" {
        return
    }
    let entry = ArchiveEntry(
        path: sanitizedPath,
        uncompressedSize: size,
        isDirectory: isDir,
        detectedEncoding: "UTF-8",
        isEncrypted: false
    )
    acc.entries.append(entry)
}

/// Unified facade for 7z native parallel compression and decompression operations.
public final class NativeSevenZipEngine: @unchecked Sendable {
    public static let shared = NativeSevenZipEngine()
    
    private init() {}
    
    /// Parses 7z archive header via zero-copy mmap and returns entry descriptors.
    public func inspectSevenZip(archivePath: String, password: String? = nil) -> [ArchiveEntry]? {
        let accumulator = SevenZipEntryAccumulator()
        let contextPtr = Unmanaged.passUnretained(accumulator).toOpaque()
        
        let status = withExtendedLifetime(accumulator) {
            CUnsafeBufferAdapter.withCString(archivePath) { cPath in
                CUnsafeBufferAdapter.withCString(password) { cPwd in
                    guard let cPath = cPath else { return TTZIP_STATUS_ERR_INVALID_PARAM }
                    return ttzip_rust_inspect_archive(cPath, cPwd, true, { entryPtr, ctx in
                        guard let entry = entryPtr?.pointee, let ctx = ctx else { return false }
                        let acc = Unmanaged<SevenZipEntryAccumulator>.fromOpaque(ctx).takeUnretainedValue()
                        let pathStr = entry.path != nil ? String(cString: entry.path!) : ""
                        let lastComp = (pathStr as NSString).lastPathComponent
                        if lastComp.hasPrefix("._") || lastComp == ".DS_Store" { return true }
                        let encStr = "UTF-8"
                        acc.entries.append(ArchiveEntry(
                            path: pathStr,
                            uncompressedSize: Int64(entry.uncompressed_size),
                            isDirectory: entry.is_directory,
                            detectedEncoding: encStr,
                            isEncrypted: entry.is_encrypted
                        ))
                        return true
                    }, contextPtr)
                }
            }
        }
        
        if status == TTZIP_STATUS_OK && !accumulator.entries.isEmpty {
            return accumulator.entries
        }
        return nil
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
