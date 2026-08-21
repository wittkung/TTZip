// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class DeflateStreamEngineTests: XCTestCase {
    
    func testOneShotCompressDecompressZlib() throws {
        let originalText = "Hello, TTZip Deflate Streaming Engine High-Performance Test! 1234567890"
        let originalData = Data(originalText.utf8)
        
        let compressed = try DeflateStreamEngine.compress(data: originalData)
        XCTAssertFalse(compressed.isEmpty)
        
        let decompressed = try DeflateStreamEngine.decompress(data: compressed)
        XCTAssertEqual(decompressed, originalData)
        XCTAssertEqual(String(data: decompressed, encoding: .utf8), originalText)
    }
    
    func testOneShotCompressDecompressGzip() throws {
        let originalText = String(repeating: "TTZip GZIP Streaming Pipeline Validation Block. ", count: 20)
        let originalData = Data(originalText.utf8)
        
        let config = DeflateStreamConfig.standardGzip
        let compressed = try DeflateStreamEngine.compress(data: originalData, config: config)
        XCTAssertFalse(compressed.isEmpty)
        
        let decompressed = try DeflateStreamEngine.decompress(data: compressed, windowBits: 31)
        XCTAssertEqual(decompressed, originalData)
    }
    
    func testOneShotCompressDecompressRawDeflate() throws {
        let originalText = "Raw RFC 1951 Deflate Payload without headers or checksums."
        let originalData = Data(originalText.utf8)
        
        let config = DeflateStreamConfig.standardRaw
        let compressed = try DeflateStreamEngine.compress(data: originalData, config: config)
        XCTAssertFalse(compressed.isEmpty)
        
        let decompressed = try DeflateStreamEngine.decompress(data: compressed, windowBits: -15)
        XCTAssertEqual(decompressed, originalData)
    }
    
    func testCompressorDecompressorChunkStreaming() throws {
        let payload = Data(repeating: 0x42, count: 256 * 1024) // 256 KB
        let chunkSize = 16 * 1024 // 16 KB chunks
        
        let compressor = try DeflateStreamCompressor(config: .fastStreaming)
        var compressedData = Data()
        
        var offset = 0
        while offset < payload.count {
            let length = min(chunkSize, payload.count - offset)
            let sub = payload.subdata(in: offset..<(offset + length))
            offset += length
            
            let isLast = (offset >= payload.count)
            let outChunk = try compressor.compress(chunk: sub, flush: isLast ? .finish : .noFlush)
            compressedData.append(outChunk)
        }
        
        if !compressor.isFinished {
            let tail = try compressor.finish()
            compressedData.append(tail)
        }
        
        let metrics = compressor.metrics
        XCTAssertEqual(metrics.totalIn, UInt64(payload.count))
        XCTAssertTrue(metrics.totalOut > 0)
        XCTAssertTrue(metrics.isFinished)
        
        // Decompress chunk by chunk
        let decompressor = try DeflateStreamDecompressor(windowBits: 15)
        var decompressedData = Data()
        
        var compOffset = 0
        let compChunkSize = 8 * 1024
        while compOffset < compressedData.count {
            let length = min(compChunkSize, compressedData.count - compOffset)
            let sub = compressedData.subdata(in: compOffset..<(compOffset + length))
            compOffset += length
            
            let isLast = (compOffset >= compressedData.count)
            let outChunk = try decompressor.decompress(chunk: sub, flush: isLast ? .finish : .noFlush)
            decompressedData.append(outChunk)
        }
        
        if !decompressor.isFinished {
            let tail = try decompressor.finish()
            decompressedData.append(tail)
        }
        
        XCTAssertEqual(decompressedData, payload)
        XCTAssertEqual(decompressor.metrics.totalOut, UInt64(payload.count))
    }
    
    func testAsyncStreamingPipeline() async throws {
        let chunks = [
            Data("Chunk 1: Async Deflate Stream Pipeline. ".utf8),
            Data("Chunk 2: High-throughput memory-safe streaming. ".utf8),
            Data("Chunk 3: Complete verification test suite.".utf8)
        ]
        let expectedTotal = chunks.reduce(Data(), +)
        
        struct MockSequence: AsyncSequence, Sendable {
            typealias Element = Data
            let items: [Data]
            
            struct AsyncIterator: AsyncIteratorProtocol {
                var index = 0
                let items: [Data]
                
                mutating func next() async throws -> Data? {
                    guard index < items.count else { return nil }
                    let item = items[index]
                    index += 1
                    return item
                }
            }
            
            func makeAsyncIterator() -> AsyncIterator {
                AsyncIterator(items: items)
            }
        }
        
        let compressedStream = DeflateStreamEngine.compressStream(MockSequence(items: chunks))
        var compressedPayload = Data()
        for try await chunk in compressedStream {
            compressedPayload.append(chunk)
        }
        XCTAssertFalse(compressedPayload.isEmpty)
        
        let decompressedStream = DeflateStreamEngine.decompressStream(MockSequence(items: [compressedPayload]))
        var decompressedPayload = Data()
        for try await chunk in decompressedStream {
            decompressedPayload.append(chunk)
        }
        
        XCTAssertEqual(decompressedPayload, expectedTotal)
    }
    
    func testDeflateStreamErrorAndEdgeCases() throws {
        let decompressor = try DeflateStreamDecompressor()
        let corruptedData = Data([0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0x11])
        
        XCTAssertThrowsError(try decompressor.decompress(chunk: corruptedData, flush: .finish)) { error in
            guard let deflateError = error as? DeflateStreamError else {
                XCTFail("Expected DeflateStreamError, got \(error)")
                return
            }
            if case .corruptedData = deflateError {
                // Success
            } else {
                XCTFail("Expected corruptedData error, got \(deflateError)")
            }
        }
    }
}
