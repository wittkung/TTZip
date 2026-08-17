import Foundation
import Compression
import CTTZipBridge

/// macOS 原生 In-Process Brotli (.br / .tar.br) 极速流式编解码引擎
/// 基于 Apple `Compression.framework` (`COMPRESSION_BROTLI`) 与原生 TAR 管道
public final class NativeBrotliEngine: @unchecked Sendable {
    public static let shared = NativeBrotliEngine()
    
    private init() {}
    
    /// 流式压缩单文件至 Brotli 格式
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
    
    /// 流式解压 Brotli 文件
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
    
    /// 归档打包为 Brotli (.br / .tar.br) 格式
    public func createArchive(
        outputPath: String,
        inputPaths: [String],
        level: ArchiveCompressionLevel,
        skipMacJunk: Bool = false,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws -> Bool {
        let tempTar = FileManager.default.temporaryDirectory.appendingPathComponent("tt_br_tar_\(UUID().uuidString).tar").path
        defer { try? FileManager.default.removeItem(atPath: tempTar) }
        
        // 1. 生成纯 TAR 流
        let status = CUnsafeBufferAdapter.withCStringsArray(inputPaths) { cInputPaths in
            ttzip_create_tar_native_c(tempTar, "tar", cInputPaths, inputPaths.count, skipMacJunk, 1)
        }
        guard status == 0 else { return false }
        
        // 2. Brotli 流式压缩 TAR 为 .br
        return try compressFile(srcPath: tempTar, dstPath: outputPath, level: level, progressHandler: progressHandler)
    }
    
    /// 解压 Brotli (.br / .tar.br) 归档
    public func extractArchive(
        archivePath: String,
        destinationDir: String,
        skipMacJunk: Bool = false,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)? = nil
    ) throws -> Bool {
        let tempTar = FileManager.default.temporaryDirectory.appendingPathComponent("tt_br_ext_\(UUID().uuidString).tar").path
        defer { try? FileManager.default.removeItem(atPath: tempTar) }
        
        // 1. Brotli 解压至纯 TAR
        let decOk = try decompressFile(srcPath: archivePath, dstPath: tempTar, progressHandler: progressHandler)
        guard decOk else { return false }
        
        // 2. 提取 TAR 到目标目录
        let extractStatus = ttzip_extract_tar_native_c(tempTar, destinationDir, skipMacJunk)
        return extractStatus == 0
    }
}
