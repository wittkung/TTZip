// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import Foundation
@testable import TTZipCore

final class ZipExtremeBlockWriterTests: XCTestCase {
    
    func testExtremeBlockWriterIntegrityAndSystemUnzip() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ttzip_extreme_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let samplePath = tempDir.appendingPathComponent("sample_10mb.txt").path
        let sampleSize = 10 * 1024 * 1024
        var sampleData = Data(capacity: sampleSize)
        let pattern = "TTZip Apple Silicon Extreme Speed Multi-Core Block Parallel Compression 2026\n".data(using: .utf8)!
        while sampleData.count < sampleSize {
            sampleData.append(pattern)
        }
        sampleData = sampleData.prefix(sampleSize)
        try sampleData.write(to: URL(fileURLWithPath: samplePath))
        
        let outZipPath = tempDir.appendingPathComponent("extreme_test.zip").path
        
        let t0 = mach_absolute_time()
        let success = try ZipExtremeBlockWriter.shared.createExtremeArchive(
            outputPath: outZipPath,
            inputPath: samplePath,
            level: .fast,
            blockSize: 512 * 1024
        )
        let t1 = mach_absolute_time()
        XCTAssertTrue(success)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outZipPath))
        
        var timebase = mach_timebase_info()
        mach_timebase_info(&timebase)
        let elapsedSec = Double(t1 - t0) * Double(timebase.numer) / Double(timebase.denom) / 1_000_000_000.0
        let mbPerSec = (Double(sampleSize) / (1024 * 1024)) / elapsedSec
        _ = mbPerSec
        
        // Decompress and verify byte-exact match
        let procUnzip = Process()
        procUnzip.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        procUnzip.arguments = ["-p", outZipPath]
        let pipeOut = Pipe()
        procUnzip.standardOutput = pipeOut
        try procUnzip.run()
        let decompressedData = pipeOut.fileHandleForReading.readDataToEndOfFile()
        procUnzip.waitUntilExit()


        
        XCTAssertEqual(decompressedData.count, sampleData.count, "Decompressed data size must match original exactly")
        XCTAssertEqual(decompressedData, sampleData, "Decompressed data must be byte-for-byte identical")
        
        // System unzip -t verification
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        proc.arguments = ["-t", outZipPath]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        try proc.run()
        proc.waitUntilExit()
        
        let outData = pipe.fileHandleForReading.readDataToEndOfFile()
        let outStr = String(data: outData, encoding: .utf8) ?? ""
        XCTAssertEqual(proc.terminationStatus, 0, "System unzip verification failed: \(outStr)")
    }
    
    func testExtremeBlockWriterOnEnwik8() throws {
        let enwik8Path = "/Users/kevintung/Library/Caches/com.ttzip.tests/fixtures/enwik8.xml"
        guard FileManager.default.fileExists(atPath: enwik8Path) else { return }
        let realSamplePath = enwik8Path
        
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ttzip_extreme_enwik8_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let outZipPath = tempDir.appendingPathComponent("enwik8_extreme.zip").path
        
        let t0 = mach_absolute_time()
        let success = try ZipExtremeBlockWriter.shared.createExtremeArchive(
            outputPath: outZipPath,
            inputPath: realSamplePath,
            level: .fast,
            blockSize: 512 * 1024
        )
        let t1 = mach_absolute_time()


        XCTAssertTrue(success)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outZipPath))
        
        var timebase = mach_timebase_info()
        mach_timebase_info(&timebase)
        let elapsedSec = Double(t1 - t0) * Double(timebase.numer) / Double(timebase.denom) / 1_000_000_000.0
        let origSize = (try? FileManager.default.attributesOfItem(atPath: realSamplePath)[.size] as? Int) ?? (100 * 1024 * 1024)
        let outSize = (try? FileManager.default.attributesOfItem(atPath: outZipPath)[.size] as? Int) ?? 0
        let mbPerSec = (Double(origSize) / (1024 * 1024)) / elapsedSec
        let spaceSavings = (1.0 - Double(outSize) / Double(origSize)) * 100.0
        
        _ = mbPerSec
        _ = spaceSavings
        
        XCTAssertGreaterThan(outSize, 0)
        XCTAssertLessThan(outSize, origSize)
        
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        proc.arguments = ["-t", outZipPath]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        try proc.run()
        proc.waitUntilExit()
        let outData = pipe.fileHandleForReading.readDataToEndOfFile()
        let outStr = String(data: outData, encoding: .utf8) ?? ""
        XCTAssertEqual(proc.terminationStatus, 0, "System unzip verification failed: \(outStr)")
    }



    func testZopfliTier6AndTier7CompressionAndSystemUnzip() throws {

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ttzip_zopfli_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let samplePath = tempDir.appendingPathComponent("sample_zopfli.txt").path
        let sampleSize = TestBenchmarkTier.isBenchmarkMode ? (1024 * 1024) : (64 * 1024)
        var sampleData = Data(capacity: sampleSize)
        let pattern = "Google Zopfli Algorithm Deep Architecture Analysis & Multi-Pass Squeeze DP in TTZip 2026\n".data(using: .utf8)!
        while sampleData.count < sampleSize {
            sampleData.append(pattern)
        }
        sampleData = sampleData.prefix(sampleSize)
        try sampleData.write(to: URL(fileURLWithPath: samplePath))
        
        // Test Tier 6 (Ultra Zopfli)
        let outZip6 = tempDir.appendingPathComponent("zopfli_tier6.zip").path
        let ok6 = try ZipExtremeBlockWriter.shared.createExtremeArchive(
            outputPath: outZip6,
            inputPath: samplePath,
            profile: .ultraZopfli,
            blockSize: 256 * 1024
        )
        XCTAssertTrue(ok6)
        
        let proc6 = Process()
        proc6.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        proc6.arguments = ["-t", outZip6]
        let pipe6 = Pipe()
        proc6.standardOutput = pipe6
        proc6.standardError = pipe6
        try proc6.run()
        proc6.waitUntilExit()
        let outData6 = pipe6.fileHandleForReading.readDataToEndOfFile()
        let outStr6 = String(data: outData6, encoding: .utf8) ?? ""
        XCTAssertEqual(proc6.terminationStatus, 0, "System unzip verification failed on Tier 6 Zopfli: \(outStr6)")
        
        // Test Tier 7 (Extreme Peak)
        let outZip7 = tempDir.appendingPathComponent("zopfli_tier7.zip").path
        let ok7 = try ZipExtremeBlockWriter.shared.createExtremeArchive(
            outputPath: outZip7,
            inputPath: samplePath,
            profile: .extremePeak,
            blockSize: 256 * 1024
        )
        XCTAssertTrue(ok7)
        
        let proc7 = Process()
        proc7.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        proc7.arguments = ["-t", outZip7]
        let pipe7 = Pipe()
        proc7.standardOutput = pipe7
        proc7.standardError = pipe7
        try proc7.run()
        proc7.waitUntilExit()
        let outData7 = pipe7.fileHandleForReading.readDataToEndOfFile()
        let outStr7 = String(data: outData7, encoding: .utf8) ?? ""
        XCTAssertEqual(proc7.terminationStatus, 0, "System unzip verification failed on Tier 7 Zopfli: \(outStr7)")
    }
}
