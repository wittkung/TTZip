import Foundation
import CTTZipBridge

/// 大文件自适应分块流式 DEFLATE 写入器 (Adaptive Chunked DEFLATE Streaming Pipeline)
/// 当文件体积 > 256MB 时自动切入 1MB 分块流式多线程管道，将进程常驻内存严格约束在 <= 64MB。
public final class ChunkedDeflateStreamWriter: @unchecked Sendable {
    public static let adaptiveThresholdBytes: Int64 = 256 * 1024 * 1024 // 256MB
    
    private var streamHandle: OpaquePointer?
    private let outFd: Int32
    private let level: Int32
    private var isClosed = false
    
    public init?(outFd: Int32, level: Int = 6) {
        self.outFd = outFd
        self.level = Int32(level > 0 ? (level > 12 ? 12 : level) : 6)
        guard let handle = ttzip_zip_chunked_stream_create(outFd, self.level) else {
            return nil
        }
        self.streamHandle = handle
    }
    
    deinit {
        close()
    }
    
    /// 流式写入数据块
    public func write(data: Data) -> Bool {
        guard let handle = streamHandle, !isClosed, !data.isEmpty else {
            return !isClosed
        }
        
        return data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return false }
            let written = ttzip_zip_chunked_stream_write(handle, baseAddress, rawBuffer.count)
            return written == Int64(rawBuffer.count)
        }
    }
    
    /// 流式写入裸指针缓冲
    public func write(buffer: UnsafeRawPointer, count: Int) -> Bool {
        guard let handle = streamHandle, !isClosed, count > 0 else {
            return !isClosed
        }
        let written = ttzip_zip_chunked_stream_write(handle, buffer, count)
        return written == Int64(count)
    }
    
    /// 结束流式压缩并返回压缩后总字节数与全局 CRC-32
    public func finish() -> (totalCompressed: UInt64, finalCrc32: UInt32)? {
        guard let handle = streamHandle, !isClosed else { return nil }
        var totalComp: UInt64 = 0
        var finalCrc: UInt32 = 0
        
        let res = ttzip_zip_chunked_stream_finish(handle, &totalComp, &finalCrc)
        guard res == 0 else { return nil }
        
        close()
        return (totalCompressed: totalComp, finalCrc32: finalCrc)
    }
    
    /// 销毁并回收流式压缩器资源
    public func close() {
        guard !isClosed else { return }
        isClosed = true
        if let handle = streamHandle {
            ttzip_zip_chunked_stream_destroy(handle)
            streamHandle = nil
        }
    }
}
