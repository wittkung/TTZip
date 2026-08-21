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
        let lvlMap: TTZipCompressionLevel
        switch raw {
        case 0: lvlMap = TTZIP_COMPRESSION_LEVEL_STORE
        case 1, 2: lvlMap = TTZIP_COMPRESSION_LEVEL_FASTEST
        case 3, 4, 5: lvlMap = TTZIP_COMPRESSION_LEVEL_FAST
        case 6, 7, 8: lvlMap = TTZIP_COMPRESSION_LEVEL_NORMAL
        case 9: lvlMap = TTZIP_COMPRESSION_LEVEL_MAXIMUM
        default: lvlMap = TTZIP_COMPRESSION_LEVEL_ULTRA
        }
        let pwd = (password != nil && !password!.isEmpty) ? password : nil
        let encMap: TTZipEncryptionMethod = (pwd != nil) ? TTZIP_ENCRYPTION_AES256 : TTZIP_ENCRYPTION_NONE
        
        return CUnsafeBufferAdapter.withCString(outputPath) { cOutputPath in
            CUnsafeBufferAdapter.withCStringsArray(inputPaths) { cInputPaths in
                CUnsafeBufferAdapter.withCString(pwd) { cPassword in
                    guard let cOutputPath = cOutputPath else { return false }
                    var opt = TTZipCreateOptions(
                        format: TTZIP_ARCHIVE_FORMAT_SEVEN_ZIP,
                        level: lvlMap,
                        encryption: encMap,
                        password: cPassword,
                        thread_budget: 0,
                        solid_block_size_mb: UInt32(solidBlockSizeMb),
                        progress_callback: nil,
                        user_data: nil
                    )
                    let status = ttzip_rust_create_archive(cInputPaths, inputPaths.count, cOutputPath, &opt)
                    if status == TTZIP_STATUS_OK {
                        progressHandler?(ArchiveProgress(state: .completed, bytesProcessed: 100, totalBytes: 100, currentFileName: ""))
                        return true
                    }
                    
                    // Fallback to 7z native binary if Rust libarchive cannot write encrypted 7z container
                    if let bin7z = SevenZipBinaryResolver.resolveBinaryPath() {
                        try? FileManager.default.removeItem(atPath: outputPath)
                        let proc = Process()
                        proc.executableURL = URL(fileURLWithPath: bin7z)
                        var args = ["a", "-t7z", "-mx=\(raw)"]
                        if let p = pwd, !p.isEmpty {
                            args.append("-p\(p)")
                            args.append("-mhe=on")
                        }
                        args.append(outputPath)
                        args.append(contentsOf: inputPaths)
                        proc.arguments = args
                        let pipe = Pipe()
                        proc.standardOutput = pipe
                        proc.standardError = FileHandle.nullDevice
                        if (try? proc.run()) != nil {
                            _ = pipe.fileHandleForReading.readDataToEndOfFile()
                            proc.waitUntilExit()
                            if proc.terminationStatus == 0 {
                                progressHandler?(ArchiveProgress(state: .completed, bytesProcessed: 100, totalBytes: 100, currentFileName: ""))
                                return true
                            }
                        }
                    }
                    TTLogger.error("[SevenZipCAdapter] 7z compression failed with status=\(status.rawValue), output=\(outputPath)")
                    return false
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
                    var opt = TTZipExtractOptions(
                        destination_path: cDestDir,
                        password: cPassword,
                        thread_budget: 0,
                        overwrite_existing: true,
                        preserve_permissions: true,
                        dry_run: false,
                        progress_callback: nil,
                        user_data: nil
                    )
                    let status = ttzip_rust_extract_archive(cArchivePath, cDestDir, &opt)
                    let items = ((try? FileManager.default.contentsOfDirectory(atPath: destinationDir)) ?? []).filter { $0 != ".noindex" && $0 != ".DS_Store" && !$0.hasPrefix("._") }
                    if status == TTZIP_STATUS_OK && !items.isEmpty {
                        return true
                    }
                    if let bin7z = SevenZipBinaryResolver.resolveBinaryPath() {
                        let proc = Process()
                        proc.executableURL = URL(fileURLWithPath: bin7z)
                        var args = ["x", "-y", "-o\(destinationDir)"]
                        if let p = pwd, !p.isEmpty {
                            args.append("-p\(p)")
                        } else {
                            args.append("-p-")
                        }
                        args.append(archivePath)
                        proc.arguments = args
                        let pipe = Pipe()
                        proc.standardOutput = pipe
                        proc.standardError = FileHandle.nullDevice
                        if (try? proc.run()) != nil {
                            _ = pipe.fileHandleForReading.readDataToEndOfFile()
                            proc.waitUntilExit()
                            if proc.terminationStatus == 0 {
                                return true
                            }
                        }
                    }
                    TTLogger.debug("[SevenZipCAdapter] 7z extraction returned status=\(status.rawValue), archive=\(archivePath), dest=\(destinationDir)")
                    return false
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
        let status = ttzip_rust_fl2_compress(
            src,
            srcLength,
            dst,
            dstCapacity,
            Int32(level),
            UInt32(threadCount),
            &outLen
        )
        return (status.rawValue, outLen, 1 << 24)
    }
}
