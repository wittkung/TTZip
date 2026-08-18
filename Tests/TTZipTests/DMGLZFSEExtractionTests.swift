// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore
import CTTZipBridge

final class DMGLZFSEExtractionTests: XCTestCase {
    
    private var tempDir: URL!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DMGLZFSETests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }
    
    override func tearDownWithError() throws {
        if let dir = tempDir {
            try? FileManager.default.removeItem(at: dir)
        }
        try super.tearDownWithError()
    }
    
    // MARK: - 1. LZFSE Buffer & Stream Codec Tests
    
    func testLZFSEBufferRoundtrip() throws {
        let adapter = LzfseCAdapter.shared
        XCTAssertTrue(adapter.isAvailable)
        
        let sizes = [64, 1024, 65536, 524288]
        for size in sizes {
            var original = [UInt8](repeating: 0, count: size)
            for i in 0..<size {
                original[i] = UInt8((i * 37 + 13) % 256)
            }
            
            let compCap = size + 65536
            var compressed = [UInt8](repeating: 0, count: compCap)
            var decompressed = [UInt8](repeating: 0, count: size)
            
            let compSize = adapter.compress(
                src: original,
                srcLength: size,
                dst: &compressed,
                dstCapacity: compCap
            )
            XCTAssertGreaterThan(compSize, 0, "Compression failed for size \(size)")
            
            let decompSize = adapter.decompress(
                src: compressed,
                srcLength: compSize,
                dst: &decompressed,
                dstCapacity: size
            )
            XCTAssertEqual(decompSize, size, "Decompressed size mismatch for size \(size)")
            XCTAssertEqual(original, decompressed, "Content mismatch for size \(size)")
        }
    }
    
    func testSingleFileLZFSEStreamRoundtrip() throws {
        let adapter = LzfseCAdapter.shared
        let srcFile = tempDir.appendingPathComponent("sample_text.txt")
        let lzfseFile = tempDir.appendingPathComponent("sample_text.txt.lzfse")
        let restoredFile = tempDir.appendingPathComponent("restored_text.txt")
        
        let testString = String(repeating: "Apple LZFSE Native High Performance Engine in TTZip. ", count: 2000)
        try testString.write(to: srcFile, atomically: true, encoding: .utf8)
        
        let compStatus = adapter.compressFileStream(srcPath: srcFile.path, dstPath: lzfseFile.path)
        XCTAssertEqual(compStatus, 0, "compressFileStream failed")
        XCTAssertTrue(FileManager.default.fileExists(atPath: lzfseFile.path))
        
        let decompStatus = adapter.decompressFileStream(srcPath: lzfseFile.path, dstPath: restoredFile.path)
        XCTAssertEqual(decompStatus, 0, "decompressFileStream failed")
        XCTAssertTrue(FileManager.default.fileExists(atPath: restoredFile.path))
        
        let restoredString = try String(contentsOf: restoredFile, encoding: .utf8)
        XCTAssertEqual(testString, restoredString)
    }
    
    // MARK: - 2. Apple UDIF DMG Header & koly Probe Tests
    
    func testDMGUDIFKolyProbeAndParse() throws {
        let dmgPath = tempDir.appendingPathComponent("test_image.dmg").path
        
        // Construct a synthetic 1024-byte file with a valid 512-byte koly trailer at the end
        var fileData = [UInt8](repeating: 0, count: 1024)
        
        // koly magic 'koly' = 0x6B6F6C79 in Big Endian at EOF-512 (index 512)
        fileData[512] = 0x6B
        fileData[513] = 0x6F
        fileData[514] = 0x6C
        fileData[515] = 0x79
        
        // Version = 4 (Big Endian at offset 516)
        fileData[516] = 0x00
        fileData[517] = 0x00
        fileData[518] = 0x00
        fileData[519] = 0x04
        
        // HeaderSize = 512 (0x0200 at offset 520)
        fileData[520] = 0x00
        fileData[521] = 0x00
        fileData[522] = 0x02
        fileData[523] = 0x00
        
        // SectorCount = 2048 (0x0000000000000800 at offset 1004)
        fileData[1004] = 0x00
        fileData[1005] = 0x00
        fileData[1006] = 0x00
        fileData[1007] = 0x00
        fileData[1008] = 0x00
        fileData[1009] = 0x00
        fileData[1010] = 0x08
        fileData[1011] = 0x00
        
        try Data(fileData).write(to: URL(fileURLWithPath: dmgPath))
        
        // Test probe
        XCTAssertTrue(DMGVirtualStreamAdapter.shared.isUDIFDmg(at: dmgPath))
        
        // Test read koly
        var koly = ttzip_udif_koly_t()
        let status = ttzip_dmg_read_koly(dmgPath, &koly)
        XCTAssertEqual(status, 0)
        XCTAssertEqual(koly.signature, TTZIP_DMG_KOLY_MAGIC)
        XCTAssertEqual(koly.version, 4)
        XCTAssertEqual(koly.header_size, 512)
        XCTAssertEqual(koly.sector_count, 2048)
    }
}
