// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import Foundation
import CryptoKit
@testable import TTZipCore
import CTTZipBridge

final class CrossBlockDeflateDictionaryTests: XCTestCase {
    
    private var sandboxDir: URL!
    
    override func setUpWithError() throws {
        sandboxDir = FileManager.default.temporaryDirectory.appendingPathComponent("ttzip_cross_dict_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: sandboxDir, withIntermediateDirectories: true)
    }
    
    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: sandboxDir)
    }
    
    // MARK: - 1. C Bridge Direct Kernel Tests
    
    func testRawDeflateBlockCompressWithDictDirect() {
        // Create repeating pattern across block boundary
        let pattern = "TTZip CrossBlock Deflate Sliding Window Dictionary Preconditioning Test 2026! ".data(using: .utf8)!
        var dictData = Data()
        while dictData.count < 32768 {
            dictData.append(pattern)
        }
        
        var chunkData = Data()
        while chunkData.count < 65536 {
            chunkData.append(pattern)
        }
        
        let maxOut = chunkData.count + 512
        let outWithDict = UnsafeMutablePointer<UInt8>.allocate(capacity: maxOut)
        let outWithoutDict = UnsafeMutablePointer<UInt8>.allocate(capacity: maxOut)
        defer {
            outWithDict.deallocate()
            outWithoutDict.deallocate()
        }
        
        // Compress with preceding 32KB dict
        let sizeWithDict = chunkData.withUnsafeBytes { chunkBuf in
            dictData.withUnsafeBytes { dictBuf in
                ttzip_raw_deflate_block_compress_with_dict(
                    chunkBuf.baseAddress!,
                    chunkBuf.count,
                    dictBuf.baseAddress!,
                    dictBuf.count,
                    outWithDict,
                    maxOut,
                    6,
                    false
                )
            }
        }
        
        // Compress without dict
        let sizeWithoutDict = chunkData.withUnsafeBytes { chunkBuf in
            ttzip_raw_deflate_block_compress_with_dict(
                chunkBuf.baseAddress!,
                chunkBuf.count,
                nil,
                0,
                outWithoutDict,
                maxOut,
                6,
                false
            )
        }
        
        XCTAssertGreaterThan(sizeWithDict, 0, "Compressed output with dictionary must be > 0")
        XCTAssertGreaterThan(sizeWithoutDict, 0, "Compressed output without dictionary must be > 0")
        XCTAssertLessThanOrEqual(sizeWithDict, sizeWithoutDict, "Cross-block dictionary must achieve equal or smaller size due to preheated LZ77 history")
    }
    
    // MARK: - 2. Multi-Block Extreme Archive Roundtrip & System Oracle Consensus
    
    func testMultiBlockArchiveRoundtripAgainstSystemUnzip() async throws {
        // Generate 4MB test file with repetitive block cross patterns
        let sampleFile = sandboxDir.appendingPathComponent("multi_block_sample.bin")
        var testData = Data()
        let sentence = "HighPerformanceParallelDeflateAppleSiliconMSeriesEngine2026 "
        let sentenceData = sentence.data(using: .utf8)!
        let targetSize = TestBenchmarkTier.isBenchmarkMode ? (4 * 1024 * 1024) : (1024 * 1024)
        let blockSize = TestBenchmarkTier.isBenchmarkMode ? 524288 : 131072
        while testData.count < targetSize {
            testData.append(sentenceData)
        }
        try testData.write(to: sampleFile)
        
        let originalSHA256 = SHA256.hash(data: testData).map { String(format: "%02x", $0) }.joined()
        
        let archivePath = sandboxDir.appendingPathComponent("output_dict.zip").path
        let success = try ZipExtremeBlockWriter.shared.createExtremeArchive(
            outputPath: archivePath,
            inputPath: sampleFile.path,
            level: .normal,
            blockSize: blockSize // 8 multi-blocks
        )
        XCTAssertTrue(success, "ZipExtremeBlockWriter must successfully compress 4MB multi-block file")
        
        // Verify with system /usr/bin/unzip oracle
        let extractDir = sandboxDir.appendingPathComponent("extracted_system")
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
        
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        proc.arguments = ["-q", archivePath, "-d", extractDir.path]
        try proc.run()
        proc.waitUntilExit()
        XCTAssertEqual(proc.terminationStatus, 0, "/usr/bin/unzip must successfully extract multi-block dictionary archive")
        
        let extractedFile = extractDir.appendingPathComponent("multi_block_sample.bin")
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedFile.path), "Extracted file must exist")
        
        let extractedData = try Data(contentsOf: extractedFile)
        let extractedSHA256 = SHA256.hash(data: extractedData).map { String(format: "%02x", $0) }.joined()
        
        XCTAssertEqual(extractedSHA256, originalSHA256, "Extracted file SHA-256 must match 100% bit-exact with original")
    }
}
