// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// Adapter Pattern: Native Rust Zstandard streaming compression and decompression adapter.
///
/// Bridges native Rust routines (`ttzip_rust_zstd_compress_file_stream` and `ttzip_rust_zstd_decompress_file_stream`)
/// with Swift `ZstdEngineProtocol`, leveraging Apple Silicon multi-core threading, bounded 4MB/4MB double buffer
/// state machine pipelines, and Long Distance Matching (LDM) with strict <16MB RSS memory guarantees.
public final class ZstdCAdapter: ZstdEngineProtocol, Sendable {
    public static let shared = ZstdCAdapter()
    
    private init() {}
    
    /// Compresses a file into a Zstandard frame using bounded 4MB/4MB streaming pipeline.
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
        let srcAttrs = try? fileManager.attributesOfItem(atPath: srcPath)
        let srcBytes = (srcAttrs?[.size] as? NSNumber)?.int64Value ?? 0
        
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
        
        final class ProgressBox: @unchecked Sendable {
            let handler: (@Sendable (ArchiveProgress) -> Void)?
            let totalBytes: Int64
            let fileName: String
            let startTime: Date
            
            init(handler: (@Sendable (ArchiveProgress) -> Void)?, totalBytes: Int64, fileName: String, startTime: Date) {
                self.handler = handler
                self.totalBytes = totalBytes
                self.fileName = fileName
                self.startTime = startTime
            }
        }
        
        let box = ProgressBox(
            handler: progressHandler,
            totalBytes: srcBytes,
            fileName: (srcPath as NSString).lastPathComponent,
            startTime: startTime
        )
        let boxPtr = Unmanaged.passRetained(box).toOpaque()
        defer { Unmanaged<ProgressBox>.fromOpaque(boxPtr).release() }
        
        let callback: TTZipProgressCallback = { processed, total, cName, userData in
            guard let ptr = userData else { return true }
            let innerBox = Unmanaged<ProgressBox>.fromOpaque(ptr).takeUnretainedValue()
            if let handler = innerBox.handler {
                let duration = max(0.001, Date().timeIntervalSince(innerBox.startTime))
                let throughput = (Double(processed) / (1024.0 * 1024.0)) / duration
                let name = cName.map { String(cString: $0) } ?? innerBox.fileName
                handler(ArchiveProgress(
                    state: .processing,
                    bytesProcessed: Int64(processed),
                    totalBytes: innerBox.totalBytes > 0 ? innerBox.totalBytes : Int64(total),
                    currentFileName: name,
                    throughputMBs: throughput
                ))
            }
            return true
        }
        
        let status = srcPath.withCString { cSrc in
            dstPath.withCString { cDst in
                ttzip_rust_zstd_compress_file_stream(
                    cSrc,
                    cDst,
                    compLevel,
                    workers,
                    0,
                    overlapLog,
                    windowLog,
                    enableLDM,
                    progressHandler != nil ? callback : nil,
                    boxPtr
                )
            }
        }
        
        if status == TTZIP_STATUS_OK {
            let duration = max(0.001, Date().timeIntervalSince(startTime))
            let throughput = (Double(srcBytes) / (1024.0 * 1024.0)) / duration
            let dstAttrs = try? fileManager.attributesOfItem(atPath: dstPath)
            let dstBytes = (dstAttrs?[.size] as? NSNumber)?.int64Value ?? 0
            
            progressHandler?(ArchiveProgress(
                state: .completed,
                bytesProcessed: dstBytes,
                totalBytes: srcBytes,
                currentFileName: (dstPath as NSString).lastPathComponent,
                throughputMBs: throughput
            ))
            return true
        }
        
        return false
    }
    
    /// Decompresses a Zstandard frame file using bounded 4MB/4MB streaming pipeline.
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
        let fileManager = FileManager.default
        let srcAttrs = try? fileManager.attributesOfItem(atPath: srcPath)
        let srcBytes = (srcAttrs?[.size] as? NSNumber)?.int64Value ?? 0
        let startTime = Date()
        
        final class ProgressBox: @unchecked Sendable {
            let handler: (@Sendable (ArchiveProgress) -> Void)?
            let totalBytes: Int64
            let fileName: String
            let startTime: Date
            
            init(handler: (@Sendable (ArchiveProgress) -> Void)?, totalBytes: Int64, fileName: String, startTime: Date) {
                self.handler = handler
                self.totalBytes = totalBytes
                self.fileName = fileName
                self.startTime = startTime
            }
        }
        
        let box = ProgressBox(
            handler: progressHandler,
            totalBytes: srcBytes,
            fileName: (srcPath as NSString).lastPathComponent,
            startTime: startTime
        )
        let boxPtr = Unmanaged.passRetained(box).toOpaque()
        defer { Unmanaged<ProgressBox>.fromOpaque(boxPtr).release() }
        
        let callback: TTZipProgressCallback = { processed, total, cName, userData in
            guard let ptr = userData else { return true }
            let innerBox = Unmanaged<ProgressBox>.fromOpaque(ptr).takeUnretainedValue()
            if let handler = innerBox.handler {
                let duration = max(0.001, Date().timeIntervalSince(innerBox.startTime))
                let throughput = (Double(processed) / (1024.0 * 1024.0)) / duration
                let name = cName.map { String(cString: $0) } ?? innerBox.fileName
                handler(ArchiveProgress(
                    state: .processing,
                    bytesProcessed: Int64(processed),
                    totalBytes: innerBox.totalBytes > 0 ? innerBox.totalBytes : Int64(total),
                    currentFileName: name,
                    throughputMBs: throughput
                ))
            }
            return true
        }
        
        let status = srcPath.withCString { cSrc in
            dstPath.withCString { cDst in
                ttzip_rust_zstd_decompress_file_stream(
                    cSrc,
                    cDst,
                    progressHandler != nil ? callback : nil,
                    boxPtr
                )
            }
        }
        
        if status == TTZIP_STATUS_OK {
            let duration = max(0.001, Date().timeIntervalSince(startTime))
            let dstAttrs = try? fileManager.attributesOfItem(atPath: dstPath)
            let dstBytes = (dstAttrs?[.size] as? NSNumber)?.int64Value ?? 0
            let throughput = (Double(dstBytes) / (1024.0 * 1024.0)) / duration
            
            progressHandler?(ArchiveProgress(
                state: .completed,
                bytesProcessed: dstBytes,
                totalBytes: dstBytes,
                currentFileName: (dstPath as NSString).lastPathComponent,
                throughputMBs: throughput
            ))
            return true
        }
        
        return false
    }
}
