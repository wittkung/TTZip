import Foundation
import CTTZipBridge

// MARK: - Deflate Stream Enums & Configuration

/// Deflate 引擎执行分层模式
public enum DeflateTierMode: Int32, Sendable, Codable, Equatable {
    /// Tier 1: 内存完整缓冲快速路径 (libdeflate)
    case tier1Block = 1
    /// Tier 2: 状态机增量流式管道 (zlib-ng SIMD)
    case tier2Stream = 2
}

/// Deflate 窗口与标头格式
public enum DeflateWindowBits: Int32, Sendable, Codable, Equatable {
    /// 原始 DEFLATE 流 (无标头与尾部校验，RFC 1951，常用于 ZIP)
    case raw = -15
    /// 标准 Zlib 标头与 Adler-32 (RFC 1950)
    case zlib = 15
    /// GZIP 标头与 CRC-32 (RFC 1952)
    case gzip = 31
}

/// Deflate 压缩策略
public enum DeflateStrategy: Int32, Sendable, Codable, Equatable {
    case defaultStrategy = 0
    case filtered = 1
    case huffmanOnly = 2
    case rle = 3
    case fixed = 4
}

/// Deflate 刷新模式
public enum DeflateFlushMode: Int32, Sendable, Codable, Equatable {
    case noFlush = 0
    case syncFlush = 2
    case fullFlush = 3
    case finish = 4
    
    public var stringValue: String {
        switch self {
        case .noFlush: return "NO_FLUSH"
        case .syncFlush: return "SYNC_FLUSH"
        case .fullFlush: return "FULL_FLUSH"
        case .finish: return "FINISH"
        }
    }
}

/// Deflate 错误类型
public enum DeflateStreamError: LocalizedError, Sendable, Equatable {
    case initializationFailed(Int32)
    case processingFailed(String)
    case streamAlreadyClosed
    case invalidParameters(String)
    case corruptedData(String)
    
    public var errorDescription: String? {
        switch self {
        case .initializationFailed(let code):
            return "Deflate stream initialization failed with code: \(code)"
        case .processingFailed(let msg):
            return "Deflate stream processing failed: \(msg)"
        case .streamAlreadyClosed:
            return "Deflate stream has already been closed"
        case .invalidParameters(let msg):
            return "Invalid stream parameters: \(msg)"
        case .corruptedData(let msg):
            return "Corrupted Deflate stream data: \(msg)"
        }
    }
}

/// Deflate 流式配置实体
public struct DeflateStreamConfig: Sendable, Codable, Equatable {
    public var tierMode: DeflateTierMode
    public var compressionLevel: Int
    public var windowBits: Int
    public var memLevel: Int
    public var strategy: DeflateStrategy
    
    public init(
        tierMode: DeflateTierMode = .tier2Stream,
        compressionLevel: Int = 6,
        windowBits: Int = 15,
        memLevel: Int = 8,
        strategy: DeflateStrategy = .defaultStrategy
    ) {
        self.tierMode = tierMode
        self.compressionLevel = max(1, min(9, compressionLevel))
        self.windowBits = windowBits
        self.memLevel = max(1, min(9, memLevel))
        self.strategy = strategy
    }
    
    public static var fastStreaming: DeflateStreamConfig {
        DeflateStreamConfig(compressionLevel: 1, windowBits: 15)
    }
    
    public static var gzipFastStreaming: DeflateStreamConfig {
        DeflateStreamConfig(compressionLevel: 1, windowBits: 31)
    }
    
    public static var rawFastStreaming: DeflateStreamConfig {
        DeflateStreamConfig(compressionLevel: 1, windowBits: -15)
    }
    
    public static var standardGzip: DeflateStreamConfig {
        DeflateStreamConfig(compressionLevel: 6, windowBits: 31)
    }
    
    public static var standardRaw: DeflateStreamConfig {
        DeflateStreamConfig(compressionLevel: 6, windowBits: -15)
    }
}

/// Deflate 流式运行状态度量
public struct DeflateStreamMetrics: Sendable, Equatable {
    public let totalIn: UInt64
    public let totalOut: UInt64
    public let adler32: UInt32
    public let crc32: UInt32
    public let isFinished: Bool
}

// MARK: - DeflateStreamCompressor

/// 高性能原生 Deflate 流式压缩器
public final class DeflateStreamCompressor: @unchecked Sendable {
    private var state = ttzip_deflate_stream_state_t()
    private var isClosed = false
    public let sessionId: UUID
    public let config: DeflateStreamConfig
    
    public init(config: DeflateStreamConfig = DeflateStreamConfig()) throws {
        self.sessionId = UUID()
        self.config = config
        
        var cConfig = ttzip_deflate_stream_config_t(
            tier_mode: UInt32(config.tierMode.rawValue),
            compression_level: Int32(config.compressionLevel),
            window_bits: Int32(config.windowBits),
            mem_level: Int32(config.memLevel),
            strategy: config.strategy.rawValue
        )
        
        let status = ttzip_deflate_stream_init(&self.state, &cConfig)
        guard status == 0 else {
            throw DeflateStreamError.initializationFailed(status)
        }
    }
    
    deinit {
        close()
    }
    
    public var totalIn: UInt64 {
        return state.total_in
    }
    
    public var totalOut: UInt64 {
        return state.total_out
    }
    
    public var adler32: UInt32 {
        return state.adler32_checksum
    }
    
    public var crc32: UInt32 {
        return state.crc32_checksum
    }
    
    public var isFinished: Bool {
        return state.is_finished
    }
    
    public var metrics: DeflateStreamMetrics {
        return DeflateStreamMetrics(
            totalIn: state.total_in,
            totalOut: state.total_out,
            adler32: state.adler32_checksum,
            crc32: state.crc32_checksum,
            isFinished: state.is_finished
        )
    }
    
    /// 流式压缩指针缓冲区
    public func compress(
        buffer: UnsafeRawPointer,
        count: Int,
        flush: DeflateFlushMode = .noFlush,
        outputChunkSize: Int = 64 * 1024,
        chunkHandler: (UnsafeRawBufferPointer) -> Void
    ) throws {
        guard !isClosed else { throw DeflateStreamError.streamAlreadyClosed }
        guard count > 0 || flush == .finish else { return }
        
        let effectiveChunkSize = max(1024, outputChunkSize)
        let outBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: effectiveChunkSize)
        defer { outBuffer.deallocate() }
        
        var offset = 0
        while offset < count || (count == 0 && flush == .finish && !state.is_finished) {
            let currentInPtr = count > 0 ? buffer.advanced(by: offset).assumingMemoryBound(to: UInt8.self) : nil
            let remainingIn = count - offset
            let beforeIn = state.total_in
            let beforeOut = state.total_out
            
            let produced = ttzip_deflate_stream_process(
                &state,
                currentInPtr,
                remainingIn,
                outBuffer,
                effectiveChunkSize,
                flush.rawValue
            )
            let consumed = Int(state.total_in - beforeIn)
            
            if produced > 0 {
                chunkHandler(UnsafeRawBufferPointer(start: outBuffer, count: produced))
            }
            
            if consumed > 0 {
                offset += consumed
            }
            
            if flush == .finish && state.is_finished {
                break
            }
            
            if consumed == 0 && state.total_out == beforeOut {
                break
            }
        }
    }
    
    /// 流式压缩 Data 块并返回压缩数据
    public func compress(
        chunk: Data,
        flush: DeflateFlushMode = .noFlush,
        outputChunkSize: Int = 64 * 1024
    ) throws -> Data {
        var output = Data()
        if chunk.isEmpty && flush != .finish {
            return output
        }
        
        try chunk.withUnsafeBytes { rawBuffer in
            if let baseAddress = rawBuffer.baseAddress {
                try compress(
                    buffer: baseAddress,
                    count: rawBuffer.count,
                    flush: flush,
                    outputChunkSize: outputChunkSize
                ) { outChunk in
                    output.append(outChunk.bindMemory(to: UInt8.self))
                }
            } else {
                let dummy = [UInt8]()
                try dummy.withUnsafeBytes { dummyBuffer in
                    try compress(
                        buffer: dummyBuffer.baseAddress ?? UnsafeRawPointer(bitPattern: 1)!,
                        count: 0,
                        flush: flush,
                        outputChunkSize: outputChunkSize
                    ) { outChunk in
                        output.append(outChunk.bindMemory(to: UInt8.self))
                    }
                }
            }
        }
        return output
    }
    
    /// 结束压缩并刷出所有剩余尾部数据
    public func finish(
        outputChunkSize: Int = 64 * 1024,
        chunkHandler: (UnsafeRawBufferPointer) -> Void
    ) throws {
        guard !isClosed else { throw DeflateStreamError.streamAlreadyClosed }
        if state.is_finished { return }
        
        let effectiveChunkSize = max(1024, outputChunkSize)
        let outBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: effectiveChunkSize)
        defer { outBuffer.deallocate() }
        
        var dummy: UInt8 = 0
        while !state.is_finished {
            let beforeOut = state.total_out
            let produced = ttzip_deflate_stream_process(
                &state,
                &dummy,
                0,
                outBuffer,
                effectiveChunkSize,
                DeflateFlushMode.finish.rawValue
            )
            if produced > 0 {
                chunkHandler(UnsafeRawBufferPointer(start: outBuffer, count: produced))
            }
            if state.is_finished || state.total_out == beforeOut {
                break
            }
        }
    }
    
    /// 结束压缩并返回所有剩余尾部数据
    public func finish(outputChunkSize: Int = 64 * 1024) throws -> Data {
        var output = Data()
        try finish(outputChunkSize: outputChunkSize) { outChunk in
            output.append(outChunk.bindMemory(to: UInt8.self))
        }
        return output
    }
    
    /// 关闭压缩器并安全回收句柄
    public func close() {
        guard !isClosed else { return }
        isClosed = true
        ttzip_deflate_stream_free(&state)
    }
}

// MARK: - DeflateStreamDecompressor

/// 高性能原生 Deflate/Inflate 流式解压器
public final class DeflateStreamDecompressor: @unchecked Sendable {
    private var state = ttzip_deflate_stream_state_t()
    private var isClosed = false
    public let sessionId: UUID
    public let windowBits: Int
    
    public init(windowBits: Int = 15) throws {
        self.sessionId = UUID()
        self.windowBits = windowBits
        let status = ttzip_inflate_stream_init(&self.state, Int32(windowBits))
        guard status == 0 else {
            throw DeflateStreamError.initializationFailed(status)
        }
    }
    
    deinit {
        close()
    }
    
    public var totalIn: UInt64 {
        return state.total_in
    }
    
    public var totalOut: UInt64 {
        return state.total_out
    }
    
    public var adler32: UInt32 {
        return state.adler32_checksum
    }
    
    public var crc32: UInt32 {
        return state.crc32_checksum
    }
    
    public var isFinished: Bool {
        return state.is_finished
    }
    
    public var metrics: DeflateStreamMetrics {
        return DeflateStreamMetrics(
            totalIn: state.total_in,
            totalOut: state.total_out,
            adler32: state.adler32_checksum,
            crc32: state.crc32_checksum,
            isFinished: state.is_finished
        )
    }
    
    /// 流式解压指针缓冲区
    public func decompress(
        buffer: UnsafeRawPointer,
        count: Int,
        flush: DeflateFlushMode = .noFlush,
        outputChunkSize: Int = 64 * 1024,
        chunkHandler: (UnsafeRawBufferPointer) -> Void
    ) throws {
        guard !isClosed else { throw DeflateStreamError.streamAlreadyClosed }
        guard count > 0 || flush == .finish else { return }
        
        let effectiveChunkSize = max(1024, outputChunkSize)
        let outBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: effectiveChunkSize)
        defer { outBuffer.deallocate() }
        
        var offset = 0
        while offset < count || (count == 0 && flush == .finish && !state.is_finished) {
            let currentInPtr = count > 0 ? buffer.advanced(by: offset).assumingMemoryBound(to: UInt8.self) : nil
            let remainingIn = count - offset
            let beforeIn = state.total_in
            let beforeOut = state.total_out
            
            let produced = ttzip_inflate_stream_process(
                &state,
                currentInPtr,
                remainingIn,
                outBuffer,
                effectiveChunkSize,
                flush.rawValue
            )
            
            if state.last_status < 0 && state.last_status != -5 /* Z_BUF_ERROR */ {
                throw DeflateStreamError.corruptedData("Stream decompression failed with status: \(state.last_status)")
            }
            
            let consumed = Int(state.total_in - beforeIn)
            
            if produced > 0 {
                chunkHandler(UnsafeRawBufferPointer(start: outBuffer, count: produced))
            }
            
            if consumed > 0 {
                offset += consumed
            }
            
            if state.is_finished {
                break
            }
            
            if consumed == 0 && state.total_out == beforeOut {
                if offset < count && !state.is_finished {
                    throw DeflateStreamError.corruptedData("Stream decompression halted without completing input")
                }
                break
            }
        }
        
        if flush == .finish && !state.is_finished {
            throw DeflateStreamError.corruptedData("Deflate stream ended prematurely without Z_STREAM_END")
        }
    }
    
    /// 流式解压 Data 块并返回解压数据
    public func decompress(
        chunk: Data,
        flush: DeflateFlushMode = .noFlush,
        outputChunkSize: Int = 64 * 1024
    ) throws -> Data {
        var output = Data()
        if chunk.isEmpty && flush != .finish {
            return output
        }
        
        try chunk.withUnsafeBytes { rawBuffer in
            if let baseAddress = rawBuffer.baseAddress {
                try decompress(
                    buffer: baseAddress,
                    count: rawBuffer.count,
                    flush: flush,
                    outputChunkSize: outputChunkSize
                ) { outChunk in
                    output.append(outChunk.bindMemory(to: UInt8.self))
                }
            } else {
                let dummy = [UInt8]()
                try dummy.withUnsafeBytes { dummyBuffer in
                    try decompress(
                        buffer: dummyBuffer.baseAddress ?? UnsafeRawPointer(bitPattern: 1)!,
                        count: 0,
                        flush: flush,
                        outputChunkSize: outputChunkSize
                    ) { outChunk in
                        output.append(outChunk.bindMemory(to: UInt8.self))
                    }
                }
            }
        }
        return output
    }
    
    /// 结束解压并刷出剩余数据
    public func finish(
        outputChunkSize: Int = 64 * 1024,
        chunkHandler: (UnsafeRawBufferPointer) -> Void
    ) throws {
        guard !isClosed else { throw DeflateStreamError.streamAlreadyClosed }
        if state.is_finished { return }
        
        let effectiveChunkSize = max(1024, outputChunkSize)
        let outBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: effectiveChunkSize)
        defer { outBuffer.deallocate() }
        
        var dummy: UInt8 = 0
        while !state.is_finished {
            let beforeOut = state.total_out
            let produced = ttzip_inflate_stream_process(
                &state,
                &dummy,
                0,
                outBuffer,
                effectiveChunkSize,
                DeflateFlushMode.finish.rawValue
            )
            if state.last_status < 0 && state.last_status != -5 {
                throw DeflateStreamError.corruptedData("Stream decompression failed with status: \(state.last_status)")
            }
            if produced > 0 {
                chunkHandler(UnsafeRawBufferPointer(start: outBuffer, count: produced))
            }
            if state.is_finished || state.total_out == beforeOut {
                break
            }
        }
        if !state.is_finished {
            throw DeflateStreamError.corruptedData("Deflate stream did not finish cleanly (status: \(state.last_status))")
        }
    }
    
    /// 结束解压并返回剩余数据
    public func finish(outputChunkSize: Int = 64 * 1024) throws -> Data {
        var output = Data()
        try finish(outputChunkSize: outputChunkSize) { outChunk in
            output.append(outChunk.bindMemory(to: UInt8.self))
        }
        return output
    }
    
    /// 关闭解压器并安全回收句柄
    public func close() {
        guard !isClosed else { return }
        isClosed = true
        ttzip_inflate_stream_free(&state)
    }
}

// MARK: - DeflateStreamEngine (Unified High-Level Pipeline API)

/// 统一的高性能 Deflate 流式引擎管道门面
public enum DeflateStreamEngine: Sendable {
    
    /// 一站式内存压缩
    public static func compress(
        data: Data,
        config: DeflateStreamConfig = DeflateStreamConfig(),
        outputChunkSize: Int = 64 * 1024
    ) throws -> Data {
        let compressor = try DeflateStreamCompressor(config: config)
        var result = try compressor.compress(chunk: data, flush: .finish, outputChunkSize: outputChunkSize)
        if !compressor.isFinished {
            let tail = try compressor.finish(outputChunkSize: outputChunkSize)
            result.append(tail)
        }
        return result
    }
    
    /// 一站式内存解压
    public static func decompress(
        data: Data,
        windowBits: Int = 15,
        outputChunkSize: Int = 64 * 1024
    ) throws -> Data {
        let decompressor = try DeflateStreamDecompressor(windowBits: windowBits)
        var result = try decompressor.decompress(chunk: data, flush: .finish, outputChunkSize: outputChunkSize)
        if !decompressor.isFinished {
            let tail = try decompressor.finish(outputChunkSize: outputChunkSize)
            result.append(tail)
        }
        return result
    }
    
    /// 异步流式压缩管道 (AsyncSequence -> AsyncThrowingStream)
    public static func compressStream<S: AsyncSequence>(
        _ sequence: S,
        config: DeflateStreamConfig = DeflateStreamConfig(),
        outputChunkSize: Int = 64 * 1024
    ) -> AsyncThrowingStream<Data, Error> where S.Element == Data, S: Sendable {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let compressor = try DeflateStreamCompressor(config: config)
                    defer { compressor.close() }
                    
                    for try await chunk in sequence {
                        try Task.checkCancellation()
                        let compressedChunk = try compressor.compress(
                            chunk: chunk,
                            flush: .noFlush,
                            outputChunkSize: outputChunkSize
                        )
                        if !compressedChunk.isEmpty {
                            continuation.yield(compressedChunk)
                        }
                    }
                    
                    let tail = try compressor.finish(outputChunkSize: outputChunkSize)
                    if !tail.isEmpty {
                        continuation.yield(tail)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
    
    /// 异步流式解压管道 (AsyncSequence -> AsyncThrowingStream)
    public static func decompressStream<S: AsyncSequence>(
        _ sequence: S,
        windowBits: Int = 15,
        outputChunkSize: Int = 64 * 1024
    ) -> AsyncThrowingStream<Data, Error> where S.Element == Data, S: Sendable {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let decompressor = try DeflateStreamDecompressor(windowBits: windowBits)
                    defer { decompressor.close() }
                    
                    for try await chunk in sequence {
                        try Task.checkCancellation()
                        let decompressedChunk = try decompressor.decompress(
                            chunk: chunk,
                            flush: .noFlush,
                            outputChunkSize: outputChunkSize
                        )
                        if !decompressedChunk.isEmpty {
                            continuation.yield(decompressedChunk)
                        }
                    }
                    
                    let tail = try decompressor.finish(outputChunkSize: outputChunkSize)
                    if !tail.isEmpty {
                        continuation.yield(tail)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}
