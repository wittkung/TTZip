// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// Native in-process Brotli (.br / .tar.br) streaming codec engine.
///
/// Backed directly by Pure Rust Google Brotli streaming engine (`ttzip_rust_brotli_...`)
/// and unified POSIX TAR archive pipeline. Completely eliminates Apple `Compression.framework` dependencies.
public final class NativeBrotliEngine: @unchecked Sendable {
    public static let shared = NativeBrotliEngine()
    
    private init() {}

    /// Computes worst-case output buffer size for Brotli block compression.
    public func compressBound(for sourceLength: Int) -> Int {
        guard sourceLength >= 0 else { return 1024 }
        return ttzip_rust_brotli_compress_bound(sourceLength)
    }

    /// Compresses in-memory data using pure Rust Brotli codec.
    public func compress(data: Data, quality: UInt32 = 6, lgwin: UInt32 = 22) throws -> Data {
        if data.isEmpty {
            return Data()
        }
        let bound = compressBound(for: data.count)
        var compressed = Data(count: bound)
        var actualLen = bound

        let status: CTTZipBridge.TTZipStatus = data.withUnsafeBytes { inBuf in
            guard let inBase = inBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return TTZIP_STATUS_ERR_INVALID_PARAM
            }
            return compressed.withUnsafeMutableBytes { outBuf in
                guard let outBase = outBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return TTZIP_STATUS_ERR_INVALID_PARAM
                }
                return ttzip_rust_brotli_compress(inBase, inBuf.count, outBase, bound, quality, lgwin, &actualLen)
            }
        }

        guard status == TTZIP_STATUS_OK else {
            throw ArchiveError.corruptedData(archivePath: "memory", entryPath: "brotli_compress")
        }

        compressed.count = actualLen
        return compressed
    }

    /// Decompresses in-memory Brotli compressed data into raw Data.
    public func decompress(compressedData: Data, maxAllowedSize: Int = 1_073_741_824) throws -> Data {
        guard !compressedData.isEmpty else {
            return Data()
        }

        var decompressed = Data(count: min(maxAllowedSize, max(compressedData.count * 4, 65536)))
        var actualLen = decompressed.count
        var status: CTTZipBridge.TTZipStatus = TTZIP_STATUS_OK
        var success = false

        while decompressed.count <= maxAllowedSize {
            actualLen = decompressed.count
            status = compressedData.withUnsafeBytes { inBuf in
                guard let inBase = inBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return TTZIP_STATUS_ERR_INVALID_PARAM
                }
                return decompressed.withUnsafeMutableBytes { outBuf in
                    guard let outBase = outBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                        return TTZIP_STATUS_ERR_INVALID_PARAM
                    }
                    return ttzip_rust_brotli_decompress(inBase, inBuf.count, outBase, outBuf.count, &actualLen)
                }
            }

            if status == TTZIP_STATUS_OK {
                success = true
                break
            }

            if decompressed.count * 2 > maxAllowedSize {
                if decompressed.count == maxAllowedSize { break }
                decompressed.count = maxAllowedSize
            } else {
                decompressed.count *= 2
            }
        }

        guard success, status == TTZIP_STATUS_OK else {
            throw ArchiveError.corruptedData(archivePath: "memory", entryPath: "brotli_decompress")
        }

        decompressed.count = actualLen
        return decompressed
    }
    
    /// Stream-compresses a single file into Brotli (.br) format with 4MB bounded pipe.
    public func compressFile(
        srcPath: String,
        dstPath: String,
        level: ArchiveCompressionLevel = .normal,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws -> Bool {
        let quality: UInt32
        switch level {
        case .fastest: quality = 1
        case .fast:    quality = 3
        case .normal:  quality = 6
        case .maximum: quality = 9
        case .ultra:   quality = 11
        @unknown default: quality = 6
        }

        let status = ttzip_rust_brotli_compress_file_stream(srcPath, dstPath, quality, 22, nil, nil)
        return status == TTZIP_STATUS_OK
    }
    
    /// Stream-decompresses a Brotli (.br) file with 4MB bounded pipe.
    public func decompressFile(
        srcPath: String,
        dstPath: String,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws -> Bool {
        let status = ttzip_rust_brotli_decompress_file_stream(srcPath, dstPath, nil, nil)
        return status == TTZIP_STATUS_OK
    }
    
    /// Packs and compresses input paths into Brotli (.br / .tar.br) archive container.
    public func createArchive(
        outputPath: String,
        inputPaths: [String],
        level: ArchiveCompressionLevel,
        skipMacJunk: Bool = false,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws -> Bool {
        let tempTar = FileManager.default.temporaryDirectory.appendingPathComponent("tt_br_tar_\(UUID().uuidString).tar").path
        defer { try? FileManager.default.removeItem(atPath: tempTar) }
        
        // 1. Generate uncompressed TAR stream
        let status = CUnsafeBufferAdapter.withCStringsArray(inputPaths) { cInputPaths in
            ttzip_create_tar_native_c(tempTar, "tar", cInputPaths, inputPaths.count, skipMacJunk, 1)
        }
        guard status == 0 else { return false }
        
        // 2. Stream compress TAR container with Pure Rust Brotli
        return try compressFile(srcPath: tempTar, dstPath: outputPath, level: level, progressHandler: progressHandler)
    }
    
    /// Extracts a Brotli (.br / .tar.br) archive container.
    public func extractArchive(
        archivePath: String,
        destinationDir: String,
        skipMacJunk: Bool = false,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws -> Bool {
        let tempTar = FileManager.default.temporaryDirectory.appendingPathComponent("tt_br_ext_\(UUID().uuidString).tar").path
        defer { try? FileManager.default.removeItem(atPath: tempTar) }
        
        // 1. Decompress Brotli container to uncompressed TAR stream
        let decOk = try decompressFile(srcPath: archivePath, dstPath: tempTar, progressHandler: progressHandler)
        guard decOk else { return false }
        
        // 2. Extract TAR entries into target directory
        let extractStatus = ttzip_extract_tar_native_c(tempTar, destinationDir, skipMacJunk)
        return extractStatus == 0
    }
}
