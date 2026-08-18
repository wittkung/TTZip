// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import CryptoKit
@testable import TTZipCore

final class SplitVolumeSpanningTests: XCTestCase {
    
    private var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("ttzip_split_test_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }
    
    func testMultiVolumeStreamSinkBoundaryRollover() throws {
        let baseOutputPath = tempDirectory.appendingPathComponent("test_archive.7z").path
        let volumeSize: Int64 = 65536 // 64 KB per volume
        
        let sink = try MultiVolumeStreamSink(
            baseOutputPath: baseOutputPath,
            volumeSizeBytes: volumeSize,
            namingPattern: .numberedExtension
        )
        
        // Write 200 KB total (should generate 4 volumes: 64KB, 64KB, 64KB, 8KB)
        let payloadSize = 204800
        var payload = Data(count: payloadSize)
        for i in 0..<payloadSize {
            payload[i] = UInt8(i & 0xFF)
        }
        
        try sink.write(data: payload)
        let generatedVolumes = try sink.close()
        
        XCTAssertEqual(generatedVolumes.count, 4)
        XCTAssertEqual(sink.totalBytes, Int64(payloadSize))
        
        let fm = FileManager.default
        XCTAssertTrue(fm.fileExists(atPath: "\(baseOutputPath).001"))
        XCTAssertTrue(fm.fileExists(atPath: "\(baseOutputPath).002"))
        XCTAssertTrue(fm.fileExists(atPath: "\(baseOutputPath).003"))
        XCTAssertTrue(fm.fileExists(atPath: "\(baseOutputPath).004"))
        
        let size1 = try fm.attributesOfItem(atPath: "\(baseOutputPath).001")[.size] as? Int64 ?? 0
        let size2 = try fm.attributesOfItem(atPath: "\(baseOutputPath).002")[.size] as? Int64 ?? 0
        let size3 = try fm.attributesOfItem(atPath: "\(baseOutputPath).003")[.size] as? Int64 ?? 0
        let size4 = try fm.attributesOfItem(atPath: "\(baseOutputPath).004")[.size] as? Int64 ?? 0
        
        XCTAssertEqual(size1, 65536)
        XCTAssertEqual(size2, 65536)
        XCTAssertEqual(size3, 65536)
        XCTAssertEqual(size4, Int64(payloadSize - 3 * 65536))
    }
    
    func testNativeParallelEncryptedSplitEngineCreation() async throws {
        let sourceFile = tempDirectory.appendingPathComponent("payload.bin")
        let testData = Data(repeating: 0x42, count: 150000) // 150 KB
        try testData.write(to: sourceFile)
        
        let engine = NativeParallelEncryptedSplitEngine()
        let volumes = try await engine.createStandardEncryptedSplitVolume(
            format: .sevenZip,
            sourcePaths: [sourceFile.path],
            outputDir: tempDirectory.path,
            baseName: "MyEncryptedSet",
            splitVolumeSizeBytes: 65536,
            password: "TestPassword123"
        )
        
        XCTAssertFalse(volumes.isEmpty)
        XCTAssertTrue(volumes.allSatisfy { FileManager.default.fileExists(atPath: $0) })
    }
}
