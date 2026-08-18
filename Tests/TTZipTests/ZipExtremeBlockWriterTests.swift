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
        
        // 1. 生成 10MB 测试样本 (具有真实重复模式与文本)
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
        
        // 2. 使用 ZipExtremeBlockWriter 进行 18 核极速多块压缩 (1MB 分块)
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
        print("⚡️ [ZipExtremeBlockWriter] 10MB 耗时: \(String(format: "%.4f", elapsedSec)) s | 吞吐: \(String(format: "%.1f", mbPerSec)) MB/s")
        
        // 3. 使用系统 unzip -p 解压并与原始数据做逐字节 diff
        let procUnzip = Process()
        procUnzip.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        procUnzip.arguments = ["-p", outZipPath]
        let pipeOut = Pipe()
        procUnzip.standardOutput = pipeOut
        try procUnzip.run()
        let decompressedData = pipeOut.fileHandleForReading.readDataToEndOfFile()
        procUnzip.waitUntilExit()
        
        print("📊 原始数据长度: \(sampleData.count) 字节 | 解压后长度: \(decompressedData.count) 字节")
        if decompressedData.count != sampleData.count {
            print("❌ 长度不一致！差异: \(decompressedData.count - sampleData.count)")
        } else {
            var diffCount = 0
            for i in 0..<sampleData.count {
                if sampleData[i] != decompressedData[i] {
                    if diffCount < 10 {
                        print("❌ 第 \(i) 字节不一致: 原始 0x\(String(format: "%02X", sampleData[i])) vs 解压 0x\(String(format: "%02X", decompressedData[i]))")
                    }
                    diffCount += 1
                }
            }
            print("🔍 总不一致字节数: \(diffCount)")
        }
        
        // 4. 系统原生 /usr/bin/unzip -t 验证
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
        print("🔍 [/usr/bin/unzip -t]:\n\(outStr)")
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
        let sampleSize = try FileManager.default.attributesOfItem(atPath: realSamplePath)[.size] as? Int64 ?? 0
        
        let t0 = mach_absolute_time()
        let success = try ZipExtremeBlockWriter.shared.createExtremeArchive(
            outputPath: outZipPath,
            inputPath: realSamplePath,
            level: .fast,
            blockSize: 1024 * 1024
        )
        let t1 = mach_absolute_time()
        XCTAssertTrue(success)
        
        var timebase = mach_timebase_info()
        mach_timebase_info(&timebase)
        let elapsedSec = Double(t1 - t0) * Double(timebase.numer) / Double(timebase.denom) / 1_000_000_000.0
        let mbPerSec = (Double(sampleSize) / (1024 * 1024)) / elapsedSec
        let zipSize = try FileManager.default.attributesOfItem(atPath: outZipPath)[.size] as? Int64 ?? 0
        let savings = (1.0 - Double(zipSize) / Double(sampleSize)) * 100.0
        
        print("🔥 [TTZip Extreme on enwik8] 100MB 耗时: \(String(format: "%.4f", elapsedSec)) s | 吞吐: \(String(format: "%.1f", mbPerSec)) MB/s | 空间节省: \(String(format: "%.1f", savings))% | 压缩体积: \(zipSize) 字节")
        
        // 校验 /usr/bin/unzip -t
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        proc.arguments = ["-t", outZipPath]
        let pipe = Pipe()
        proc.standardOutput = pipe
        try proc.run()
        proc.waitUntilExit()
        XCTAssertEqual(proc.terminationStatus, 0)
    }
    
    func testZopfliTier6AndTier7CompressionAndSystemUnzip() throws {

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ttzip_zopfli_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let samplePath = tempDir.appendingPathComponent("sample_zopfli.txt").path
        let sampleSize = 1024 * 1024 // 1 MB
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
        print("🔍 Tier 6 unzip -t:\n\(outStr6)")
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
        print("🔍 Tier 7 unzip -t:\n\(outStr7)")
        XCTAssertEqual(proc7.terminationStatus, 0, "System unzip verification failed on Tier 7 Zopfli: \(outStr7)")

    }
}

