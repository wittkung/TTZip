// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import Compression
import CTTZipBridge

/// Native in-process Brotli (.br / .tar.br) streaming codec engine.
///
/// Backed by Apple `Compression.framework` (`COMPRESSION_BROTLI`) and native TAR pipeline.
public final class NativeBrotliEngine: @unchecked Sendable {
    public static let shared = NativeBrotliEngine()
    
    private init() {}
    
    /// Stream-compresses a single file into Brotli (.br) format.
    public func compressFile(
        srcPath: String,
        dstPath: String,
        level: ArchiveCompressionLevel = .normal,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws -> Bool {
        guard let inHandle = FileHandle(forReadingAtPath: srcPath) else { return false }
        defer { try? inHandle.close() }
        
        FileManager.default.createFile(atPath: dstPath, contents: nil)
        guard let outHandle = FileHandle(forWritingAtPath: dstPath) else { return false }
        defer { try? outHandle.close() }
        
        let bufferSize = 8 * 1024 * 1024 // 8MB chunk
        let inBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        let outBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer {
            inBuffer.deallocate()
            outBuffer.deallocate()
        }
        
        var stream = compression_stream(dst_ptr: outBuffer, dst_size: bufferSize, src_ptr: inBuffer, src_size: 0, state: nil)
        let status = compression_stream_init(&stream, COMPRESSION_STREAM_ENCODE, COMPRESSION_BROTLI)
        guard status == COMPRESSION_STATUS_OK else { return false }
        defer { compression_stream_destroy(&stream) }
        
        while true {
            let data = inHandle.readData(ofLength: bufferSize)
            if data.isEmpty {
                // Finalize stream
                stream.src_size = 0
                while true {
                    stream.dst_ptr = outBuffer
                    stream.dst_size = bufferSize
                    let res = compression_stream_process(&stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))
                    let written = bufferSize - stream.dst_size
                    if written > 0 {
                        outHandle.write(Data(bytesNoCopy: outBuffer, count: written, deallocator: .none))
                    }
                    if res == COMPRESSION_STATUS_END { break }
                    if res == COMPRESSION_STATUS_ERROR { return false }
                    if written == 0 { break }
                }
                break
            }
            
            data.withUnsafeBytes { rawBytes in
                guard let base = rawBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
                stream.src_ptr = base
                stream.src_size = data.count
                
                var processStatus = COMPRESSION_STATUS_OK
                repeat {
                    stream.dst_ptr = outBuffer
                    stream.dst_size = bufferSize
                    processStatus = compression_stream_process(&stream, 0)
                    let written = bufferSize - stream.dst_size
                    if written > 0 {
                        outHandle.write(Data(bytesNoCopy: outBuffer, count: written, deallocator: .none))
                    }
                    if processStatus == COMPRESSION_STATUS_ERROR { break }
                } while stream.src_size > 0 || (processStatus == COMPRESSION_STATUS_OK && stream.dst_size == 0)
            }
        }
        return true
    }
    
    /// Stream-decompresses a Brotli (.br) file.
    public func decompressFile(
        srcPath: String,
        dstPath: String,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws -> Bool {
        guard let inHandle = FileHandle(forReadingAtPath: srcPath) else { return false }
        defer { try? inHandle.close() }
        
        FileManager.default.createFile(atPath: dstPath, contents: nil)
        guard let outHandle = FileHandle(forWritingAtPath: dstPath) else { return false }
        defer { try? outHandle.close() }
        
        let bufferSize = 8 * 1024 * 1024 // 8MB chunk
        let inBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        let outBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer {
            inBuffer.deallocate()
            outBuffer.deallocate()
        }
        
        var stream = compression_stream(dst_ptr: outBuffer, dst_size: bufferSize, src_ptr: inBuffer, src_size: 0, state: nil)
        let status = compression_stream_init(&stream, COMPRESSION_STREAM_DECODE, COMPRESSION_BROTLI)
        guard status == COMPRESSION_STATUS_OK else { return false }
        defer { compression_stream_destroy(&stream) }
        
        var isFinished = false
        while !isFinished {
            let data = inHandle.readData(ofLength: bufferSize)
            if data.isEmpty { break }
            
            data.withUnsafeBytes { rawBytes in
                guard let base = rawBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
                stream.src_ptr = base
                stream.src_size = data.count
                
                var processStatus = COMPRESSION_STATUS_OK
                repeat {
                    stream.dst_ptr = outBuffer
                    stream.dst_size = bufferSize
                    processStatus = compression_stream_process(&stream, 0)
                    let written = bufferSize - stream.dst_size
                    if written > 0 {
                        outHandle.write(Data(bytesNoCopy: outBuffer, count: written, deallocator: .none))
                    }
                    if processStatus == COMPRESSION_STATUS_END {
                        isFinished = true
                        break
                    }
                    if processStatus == COMPRESSION_STATUS_ERROR { break }
                } while stream.src_size > 0 || (processStatus == COMPRESSION_STATUS_OK && stream.dst_size == 0)
            }
        }
        
        if !isFinished {
            while true {
                stream.dst_ptr = outBuffer
                stream.dst_size = bufferSize
                stream.src_size = 0
                let res = compression_stream_process(&stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))
                let written = bufferSize - stream.dst_size
                if written > 0 {
                    outHandle.write(Data(bytesNoCopy: outBuffer, count: written, deallocator: .none))
                }
                if res == COMPRESSION_STATUS_END || res == COMPRESSION_STATUS_ERROR || written == 0 { break }
            }
        }
        return true
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
        
        // 2. Stream compress TAR container with Brotli
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
