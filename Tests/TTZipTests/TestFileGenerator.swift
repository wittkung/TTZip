// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CryptoKit
@testable import TTZipCore

/// Utility generator creating realistic file fixtures and synthetic payloads for test suites.
public enum TestFileGenerator {
    
    /// Generates a batch of small dummy data files within the specified directory.
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
    
    /// Generates a large payload file using streamed 1MB chunks to prevent memory exhaustion.
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

    /// Generates a realistic structured text log file with the given number of log lines.
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
    
    /// Generates an AES-GCM encrypted payload file using Apple CryptoKit.
    public static func createHugeEncryptedFile(at targetURL: URL, sizeInMB: Int) throws {
        let parentDir = targetURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        
        let rawData = Data(repeating: 0x55, count: sizeInMB * 1024 * 1024)
        let key = SymmetricKey(size: .bits256)
        let sealedBox = try AES.GCM.seal(rawData, using: key)
        guard let combinedData = sealedBox.combined else { return }
        try combinedData.write(to: targetURL)
    }
    
    /// Instantly allocates a sparse/dense huge file on macOS using `/usr/sbin/mkfile`.
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

/// Formatted diagnostic test logger dispatching structured test summaries through TTLogger.
public enum TTZipTestLogger {
    
    /// Emits a structured section header banner for a test suite.
    public static func logHeader(_ title: String) {
        TTLogger.debug("\n================================================================================")
        TTLogger.debug("  📊 [TTZip Test Suite] \(title)")
        TTLogger.debug("================================================================================")
    }

    /// Emits a structured row of performance metrics for an archive compression/decompression benchmark.
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
        TTLogger.debug("  [▶ \(format)] Payload: \(pMB) MB | Archive: \(cMB) MB (\(rP)%) | Codec: \(cSpd) / \(dSpd) MB/s | Elapsed: \(el) s -> \(status)")
    }

    /// Emits a formatted test suite completion summary.
    public static func logSuiteSummary(suiteName: String, totalTests: Int, passed: Int, failed: Int, duration: Double) {
        TTLogger.debug("--------------------------------------------------------------------------------")
        TTLogger.debug("  ✅ Test Suite [\(suiteName)] Completed: \(totalTests) tests | \(passed) passed | \(failed) failed | Total time: \(String(format: "%.3f", duration)) s")
        TTLogger.debug("--------------------------------------------------------------------------------\n")
    }
}
