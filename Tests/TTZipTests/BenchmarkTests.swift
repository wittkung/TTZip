// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class BenchmarkTests: XCTestCase {
    
    var payloadSize: Int {
        TestBenchmarkTier.isBenchmarkMode ? (5 * 1024 * 1024) : (1024 * 1024)
    }
    
    private func createRealWorldPayload(at sandbox: IsolatedTempSandbox) throws -> String {
        let realWorldFilePath = sandbox.fileURL(named: "real_world_payload.bin").path
        var realWorldData = Data()
        realWorldData.reserveCapacity(payloadSize)
        
        let codeLines = [
            "import Foundation\n",
            "public struct CompressionChunkHeader { public var flags: UInt32; public var crc: UInt32 }\n",
            "func processStream(input: UnsafePointer<UInt8>, length: Int) -> Int { return length * 2 }\n",
            "let buffer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: 65536)\n"
        ]
        
        var seed: UInt64 = 0x123456789ABCDEF0
        func nextRandomByte() -> UInt8 {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return UInt8(truncatingIfNeeded: seed >> 32)
        }
        
        var iter = 0
        while realWorldData.count < payloadSize {
            iter += 1
            let json = "{\"id\":\(iter),\"guid\":\"4F8A-\(iter)-89AB\",\"timestamp\":1770000000}\n"
            realWorldData.append(contentsOf: json.utf8)
            
            let line = codeLines[iter % codeLines.count]
            realWorldData.append(contentsOf: line.utf8)
            
            var randomBytes = [UInt8](repeating: 0, count: 256)
            for i in 0..<256 {
                randomBytes[i] = nextRandomByte()
            }
            realWorldData.append(contentsOf: randomBytes)
        }
        realWorldData = realWorldData.prefix(payloadSize)
        try realWorldData.write(to: URL(fileURLWithPath: realWorldFilePath))
        return realWorldFilePath
    }
    
    func testZipPerformanceMetrics() async throws {
        try await runBenchmarkForFormat(.zip, formatName: "ZIP (Deflate)")
    }
    
    func testTarGzPerformanceMetrics() async throws {
        try await runBenchmarkForFormat(.tarGz, formatName: "TAR.GZ (Gzip)")
    }
    
    func testTarZstPerformanceMetrics() async throws {
        try await runBenchmarkForFormat(.tarZst, formatName: "TAR.ZST (Zstandard)")
    }
    
    func testRealWorldMixedPayloadMetrics() async throws {
        try await runBenchmarkForFormat(.tarZst, formatName: "TAR.ZST 真实混合数据")
    }
    
    private func runBenchmarkForFormat(_ format: ArchiveCompressionFormat, formatName: String) async throws {
        let sandbox = try IsolatedTempSandbox(prefix: "bench_\(format.rawValue)")
        defer { sandbox.cleanup() }
        
        let inputPath = try createRealWorldPayload(at: sandbox)
        let outArchive = sandbox.fileURL(named: "out.\(format.rawValue)").path
        let extractDest = sandbox.fileURL(named: "extracted").path
        
        let originalData = try Data(contentsOf: URL(fileURLWithPath: inputPath))
        let rawSizeBytes = Double(originalData.count)
        let rawMB = rawSizeBytes / (1024 * 1024)
        
        // 1.
        let writer = ArchiveWriter()
        let clock = ContinuousClock()
        
        let compressElapsed = try await clock.measure {
            try await writer.createArchive(outputPath: outArchive, format: format, level: .normal, inputPaths: [inputPath])
        }
        let compressDuration = max(0.0001, Double(compressElapsed.components.seconds) + (Double(compressElapsed.components.attoseconds) / 1e18))
        let compressSpeedMBps = rawMB / compressDuration
        
        // 2.
        let attr = try FileManager.default.attributesOfItem(atPath: outArchive)
        let compressedSizeBytes = Double(attr[.size] as? Int64 ?? 0)
        
        // 3.
        let extractor = ArchiveExtractor()
        let decompressElapsed = try await clock.measure {
            try await extractor.extract(archivePath: outArchive, destinationDir: extractDest)
        }
        let decompressDuration = max(0.0001, Double(decompressElapsed.components.seconds) + (Double(decompressElapsed.components.attoseconds) / 1e18))
        let decompressSpeedMBps = rawMB / decompressDuration
        
        // Verify expected invariant
        let extractedFilePath = (extractDest as NSString).appendingPathComponent((inputPath as NSString).lastPathComponent)
        if FileManager.default.fileExists(atPath: extractedFilePath) {
            let restoredData = try Data(contentsOf: URL(fileURLWithPath: extractedFilePath))
            XCTAssertEqual(restoredData, originalData, "解压后的文件数据必须与原始文件在字节级别 100% 完全一致！")
        }
        
        TTZipTestLogger.logMetricsRow(
            format: format.rawValue,
            payloadMB: rawMB,
            compressedMB: compressedSizeBytes / (1024 * 1024),
            compressSpeedMBs: compressSpeedMBps,
            decompressSpeedMBs: decompressSpeedMBps,
            elapsedSeconds: compressDuration + decompressDuration
        )
        
        XCTAssertGreaterThan(compressSpeedMBps, 5.0, "压缩速度应高于 5 MB/s")
        XCTAssertGreaterThan(decompressSpeedMBps, 10.0, "解压速度应高于 10 MB/s")
    }
}
