// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// Adapter Pattern: Native C 7z archiving and Fast-LZMA2 engine adapter.
///
/// Wraps native C routines (`ttzip_7z_extract_native_parallel_c`, `ttzip_create_7z_native_c`,
/// and `ttzip_fl2_compress_block`) into Swift concurrency-compliant `SevenZipEngineProtocol`.
public final class SevenZipCAdapter: SevenZipEngineProtocol, Sendable {
    public static let shared = SevenZipCAdapter()
    
    private init() {}
    
    /// Creates a 7z archive using native C static library bindings.
    /// - Parameters:
    ///   - outputPath: Target output `.7z` file path.
    ///   - inputPaths: Array of source file and directory paths.
    ///   - level: Compression level.
    ///   - password: Optional encryption passphrase.
    ///   - useZstd: Whether to utilize Zstandard codec within 7z container.
    ///   - solidBlockSizeMb: Size of solid stream block in MB.
    ///   - progressHandler: Optional progress callback.
    /// - Returns: `true` if archive creation succeeded, otherwise `false`.
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
        let raw = level.rawValue
        let lvl: Int32 = raw <= 0 ? 0 : (raw >= 9 ? 9 : Int32(raw))
        let pwd = (password != nil && !password!.isEmpty) ? password : nil
        
        return CUnsafeBufferAdapter.withCString(outputPath) { cOutputPath in
            CUnsafeBufferAdapter.withCStringsArray(inputPaths) { cInputPaths in
                CUnsafeBufferAdapter.withCString(pwd) { cPassword in
                    guard let cOutputPath = cOutputPath else { return false }
                    let status = ttzip_create_7z_native_c(
                        cOutputPath,
                        cInputPaths,
                        inputPaths.count,
                        lvl,
                        cPassword
                    )
                    if status == 0 {
                        progressHandler?(ArchiveProgress(state: .completed, bytesProcessed: 100, totalBytes: 100, currentFileName: ""))
                    } else {
                        TTLogger.error("[SevenZipCAdapter] C layer compression failed with status=\(status), output=\(outputPath)")
                    }
                    return status == 0
                }
            }
        }
    }
    
    /// Extracts a 7z archive using native C static library bindings.
    /// - Parameters:
    ///   - archivePath: Path to input `.7z` archive file.
    ///   - destinationDir: Target extraction directory path.
    ///   - skipMacJunk: Whether to filter AppleDouble and Resource Fork artifacts.
    ///   - password: Optional decryption passphrase.
    /// - Returns: `true` if extraction succeeded, otherwise `false`.
    @inline(__always)
    public func extractArchive(
        archivePath: String,
        destinationDir: String,
        skipMacJunk: Bool = true,
        password: String? = nil
    ) throws -> Bool {
        let pwd = (password != nil && !password!.isEmpty) ? password : nil
        return CUnsafeBufferAdapter.withCString(archivePath) { cArchivePath in
            CUnsafeBufferAdapter.withCString(destinationDir) { cDestDir in
                CUnsafeBufferAdapter.withCString(pwd) { cPassword in
                    guard let cArchivePath = cArchivePath, let cDestDir = cDestDir else { return false }
                    let status = ttzip_extract_7z_native_c(
                        cArchivePath,
                        cDestDir,
                        cPassword
                    )
                    if status != 0 {
                        TTLogger.debug("[SevenZipCAdapter] C layer extraction returned status=\(status), archive=\(archivePath), dest=\(destinationDir)")
                    }
                    return status == 0
                }
            }
        }
    }

    /// Compresses a buffer block directly using Fast-LZMA2 hybrid routines.
    /// - Parameters:
    ///   - src: Pointer to source uncompressed byte buffer.
    ///   - srcLength: Uncompressed byte count.
    ///   - dst: Pointer to destination output buffer.
    ///   - dstCapacity: Allocated capacity of destination buffer.
    ///   - level: LZMA2 compression level.
    ///   - isZeroBlock: Optimization flag for zero-filled buffers.
    ///   - threadCount: Number of worker threads for parallel LZMA2 chunking.
    /// - Returns: Tuple of status code, output compressed size, and dictionary size.
    @inline(__always)
    public func compressBlockFL2(
        src: UnsafePointer<UInt8>,
        srcLength: Int,
        dst: UnsafeMutablePointer<UInt8>,
        dstCapacity: Int,
        level: Int = 5,
        isZeroBlock: Bool = false,
        threadCount: Int = 0
    ) -> (status: Int32, compressedSize: Int, dictSize: UInt32) {
        var outLen: Int = 0
        var outDict: UInt32 = 0
        let status = ttzip_fl2_compress_block(
            src,
            srcLength,
            dst,
            dstCapacity,
            &outLen,
            Int32(level),
            isZeroBlock,
            &outDict,
            Int32(threadCount)
        )
        return (status, outLen, outDict)
    }
}
