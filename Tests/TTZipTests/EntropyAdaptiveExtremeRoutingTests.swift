// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore
import CTTZipBridge

final class EntropyAdaptiveExtremeRoutingTests: XCTestCase {
    
    func testEntropyProbeLowEntropy() throws {
        // 纯重复低熵文本
        let text = String(repeating: "<xml><tag id=\"item_12345\">Hello World Dynamic Compress</tag></xml>\n", count: 100)
        let data = text.data(using: .utf8)!
        
        var entropy: Double = 0.0
        var ratio: Double = 1.0
        let method = data.withUnsafeBytes { ptr -> Int32 in
            ttzip_probe_entropy_and_compressibility(ptr.baseAddress!, data.count, 4096, &entropy, &ratio)
        }
        
        print("📊 低熵测试: Entropy = \(String(format: "%.3f", entropy)) bits/byte, Method = \(method), Ratio = \(ratio)")
        XCTAssertEqual(method, 8, "低熵数据必须路由至 Deflate (Method 8)")
        XCTAssertLessThan(entropy, 6.0, "重复 XML 文本信息熵必须 < 6.0 bits/byte")
    }
    
    func testEntropyProbeHighEntropy() throws {
        // 高熵随机噪声 / 伪不可压缩数据
        var randomBytes = [UInt8](repeating: 0, count: 65536)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        let data = Data(randomBytes)
        
        var entropy: Double = 0.0
        var ratio: Double = 1.0
        let method = data.withUnsafeBytes { ptr -> Int32 in
            ttzip_probe_entropy_and_compressibility(ptr.baseAddress!, data.count, 4096, &entropy, &ratio)
        }
        
        print("📊 高熵测试: Entropy = \(String(format: "%.3f", entropy)) bits/byte, Method = \(method), Ratio = \(ratio)")
        XCTAssertEqual(method, 0, "高熵随机数据必须智能路由至 Direct Store (Method 0)")
        XCTAssertGreaterThanOrEqual(entropy, 7.5, "随机噪声信息熵必须 >= 7.5 bits/byte")
    }
    
    func testExtremeBlockWriterLowEntropyPipeline() async throws {
        let tempDir = NSTemporaryDirectory() + "entropy_test_\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }
        
        let textFile = (tempDir as NSString).appendingPathComponent("large_text.xml")
        let text = String(repeating: "<article id=\"wiki_001\"><title>Swift 6.0 Concurrency</title><content>High performance native engine</content></article>\n", count: 30000)
        try text.data(using: .utf8)!.write(to: URL(fileURLWithPath: textFile))
        
        let outZip = (tempDir as NSString).appendingPathComponent("low_entropy_out.zip")
        let success = try ZipExtremeBlockWriter.shared.createExtremeArchive(
            outputPath: outZip,
            inputPath: textFile,
            level: .fastest,
            blockSize: 512 * 1024
        )
        XCTAssertTrue(success)
        
        // 校验体积与系统原生解压
        let originalSize = try FileManager.default.attributesOfItem(atPath: textFile)[.size] as! Int64
        let zipSize = try FileManager.default.attributesOfItem(atPath: outZip)[.size] as! Int64
        XCTAssertLessThan(zipSize, originalSize / 5, "低熵数据在 Deflate 极速模式下必须获得 >5x 压缩比")
        
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        p.arguments = ["-t", outZip]
        try p.run()
        p.waitUntilExit()
        XCTAssertEqual(p.terminationStatus, 0, "系统 unzip 必须 100% 校验通过")
    }
    
    func testExtremeBlockWriterHighEntropyStorePipeline() async throws {
        let tempDir = NSTemporaryDirectory() + "entropy_test_high_\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }
        
        let randomFile = (tempDir as NSString).appendingPathComponent("random_payload.bin")
        var randomBytes = [UInt8](repeating: 0, count: 5 * 1024 * 1024) // 5MB
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        try Data(randomBytes).write(to: URL(fileURLWithPath: randomFile))
        
        let outZip = (tempDir as NSString).appendingPathComponent("high_entropy_out.zip")
        
        let start = mach_absolute_time()
        let success = try ZipExtremeBlockWriter.shared.createExtremeArchive(
            outputPath: outZip,
            inputPath: randomFile,
            level: .fastest,
            blockSize: 512 * 1024
        )
        let elapsed = Double(mach_absolute_time() - start) * 1e-9
        XCTAssertTrue(success)
        
        let speedMBs = 5.0 / max(0.0001, elapsed)
        print("⚡️ 高熵智能 Direct Store 吞吐量: \(String(format: "%.1f", speedMBs)) MB/s")
        
        // 校验系统原生解压
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        p.arguments = ["-t", outZip]
        try p.run()
        p.waitUntilExit()
        XCTAssertEqual(p.terminationStatus, 0, "高熵 Store 模式必须 100% 通过系统原生解压校验")
    }
}
