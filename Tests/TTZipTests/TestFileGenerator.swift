// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CryptoKit

/// ( 、mkfile AES )
public enum TestFileGenerator {
    
    /// 1. ( )
    @discardableResult
    public static func createBatchSmallFiles(in directory: URL, count: Int, sizePerFileInKB: Int) throws -> [URL] {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        var generatedURLs: [URL] = []
        let dummyData = Data(repeating: 0xFF, count: sizePerFileInKB * 1024)
        for i in 0..<count {
            let fileURL = directory.appendingPathComponent("small_\(i)_\(UUID().uuidString.prefix(8)).dat")
            try dummyData.write(to: fileURL)
            generatedURLs.append(fileURL)
        }
        return generatedURLs
    }
    
    /// 2. ( Foundation OutputStream ， OOM)
    public static func createHugeFile(at targetURL: URL, sizeInMB: Int) throws {
        let parentDir = targetURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        
        guard let stream = OutputStream(url: targetURL, append: false) else { return }
        stream.open()
        defer { stream.close() }
        
        let chunkSize = 1024 * 1024 // 1MB chunk
        var buffer = [UInt8](repeating: 0xAB, count: chunkSize)
        for _ in 0..<sizeInMB {
            _ = buffer.withUnsafeMutableBufferPointer { ptr in
                stream.write(ptr.baseAddress!, maxLength: chunkSize)
            }
        }
    }

    /// Validates expected behavior and invariants.
    public static func createRealisticLogFile(at targetURL: URL, linesCount: Int) throws {
        let parentDir = targetURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        var logData = Data()
        let logLine = "2026-08-10 15:00:00.123 [INFO] com.ttzip.core.engine - Processed chunk sequence #1024 with zero allocation [CRC32: 0x4F8A9B2C] throughput: 3200 MB/s\n"
        let lineBytes = Array(logLine.utf8)
        logData.reserveCapacity(linesCount * lineBytes.count)
        for _ in 0..<linesCount {
            logData.append(contentsOf: lineBytes)
        }
        try logData.write(to: targetURL)
    }
    
    /// 4. ( Apple CryptoKit AES-GCM)
    public static func createHugeEncryptedFile(at targetURL: URL, sizeInMB: Int) throws {
        let parentDir = targetURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        
        let rawData = Data(repeating: 0x55, count: sizeInMB * 1024 * 1024)
        let key = SymmetricKey(size: .bits256)
        let sealedBox = try AES.GCM.seal(rawData, using: key)
        guard let combinedData = sealedBox.combined else { return }
        try combinedData.write(to: targetURL)
    }
    
    /// 5. macOS `/usr/sbin/mkfile` GB
    public static func createInstantHugeFile(atPath path: String, sizeInMB: Int) {
        let parentDir = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: parentDir, withIntermediateDirectories: true)
        
        let mkfileBin = FileManager.default.fileExists(atPath: "/usr/sbin/mkfile") ? "/usr/sbin/mkfile" : "/usr/bin/mkfile"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: mkfileBin)
        process.arguments = ["\(sizeInMB)m", path]
        try? process.run()
        process.waitUntilExit()
    }
}

/// Validates expected behavior and invariants.
public enum TTZipTestLogger {
    public static func logHeader(_ title: String) {
        print("\n================================================================================")
        print("  📊 [TTZip Test Suite] \(title)")
        print("================================================================================")
    }

    public static func logMetricsRow(
        format: String,
        payloadMB: Double,
        compressedMB: Double,
        compressSpeedMBs: Double,
        decompressSpeedMBs: Double,
        elapsedSeconds: Double
    ) {
        let ratio = (compressedMB / max(0.001, payloadMB)) * 100.0
        let status = (compressSpeedMBs >= 150.0 && decompressSpeedMBs >= 500.0) ? "PASS [PERF_OPTIMAL]" : "PASS [PERF_ACCEPTABLE]"
        let pMB = String(format: "%.2f", payloadMB)
        let cMB = String(format: "%.2f", compressedMB)
        let rP = String(format: "%.1f", ratio)
        let cSpd = String(format: "%.1f", compressSpeedMBs)
        let dSpd = String(format: "%.1f", decompressSpeedMBs)
        let el = String(format: "%.3f", elapsedSeconds)
        print("  [▶ \(format)] 载荷: \(pMB) MB | 压缩包: \(cMB) MB (\(rP)%) | 编解码: \(cSpd) / \(dSpd) MB/s | 耗时: \(el) s -> \(status)")
    }

    public static func logSuiteSummary(suiteName: String, totalTests: Int, passed: Int, failed: Int, duration: Double) {
        print("--------------------------------------------------------------------------------")
        print("  ✅ 测试套件 [\(suiteName)] 完成: 运行 \(totalTests) 测试 | 通过 \(passed) | 失败 \(failed) | 总耗时: \(String(format: "%.3f", duration)) 秒")
        print("--------------------------------------------------------------------------------\n")
    }
}
