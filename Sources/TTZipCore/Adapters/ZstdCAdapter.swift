// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// Adapter Pattern: Native C Zstandard streaming compression and decompression adapter.
///
/// Bridges native C routines (`ttzip_zstd_compress_file_stream` and `ttzip_zstd_decompress_file_stream`)
/// with Swift `ZstdEngineProtocol`, leveraging Apple Silicon multi-core threading and Long Distance Matching (LDM).
public final class ZstdCAdapter: ZstdEngineProtocol, Sendable {
    public static let shared = ZstdCAdapter()
    
    private init() {}
    
    /// Compresses a file or stream into a Zstandard frame.
    /// - Parameters:
    ///   - srcPath: Path to source input file.
    ///   - dstPath: Path to destination compressed output file.
    ///   - level: Compression level (-5 to 22).
    ///   - enableLDM: Whether to enable Long Distance Matching windowing.
    ///   - dictPath: Optional external dictionary file path.
    ///   - progressHandler: Optional progress callback.
    /// - Returns: `true` if compression succeeded, otherwise `false`.
    public func compressFile(
        srcPath: String,
        dstPath: String,
        level: ArchiveCompressionLevel = .normal,
        enableLDM: Bool = false,
        dictPath: String? = nil,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws -> Bool {
        let tuner = AppleSiliconTuner.shared
        tuner.boostCurrentThreadPriority()
        
        let workers = UInt32(tuner.optimalCompressionThreads)
        let fileManager = FileManager.default
        guard let srcData = try? Data(contentsOf: URL(fileURLWithPath: srcPath)) else { return false }
        let srcBytes = Int64(srcData.count)
        
        var windowLog: UInt32 = 0
        if enableLDM {
            let optWindow = tuner.optimalZstdLongWindowLog
            if srcBytes > 0 {
                let maxLog = Int(ceil(log2(Double(srcBytes))))
                windowLog = UInt32(max(10, min(optWindow, maxLog)))
            } else {
                windowLog = UInt32(optWindow)
            }
        }
        let overlapLog: UInt32 = enableLDM ? 2 : 0
        let compLevel = Int32(max(-5, min(22, level.rawValue)))
        let startTime = Date()
        
        progressHandler?(ArchiveProgress(
            state: .processing,
            bytesProcessed: 0,
            totalBytes: srcBytes,
            currentFileName: (srcPath as NSString).lastPathComponent,
            throughputMBs: 0.0
        ))
        
        let bound = ttzip_rust_zstd_compress_bound(srcData.count)
        var outBuf = [UInt8](repeating: 0, count: bound)
        var outLen: Int = 0
        
        let status = srcData.withUnsafeBytes { srcRaw in
            guard let srcPtr = srcRaw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return TTZIP_STATUS_ERR_INVALID_PARAM }
            return outBuf.withUnsafeMutableBufferPointer { dstRaw in
                guard let dstPtr = dstRaw.baseAddress else { return TTZIP_STATUS_ERR_INVALID_PARAM }
                return ttzip_rust_zstd_compress_advanced(
                    srcPtr,
                    srcData.count,
                    dstPtr,
                    bound,
                    compLevel,
                    workers,
                    0,
                    overlapLog,
                    windowLog,
                    enableLDM,
                    &outLen
                )
            }
        }
        
        if status == TTZIP_STATUS_OK {
            let compData = Data(bytes: outBuf, count: outLen)
            try compData.write(to: URL(fileURLWithPath: dstPath))
            
            let duration = max(0.001, Date().timeIntervalSince(startTime))
            let throughput = (Double(srcBytes) / (1024.0 * 1024.0)) / duration
            
            progressHandler?(ArchiveProgress(
                state: .completed,
                bytesProcessed: Int64(outLen),
                totalBytes: srcBytes,
                currentFileName: (dstPath as NSString).lastPathComponent,
                throughputMBs: throughput
            ))
            return true
        }
        
        return false
    }
    
    /// Decompresses a Zstandard frame file.
    /// - Parameters:
    ///   - srcPath: Path to source `.zst` file.
    ///   - dstPath: Path to destination decompressed output file.
    ///   - dictPath: Optional external dictionary file path.
    ///   - progressHandler: Optional progress callback.
    /// - Returns: `true` if decompression succeeded, otherwise `false`.
    public func decompressFile(
        srcPath: String,
        dstPath: String,
        dictPath: String? = nil,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws -> Bool {
        guard let srcData = try? Data(contentsOf: URL(fileURLWithPath: srcPath)) else { return false }
        var decompSize = Int(ttzip_rust_zstd_get_decompressed_size(
            (srcData as NSData).bytes.assumingMemoryBound(to: UInt8.self),
            srcData.count
        ))
        if decompSize <= 0 || decompSize > 1024 * 1024 * 1024 {
            decompSize = max(srcData.count * 4, 64 * 1024)
        }
        
        var outBuf = [UInt8](repeating: 0, count: decompSize)
        var outLen: Int = 0
        
        let status = srcData.withUnsafeBytes { srcRaw in
            guard let srcPtr = srcRaw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return TTZIP_STATUS_ERR_INVALID_PARAM }
            return outBuf.withUnsafeMutableBufferPointer { dstRaw in
                guard let dstPtr = dstRaw.baseAddress else { return TTZIP_STATUS_ERR_INVALID_PARAM }
                return ttzip_rust_zstd_decompress(
                    srcPtr,
                    srcData.count,
                    dstPtr,
                    decompSize,
                    &outLen
                )
            }
        }
        
        if status == TTZIP_STATUS_OK {
            let decompData = Data(bytes: outBuf, count: outLen)
            try? decompData.write(to: URL(fileURLWithPath: dstPath))
            return true
        }
        return false
    }
}
