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

/// Unified facade for 7z native parallel compression and decompression operations.
/// Directly interfaces with `SevenZipCAdapter` and C/Rust FFI bindings without intermediate onion forwarders.
public final class NativeSevenZipEngine: SevenZipEngineProtocol, @unchecked Sendable {
    public static let shared = NativeSevenZipEngine()
    
    private init() {}
    
    /// Parses 7z archive header and returns entry descriptors.
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
    
    /// Extracts 7z archive directly via `SevenZipCAdapter`.
    @inline(__always)
    public func extractSevenZipParallel(
        archivePath: String,
        destinationDir: String,
        password: String? = nil,
        skipMacJunk: Bool = true,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws -> Bool {
        return try SevenZipCAdapter.shared.extractArchive(
            archivePath: archivePath,
            destinationDir: destinationDir,
            skipMacJunk: skipMacJunk,
            password: password
        )
    }
    
    /// Compresses input paths into 7z archive directly via `SevenZipCAdapter`.
    @inline(__always)
    public func createSevenZipParallel(
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
    
    // MARK: - SevenZipEngineProtocol
    
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
        return try createSevenZipParallel(
            outputPath: outputPath,
            inputPaths: inputPaths,
            level: level,
            password: password,
            useZstd: useZstd,
            solidBlockSizeMb: solidBlockSizeMb,
            progressHandler: progressHandler
        )
    }
    
    @inline(__always)
    public func extractArchive(
        archivePath: String,
        destinationDir: String,
        password: String? = nil
    ) throws -> Bool {
        return try extractSevenZipParallel(
            archivePath: archivePath,
            destinationDir: destinationDir,
            password: password,
            skipMacJunk: true,
            progressHandler: nil
        )
    }
}
