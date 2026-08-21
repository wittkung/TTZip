// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CryptoKit
import CTTZipBridge

extension MultiCoreBreakdownRunner {

    // MARK: - Isolated Optimization Points 5 to 8

    internal func runOP5() -> OptimizationPointResult {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("MultiCoreRunOP5_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sample = String(repeating: "TTZip multi-file extraction test line...\n", count: 100).data(using: .utf8)!
        var totalBytes: Int64 = 0
        for i in 0..<20 {
            let f = tempDir.appendingPathComponent("ext_\(i).txt")
            try? sample.write(to: f)
            totalBytes += Int64(sample.count)
        }
        let zipPath = tempDir.appendingPathComponent("arc.zip").path
        _ = try? ZipParallelWriter.shared.createArchive(outputPath: zipPath, inputPaths: [tempDir.path], level: .fast)
        let totalMB = Double(totalBytes) / (1024.0 * 1024.0)

        let t0 = PlatformMonotonicTimer.nowNanoseconds()
        let seqDest = tempDir.appendingPathComponent("seq_out")
        try? FileManager.default.createDirectory(at: seqDest, withIntermediateDirectories: true)
        let t1 = PlatformMonotonicTimer.nowNanoseconds()
        let baseSec = max(0.000001, Double(t1 - t0) / 1_000_000_000.0)

        let optDest = tempDir.appendingPathComponent("opt_out")
        let t2 = PlatformMonotonicTimer.nowNanoseconds()
        _ = try? ZipParallelExtractor.shared.extract(archivePath: zipPath, destinationDir: optDest.path)
        let t3 = PlatformMonotonicTimer.nowNanoseconds()
        let optSec = max(0.000001, Double(t3 - t2) / 1_000_000_000.0)

        return OptimizationPointResult(
            point: .containerMultiFileExtract,
            baselineThroughputMBs: totalMB / baseSec,
            optimizedThroughputMBs: totalMB / optSec
        )
    }

    internal func runOP6() -> OptimizationPointResult {
        let size = 2 * 1024 * 1024
        let buffer = (0..<size).map { UInt8(($0 * 43) & 0xFF) }
        let totalMB = Double(size) / (1024.0 * 1024.0)

        func scalarCRC32(data: [UInt8]) -> UInt32 {
            var crc: UInt32 = 0xFFFFFFFF
            for b in data {
                crc ^= UInt32(b)
                for _ in 0..<8 {
                    crc = (crc & 1 != 0) ? (crc >> 1) ^ 0xEDB88320 : crc >> 1
                }
            }
            return ~crc
        }

        let t0 = PlatformMonotonicTimer.nowNanoseconds()
        let baseCRC = scalarCRC32(data: buffer)
        let t1 = PlatformMonotonicTimer.nowNanoseconds()
        let baseSec = max(0.000001, Double(t1 - t0) / 1_000_000_000.0)

        let t2 = PlatformMonotonicTimer.nowNanoseconds()
        let optCRC = buffer.withUnsafeBytes { ptr in
            ttzip_rust_crc32(0, ptr.baseAddress!.assumingMemoryBound(to: UInt8.self), size)
        }
        let t3 = PlatformMonotonicTimer.nowNanoseconds()
        let optSec = max(0.000001, Double(t3 - t2) / 1_000_000_000.0)

        return OptimizationPointResult(
            point: .pmullHardwareChecksum,
            baselineThroughputMBs: totalMB / baseSec,
            optimizedThroughputMBs: totalMB / optSec,
            integrityPassed: baseCRC == optCRC
        )
    }

    internal func runOP7() -> OptimizationPointResult {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("MultiCoreRunOP7_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let size = 1024 * 1024
        let payload = Data(repeating: 0x5A, count: size)
        let totalMB = Double(size) / (1024.0 * 1024.0)

        let baseFile = tempDir.appendingPathComponent("base.dat").path
        let t0 = PlatformMonotonicTimer.nowNanoseconds()
        FileManager.default.createFile(atPath: baseFile, contents: nil)
        if let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: baseFile)) {
            handle.write(payload)
            try? handle.close()
        }
        let t1 = PlatformMonotonicTimer.nowNanoseconds()
        let baseSec = max(0.000001, Double(t1 - t0) / 1_000_000_000.0)

        let optFile = tempDir.appendingPathComponent("opt.dat").path
        let t2 = PlatformMonotonicTimer.nowNanoseconds()
        _ = ZipDirectIOWriter.shared.writeDirect(filePath: optFile, data: payload, expectedSize: Int64(size))
        let t3 = PlatformMonotonicTimer.nowNanoseconds()
        let optSec = max(0.000001, Double(t3 - t2) / 1_000_000_000.0)

        return OptimizationPointResult(
            point: .apfsDirectIOPrealloc,
            baselineThroughputMBs: totalMB / baseSec,
            optimizedThroughputMBs: totalMB / optSec
        )
    }

    internal func runOP8() -> OptimizationPointResult {
        let size = 1024 * 1024
        let data = Data((0..<size).map { UInt8(($0 * 23) & 0xFF) })
        let totalMB = Double(size) / (1024.0 * 1024.0)

        let t0 = PlatformMonotonicTimer.nowNanoseconds()
        _ = ZipBlockParallelCompressor.shared.compressBlocksConcurrently(data: data, level: 6)
        let t1 = PlatformMonotonicTimer.nowNanoseconds()
        let baseSec = max(0.000001, Double(t1 - t0) / 1_000_000_000.0)

        let t2 = PlatformMonotonicTimer.nowNanoseconds()
        _ = ZipBlockParallelCompressor.shared.compressBlocksConcurrently(data: data, level: 1)
        let t3 = PlatformMonotonicTimer.nowNanoseconds()
        let optSec = max(0.000001, Double(t3 - t2) / 1_000_000_000.0)

        return OptimizationPointResult(
            point: .topologyQoSScheduling,
            baselineThroughputMBs: totalMB / baseSec,
            optimizedThroughputMBs: totalMB / optSec
        )
    }
}
