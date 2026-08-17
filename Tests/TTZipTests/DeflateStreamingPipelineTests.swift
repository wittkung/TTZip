import XCTest
@testable import TTZipCore
import CTTZipBridge

final class DeflateStreamingPipelineTests: XCTestCase {
    
    // MARK: - 1. AsyncSequence / AsyncThrowingStream Pipeline
    
    func testAsyncStreamDeflatePipeline() async throws {
        let chunkCount = 20
        let chunkSize = 64 * 1024 // 64KB each
        var chunks: [Data] = []
        var expectedOriginal = Data()
        
        for i in 0..<chunkCount {
            let line = "AsyncPipelineChunk_\(i)_" + String(repeating: "TTZip_NEON_Stream_\(i)_", count: chunkSize / 32)
            let chunkData = line.data(using: .utf8)!
            chunks.append(chunkData)
            expectedOriginal.append(chunkData)
        }
        
        let asyncChunks = AsyncStream<Data> { continuation in
            for chunk in chunks {
                continuation.yield(chunk)
            }
            continuation.finish()
        }
        
        let compressedStream = DeflateStreamEngine.compressStream(
            asyncChunks,
            config: .fastStreaming,
            outputChunkSize: 32 * 1024
        )
        
        var compressedChunks: [Data] = []
        for try await compChunk in compressedStream {
            compressedChunks.append(compChunk)
        }
        
        let totalCompressedBytes = compressedChunks.reduce(0) { $0 + $1.count }
        XCTAssertGreaterThan(totalCompressedBytes, 0)
        XCTAssertLessThan(totalCompressedBytes, expectedOriginal.count)
        
        // Decompress via async stream
        let compressedAsyncStream = AsyncStream<Data> { continuation in
            for chunk in compressedChunks {
                continuation.yield(chunk)
            }
            continuation.finish()
        }
        
        let decompressedStream = DeflateStreamEngine.decompressStream(
            compressedAsyncStream,
            windowBits: 15,
            outputChunkSize: 32 * 1024
        )
        
        var decompressedData = Data()
        for try await decompChunk in decompressedStream {
            decompressedData.append(decompChunk)
        }
        
        XCTAssertEqual(decompressedData.count, expectedOriginal.count)
        XCTAssertEqual(decompressedData, expectedOriginal, "Async stream roundtrip must yield bit-identical payload")
    }
    
    // MARK: - 2. Multi-MegaByte GZIP Streaming Pipeline
    
    func testMultiMegaByteGzipStreamingPipeline() async throws {
        let targetSize = 5 * 1024 * 1024 // 5MB
        let pattern = "GZIP_MultiMegaByte_Stream_Payload_Pattern_2026_AppleSilicon#".data(using: .utf8)!
        
        var originalData = Data()
        originalData.reserveCapacity(targetSize)
        while originalData.count < targetSize {
            originalData.append(pattern)
        }
        
        let chunkSizeBytes = 64 * 1024
        var inputChunks: [Data] = []
        var offset = 0
        while offset < originalData.count {
            let length = min(chunkSizeBytes, originalData.count - offset)
            inputChunks.append(originalData.subdata(in: offset..<(offset + length)))
            offset += length
        }
        
        let inputStream = AsyncStream<Data> { continuation in
            for chunk in inputChunks {
                continuation.yield(chunk)
            }
            continuation.finish()
        }
        
        let gzipCompressedStream = DeflateStreamEngine.compressStream(
            inputStream,
            config: .gzipFastStreaming,
            outputChunkSize: chunkSizeBytes
        )
        
        var compressedChunks: [Data] = []
        for try await compChunk in gzipCompressedStream {
            compressedChunks.append(compChunk)
        }
        
        let compressedStreamForDecompress = AsyncStream<Data> { continuation in
            for chunk in compressedChunks {
                continuation.yield(chunk)
            }
            continuation.finish()
        }
        
        let gzipDecompressedStream = DeflateStreamEngine.decompressStream(
            compressedStreamForDecompress,
            windowBits: 31,
            outputChunkSize: chunkSizeBytes
        )
        
        var recoveredData = Data()
        for try await decompChunk in gzipDecompressedStream {
            recoveredData.append(decompChunk)
        }
        
        XCTAssertEqual(recoveredData.count, originalData.count)
        XCTAssertEqual(recoveredData, originalData)
    }
    
    // MARK: - 3. Raw Deflate Streaming Pipeline
    
    func testRawDeflateStreamingLargePipeline() async throws {
        let sample = Data((0..<(2 * 1024 * 1024)).map { UInt8(($0 * 31) & 0xFF) })
        let chunkSize = 128 * 1024
        
        var chunks: [Data] = []
        var offset = 0
        while offset < sample.count {
            let len = min(chunkSize, sample.count - offset)
            chunks.append(sample.subdata(in: offset..<(offset + len)))
            offset += len
        }
        
        let inStream = AsyncStream<Data> { continuation in
            for c in chunks { continuation.yield(c) }
            continuation.finish()
        }
        
        let compStream = DeflateStreamEngine.compressStream(
            inStream,
            config: .rawFastStreaming,
            outputChunkSize: chunkSize
        )
        
        var compChunks: [Data] = []
        for try await c in compStream {
            compChunks.append(c)
        }
        
        let compStreamIn = AsyncStream<Data> { continuation in
            for c in compChunks { continuation.yield(c) }
            continuation.finish()
        }
        
        let decompStream = DeflateStreamEngine.decompressStream(
            compStreamIn,
            windowBits: -15,
            outputChunkSize: chunkSize
        )
        
        var decompData = Data()
        for try await c in decompStream {
            decompData.append(c)
        }
        
        XCTAssertEqual(decompData.count, sample.count)
        XCTAssertEqual(decompData, sample)
    }
    
    // MARK: - 4. Closure-based UnsafeRawBufferPointer Zero-Copy Chunk Handler
    
    func testChunkedStreamHandlerZeroCopyBuffer() throws {
        let text = "Zero_Copy_Pointer_Handler_Validation_Stream_2026_" + String(repeating: "TTZip_NEON_FastPath_", count: 100)
        let data = text.data(using: .utf8)!
        
        let compressor = try DeflateStreamCompressor(config: .standardGzip)
        var compressed = Data()
        
        try data.withUnsafeBytes { rawIn in
            try compressor.compress(
                buffer: rawIn.baseAddress!,
                count: rawIn.count,
                flush: .finish,
                outputChunkSize: 4096
            ) { rawOut in
                compressed.append(rawOut.bindMemory(to: UInt8.self))
            }
        }
        
        if !compressor.isFinished {
            try compressor.finish(outputChunkSize: 4096) { rawOut in
                compressed.append(rawOut.bindMemory(to: UInt8.self))
            }
        }
        
        XCTAssertTrue(compressor.isFinished)
        XCTAssertGreaterThan(compressed.count, 0)
        
        let decompressor = try DeflateStreamDecompressor(windowBits: 31)
        var decompressed = Data()
        
        try compressed.withUnsafeBytes { rawIn in
            try decompressor.decompress(
                buffer: rawIn.baseAddress!,
                count: rawIn.count,
                flush: .finish,
                outputChunkSize: 4096
            ) { rawOut in
                decompressed.append(rawOut.bindMemory(to: UInt8.self))
            }
        }
        
        if !decompressor.isFinished {
            try decompressor.finish(outputChunkSize: 4096) { rawOut in
                decompressed.append(rawOut.bindMemory(to: UInt8.self))
            }
        }
        
        XCTAssertEqual(decompressed, data)
    }
    
    // MARK: - 5. Parallel Concurrent Streaming Sessions
    
    func testPipelinedConcurrentStreamingSessions() async throws {
        let iterations = 20
        
        await withTaskGroup(of: Bool.self) { group in
            for i in 0..<iterations {
                group.addTask {
                    do {
                        let sampleString = "ConcurrentStreamTask_\(i)_" + String(repeating: "TTZip_Concurrent_SIMD_\(i)_", count: 200)
                        let payload = sampleString.data(using: .utf8)!
                        
                        let config = DeflateStreamConfig(compressionLevel: (i % 9) + 1, windowBits: (i % 2 == 0) ? 15 : 31)
                        let compressed = try DeflateStreamEngine.compress(data: payload, config: config)
                        let decompressed = try DeflateStreamEngine.decompress(data: compressed, windowBits: config.windowBits)
                        return decompressed == payload
                    } catch {
                        return false
                    }
                }
            }
            
            for await result in group {
                XCTAssertTrue(result, "All parallel concurrent streaming sessions must complete successfully without race conditions")
            }
        }
    }
}
