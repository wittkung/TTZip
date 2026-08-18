// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore
import CTTZipBridge

final class DeflateStreamCoderTests: XCTestCase {
    
    // MARK: - 1. RFC 1950 (Zlib), RFC 1952 (Gzip), RFC 1951 (Raw) Roundtrip Fidelity Tests
    
    func testDeflateZlibHeaderRoundtrip() throws {
        let sampleString = "AppleSilicon_Deflate_Streaming_Test_Payload_" + String(repeating: "TTZip_High_Performance_Engine_2026_", count: 500)
        let sampleData = sampleString.data(using: .utf8)!
        
        let config = DeflateStreamConfig(compressionLevel: 6, windowBits: 15)
        let compressed = try DeflateStreamEngine.compress(data: sampleData, config: config)
        XCTAssertGreaterThan(compressed.count, 0)
        XCTAssertLessThan(compressed.count, sampleData.count)
        
        let decompressed = try DeflateStreamEngine.decompress(data: compressed, windowBits: 15)
        XCTAssertEqual(decompressed, sampleData, "Zlib-wrapped Deflate decompression must match original payload 100%")
    }
    
    func testDeflateGzipHeaderRoundtrip() throws {
        let sampleString = "GZIP_RFC1952_Compatibility_Payload_Test_" + String(repeating: "TTZip_NEON_Streaming_SIMD_", count: 1000)
        let sampleData = sampleString.data(using: .utf8)!
        
        let config = DeflateStreamConfig(compressionLevel: 1, windowBits: 31)
        let compressor = try DeflateStreamCompressor(config: config)
        
        var compressed = try compressor.compress(chunk: sampleData, flush: .finish)
        if !compressor.isFinished {
            let tail = try compressor.finish()
            compressed.append(tail)
        }
        
        XCTAssertGreaterThan(compressed.count, 0)
        XCTAssertLessThan(compressed.count, sampleData.count)
        XCTAssertGreaterThan(compressor.crc32, 0, "GZIP stream must compute non-zero CRC-32 checksum")
        
        // Decompress with GZIP window bits (31)
        let decompressor = try DeflateStreamDecompressor(windowBits: 31)
        var decompressed = try decompressor.decompress(chunk: compressed, flush: .finish)
        if !decompressor.isFinished {
            let tail = try decompressor.finish()
            decompressed.append(tail)
        }
        
        XCTAssertEqual(decompressed, sampleData, "GZIP-wrapped Deflate decompression must recover original data")
        XCTAssertEqual(decompressor.crc32, compressor.crc32, "Decompressor CRC-32 must match compressor CRC-32")
    }
    
    func testDeflateRawDeflateRoundtrip() throws {
        let sampleData = Data((0..<16384).map { UInt8($0 & 0xFF) })
        let config = DeflateStreamConfig(compressionLevel: 6, windowBits: -15)
        
        let compressed = try DeflateStreamEngine.compress(data: sampleData, config: config)
        XCTAssertGreaterThan(compressed.count, 0)
        
        let decompressed = try DeflateStreamEngine.decompress(data: compressed, windowBits: -15)
        XCTAssertEqual(decompressed, sampleData, "Raw Deflate (RFC 1951) must roundtrip bit-identically")
    }
    
    // MARK: - 2. All Compression Levels (1 to 9)
    
    func testDeflateAllCompressionLevels() throws {
        let payload = Data(repeating: 0x42, count: 64 * 1024)
        
        for level in 1...9 {
            let config = DeflateStreamConfig(compressionLevel: level, windowBits: 15)
            let compressed = try DeflateStreamEngine.compress(data: payload, config: config)
            XCTAssertGreaterThan(compressed.count, 0, "Level \(level) must produce valid compressed output")
            XCTAssertLessThan(compressed.count, payload.count, "Level \(level) must achieve compression")
            
            let decompressed = try DeflateStreamEngine.decompress(data: compressed, windowBits: 15)
            XCTAssertEqual(decompressed, payload, "Level \(level) roundtrip must be 100% data faithful")
        }
    }
    
    // MARK: - 3. Flush Modes Testing
    
    func testDeflateFlushModes() throws {
        let payloadPart1 = "Part1_FlushMode_Testing_SyncFlush_".data(using: .utf8)!
        let payloadPart2 = "Part2_FlushMode_Testing_FullFlush_".data(using: .utf8)!
        let payloadPart3 = "Part3_FlushMode_Testing_Finish_".data(using: .utf8)!
        let totalOriginal = payloadPart1 + payloadPart2 + payloadPart3
        
        let compressor = try DeflateStreamCompressor(config: DeflateStreamConfig(compressionLevel: 6, windowBits: 15))
        var compressed = Data()
        
        // 1. Sync Flush
        let chunk1 = try compressor.compress(chunk: payloadPart1, flush: .syncFlush)
        compressed.append(chunk1)
        XCTAssertGreaterThan(chunk1.count, 0, "SYNC_FLUSH must immediately emit compressed bytes")
        
        // 2. Full Flush
        let chunk2 = try compressor.compress(chunk: payloadPart2, flush: .fullFlush)
        compressed.append(chunk2)
        XCTAssertGreaterThan(chunk2.count, 0, "FULL_FLUSH must emit bytes and reset dictionary")
        
        // 3. Finish
        let chunk3 = try compressor.compress(chunk: payloadPart3, flush: .finish)
        compressed.append(chunk3)
        if !compressor.isFinished {
            let tail = try compressor.finish()
            compressed.append(tail)
        }
        
        XCTAssertTrue(compressor.isFinished)
        
        let decompressor = try DeflateStreamDecompressor(windowBits: 15)
        var decompressed = try decompressor.decompress(chunk: compressed, flush: .finish)
        if !decompressor.isFinished {
            let tail = try decompressor.finish()
            decompressed.append(tail)
        }
        
        XCTAssertEqual(decompressed, totalOriginal, "Interleaved flush modes must decompress to the exact concatenation")
    }
    
    // MARK: - 4. Chunk Granularities (1KB, 64KB, 1MB)
    
    func testDeflateChunkGranularities() throws {
        let pattern = "Granularity_Test_Chunk_2026_AppleSilicon_MSeries_".data(using: .utf8)!
        var fullPayload = Data()
        while fullPayload.count < 2 * 1024 * 1024 { // 2MB
            fullPayload.append(pattern)
        }
        
        let chunkSizes = [1024, 64 * 1024, 1024 * 1024]
        
        for chunkSize in chunkSizes {
            let compressor = try DeflateStreamCompressor(config: .gzipFastStreaming)
            var compressed = Data()
            
            var offset = 0
            while offset < fullPayload.count {
                let thisChunkSize = min(chunkSize, fullPayload.count - offset)
                let subdata = fullPayload.subdata(in: offset..<(offset + thisChunkSize))
                offset += thisChunkSize
                let isLast = (offset == fullPayload.count)
                
                let outChunk = try compressor.compress(
                    chunk: subdata,
                    flush: isLast ? .finish : .noFlush,
                    outputChunkSize: chunkSize
                )
                compressed.append(outChunk)
            }
            if !compressor.isFinished {
                let tail = try compressor.finish(outputChunkSize: chunkSize)
                compressed.append(tail)
            }
            
            XCTAssertTrue(compressor.isFinished)
            XCTAssertEqual(compressor.totalIn, UInt64(fullPayload.count))
            
            // Decompress with matching or different chunk size
            let decompressor = try DeflateStreamDecompressor(windowBits: 31)
            var decompressed = Data()
            
            var decompOffset = 0
            while decompOffset < compressed.count {
                let thisDecompChunk = min(chunkSize, compressed.count - decompOffset)
                let subdata = compressed.subdata(in: decompOffset..<(decompOffset + thisDecompChunk))
                decompOffset += thisDecompChunk
                let isLast = (decompOffset == compressed.count)
                
                let outChunk = try decompressor.decompress(
                    chunk: subdata,
                    flush: isLast ? .finish : .noFlush,
                    outputChunkSize: chunkSize
                )
                decompressed.append(outChunk)
            }
            if !decompressor.isFinished {
                let tail = try decompressor.finish(outputChunkSize: chunkSize)
                decompressed.append(tail)
            }
            
            XCTAssertEqual(decompressed.count, fullPayload.count, "Chunk size \(chunkSize) must recover exact byte count")
            XCTAssertEqual(decompressed, fullPayload, "Chunk size \(chunkSize) decompression must be bit-identical")
        }
    }
    
    // MARK: - 5. Streaming Throughput Gate Assertions (>= 350 MB/s)
    
    func testDeflateStreamingThroughputFloor() throws {
        // Construct 10MB test payload with realistic compressible entropy
        let logLine = "2026-08-17 12:00:00.123 [INFO] DeflateStreamEngine - Block #1024 NEON accelerated pipeline throughput test pass\n"
        let lineData = logLine.data(using: .utf8)!
        var payload = Data()
        payload.reserveCapacity(10 * 1024 * 1024)
        while payload.count < 10 * 1024 * 1024 {
            payload.append(lineData)
        }
        
        let config = DeflateStreamConfig.fastStreaming // Level 1 fast streaming
        let compressor = try DeflateStreamCompressor(config: config)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        var compressed = try compressor.compress(chunk: payload, flush: .finish, outputChunkSize: 256 * 1024)
        if !compressor.isFinished {
            let tail = try compressor.finish(outputChunkSize: 256 * 1024)
            compressed.append(tail)
        }
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        let payloadMB = Double(payload.count) / (1024.0 * 1024.0)
        let throughputMBs = payloadMB / max(0.0001, elapsed)
        
        print("⚡️ [PERF GATE] Deflate Streaming Level 1 Throughput: \(String(format: "%.2f", throughputMBs)) MB/s (Elapsed: \(String(format: "%.4f", elapsed)) s)")
        
        XCTAssertGreaterThanOrEqual(
            throughputMBs,
            350.0,
            "Deflate Streaming Level 1 throughput (\(throughputMBs) MB/s) must satisfy performance floor >= 350 MB/s"
        )
        
        // Decompression Throughput Verification
        let decompressStartTime = CFAbsoluteTimeGetCurrent()
        let decompressed = try DeflateStreamEngine.decompress(data: compressed, windowBits: 15)
        let decompressElapsed = CFAbsoluteTimeGetCurrent() - decompressStartTime
        let decompressThroughputMBs = payloadMB / max(0.0001, decompressElapsed)
        
        print("⚡️ [PERF GATE] Deflate Streaming Decompression Throughput: \(String(format: "%.2f", decompressThroughputMBs)) MB/s")
        XCTAssertGreaterThanOrEqual(decompressThroughputMBs, 500.0, "Decompression throughput must exceed 500 MB/s")
        XCTAssertEqual(decompressed.count, payload.count)
    }
    
    // MARK: - 6. Invariant & Lifecycle Checks
    
    func testDeflateLifecycleAndMagicDefense() throws {
        let compressor = try DeflateStreamCompressor(config: .fastStreaming)
        XCTAssertFalse(compressor.isFinished)
        XCTAssertEqual(compressor.totalIn, 0)
        XCTAssertEqual(compressor.totalOut, 0)
        
        compressor.close()
        
        // Calling on closed compressor must throw streamAlreadyClosed
        let dummy = Data([1, 2, 3])
        XCTAssertThrowsError(try compressor.compress(chunk: dummy)) { error in
            guard let streamErr = error as? DeflateStreamError, streamErr == .streamAlreadyClosed else {
                XCTFail("Expected streamAlreadyClosed error, got \(error)")
                return
            }
        }
    }
    
    func testDeflateCorruptedStreamDetection() throws {
        let corruptedData = Data([0x1F, 0x8B, 0x08, 0x00, 0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0x00])
        let decompressor = try DeflateStreamDecompressor(windowBits: 31)
        
        XCTAssertThrowsError(try decompressor.decompress(chunk: corruptedData, flush: .finish))
    }
    
    // MARK: - 7. Schema & Contract Conformity
    
    func testContractSchemaCompliance() throws {
        let config = DeflateStreamConfig(
            tierMode: .tier2Stream,
            compressionLevel: 6,
            windowBits: 15,
            memLevel: 8,
            strategy: .defaultStrategy
        )
        
        XCTAssertEqual(config.tierMode.rawValue, 2)
        XCTAssertTrue(1...9 ~= config.compressionLevel)
        XCTAssertTrue([-15, 15, 31].contains(config.windowBits))
        XCTAssertTrue(1...9 ~= config.memLevel)
        XCTAssertTrue(0...4 ~= config.strategy.rawValue)
        
        let compressor = try DeflateStreamCompressor(config: config)
        XCTAssertFalse(compressor.sessionId.uuidString.isEmpty)
        
        let metrics = compressor.metrics
        XCTAssertEqual(metrics.totalIn, 0)
        XCTAssertEqual(metrics.totalOut, 0)
        XCTAssertFalse(metrics.isFinished)
    }
}
