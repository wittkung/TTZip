// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import CTTZipBridge
@testable import TTZipCore

/// Test suite validating ARM64 PMULL hardware-accelerated CRC-32 calculation against reference oracles and performance floors.
final class CRC32PmullDifferentialTests: XCTestCase {

    // MARK: - 1. Golden Test Vectors & Differential Oracle Validation

    func testGoldenVectorsAndDifferential() {
        // Standard IEEE 802.3 test vector "123456789" -> 0xCBF43926
        let ascii9 = "123456789".data(using: .utf8)!
        let expectedCRC: UInt32 = 0xCBF43926

        let computedPMULL = ascii9.withUnsafeBytes { raw in
            ttzip_crc32_pmull_wide(0, raw.baseAddress?.assumingMemoryBound(to: UInt8.self), raw.count)
        }
        XCTAssertEqual(computedPMULL, expectedCRC, "CRC32 (PMULL wide) for '123456789' mismatch!")

        let computedSingle = ascii9.withUnsafeBytes { raw in
            ttzip_core_crc32_neon_single(0, raw.baseAddress?.assumingMemoryBound(to: UInt8.self), raw.count)
        }
        XCTAssertEqual(computedSingle, expectedCRC, "CRC32 (Core single) for '123456789' mismatch!")

        let computedScalar = ascii9.withUnsafeBytes { raw in
            ttzip_crc32_scalar(0, raw.baseAddress?.assumingMemoryBound(to: UInt8.self), raw.count)
        }
        XCTAssertEqual(computedScalar, expectedCRC, "CRC32 (Scalar) for '123456789' mismatch!")

        let computedFast = ascii9.withUnsafeBytes { raw in
            ttzip_crc32_fast(0, raw.baseAddress?.assumingMemoryBound(to: UInt8.self), raw.count)
        }
        XCTAssertEqual(computedFast, expectedCRC, "CRC32 (Fast) for '123456789' mismatch!")

        // Empty input test -> initial CRC
        XCTAssertEqual(ttzip_crc32_pmull_wide(0, nil, 0), 0)
        XCTAssertEqual(ttzip_crc32_pmull_wide(0x12345678, nil, 0), 0x12345678)
        XCTAssertEqual(ttzip_core_crc32_neon_single(0x87654321, nil, 0), 0x87654321)
    }

    // MARK: - 2. Exhaustive Length & Alignment Differential Matrix (16,384 Combinations)

    func testExhaustiveLengthAndAlignmentDifferential() {
        let maxLen = 1024
        let maxAlign = 16
        let totalAlloc = maxLen + maxAlign + 64
        var rawMemory = [UInt8](repeating: 0, count: totalAlloc)

        // Seed with deterministic pseudorandom data
        var seed: UInt64 = 0x8542918518928371
        for i in 0..<totalAlloc {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            rawMemory[i] = UInt8(truncatingIfNeeded: seed >> 32)
        }

        rawMemory.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }

            for align in 0..<maxAlign {
                let alignedPtr = base.advanced(by: align)
                for len in 0...maxLen {
                    let initialSeed: UInt32 = UInt32(truncatingIfNeeded: (seed ^ UInt64(len &* 31 + align)))
                    let expected = ttzip_crc32_scalar(initialSeed, alignedPtr, len)
                    let actual = ttzip_crc32_pmull_wide(initialSeed, alignedPtr, len)

                    XCTAssertEqual(
                        actual, expected,
                        "Mismatch at align=\(align), len=\(len)! Expected 0x\(String(expected, radix: 16)), got 0x\(String(actual, radix: 16))"
                    )
                }
            }
        }
    }

    // MARK: - 3. In-Cache Throughput Floor (>= 35 GB/s on Apple Silicon P-Core)

    func testInCacheThroughputFloor() {
        let bufferSize = 64 * 1024 // 64 KB (fits completely in L1 D-Cache)
        var buffer = [UInt8](repeating: 0x5A, count: bufferSize)
        for i in 0..<bufferSize {
            buffer[i] = UInt8(i & 0xFF)
        }

        let iterations = 20_000 // Total 1.28 GB processed

        buffer.withUnsafeBufferPointer { buf in
            guard let ptr = buf.baseAddress else { return }

            // Warmup
            var crc: UInt32 = 0
            for _ in 0..<500 {
                crc = ttzip_core_crc32_neon_single(crc, ptr, bufferSize)
            }

            let start = DispatchTime.now()
            for _ in 0..<iterations {
                crc = ttzip_core_crc32_neon_single(crc, ptr, bufferSize)
            }
            let elapsedSec = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000.0

            let totalBytes = Double(bufferSize * iterations)
            let throughputMBs = (totalBytes / (1024.0 * 1024.0)) / elapsedSec

            print("[BENCH] CRC32 Single-Core In-Cache (64KB) Throughput: \(String(format: "%.1f", throughputMBs)) MB/s (\(String(format: "%.2f", throughputMBs / 1024.0)) GB/s), CRC: 0x\(String(crc, radix: 16))")

            #if arch(arm64)
            XCTAssertGreaterThanOrEqual(
                throughputMBs, 35000.0,
                "In-cache CRC32 throughput \(throughputMBs) MB/s fell below hard floor 35,000 MB/s (35 GB/s)!"
            )
            #endif
        }
    }

    // MARK: - 4. Large Memory Buffer Throughput (>= 15 GB/s)

    func testLargeBufferThroughputFloor() {
        let bufferSize = 20 * 1024 * 1024 // 20 MB buffer
        var buffer = [UInt8](repeating: 0xA5, count: bufferSize)
        for i in 0..<1024 {
            buffer[i] = UInt8(i & 0xFF)
        }

        let iterations = 50 // Total 1.0 GB processed

        buffer.withUnsafeBufferPointer { buf in
            guard let ptr = buf.baseAddress else { return }

            // Warmup
            var crc: UInt32 = 0
            crc = ttzip_core_crc32_neon_single(crc, ptr, bufferSize)

            let start = DispatchTime.now()
            for _ in 0..<iterations {
                crc = ttzip_core_crc32_neon_single(crc, ptr, bufferSize)
            }
            let elapsedSec = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000.0

            let totalBytes = Double(bufferSize * iterations)
            let throughputMBs = (totalBytes / (1024.0 * 1024.0)) / elapsedSec

            print("[BENCH] CRC32 Single-Core Large-Buffer (20MB) Throughput: \(String(format: "%.1f", throughputMBs)) MB/s (\(String(format: "%.2f", throughputMBs / 1024.0)) GB/s), CRC: 0x\(String(crc, radix: 16))")

            #if arch(arm64)
            XCTAssertGreaterThanOrEqual(
                throughputMBs, 15000.0,
                "Large-buffer CRC32 throughput \(throughputMBs) MB/s fell below floor 15,000 MB/s (15 GB/s)!"
            )
            #endif
        }
    }

    // MARK: - 5. Full-Spectrum Size Matrix Benchmark & Zero-Regression Verification

    func testFullSpectrumSizeComparison() {
        let testSizes = [
            1, 4, 8, 15, 16, 31, 32, 63, 64, 127, 128, 191, 192, 256, 512,
            1024, 4096, 16384, 65536, 1048576, 10485760
        ]

        print("\n================ CRC-32 FULL-SPECTRUM SIZE BENCHMARK ================")
        print(String(format: "%-10@ | %-16@ | %-16@ | %-12@ | %-6@", "Size", "Scalar (MB/s)", "PMULL-12 (MB/s)", "Speedup", "Status"))
        print("----------------------------------------------------------------------")

        for size in testSizes {
            var data = [UInt8](repeating: 0, count: size + 64)
            for i in 0..<size {
                data[i] = UInt8((i &* 37 + 19) & 0xFF)
            }

            // Target approx 100MB to 500MB total data processed per size for stable timing
            let iterations: Int
            if size < 64 {
                iterations = 50_000
            } else if size < 1024 {
                iterations = 20_000
            } else if size < 65536 {
                iterations = 2_000
            } else {
                iterations = 50
            }

            data.withUnsafeBufferPointer { buf in
                guard let ptr = buf.baseAddress else { return }

                // 1. Warmup
                var crcScalar: UInt32 = 0
                var crcPmull: UInt32 = 0
                for _ in 0..<min(iterations, 100) {
                    crcScalar = ttzip_crc32_scalar(crcScalar, ptr, size)
                    crcPmull = ttzip_crc32_pmull_wide(crcPmull, ptr, size)
                }

                // 2. Measure Scalar Baseline
                let startScalar = DispatchTime.now()
                for _ in 0..<iterations {
                    crcScalar = ttzip_crc32_scalar(crcScalar, ptr, size)
                }
                let durScalar = Double(DispatchTime.now().uptimeNanoseconds - startScalar.uptimeNanoseconds) / 1_000_000_000.0
                let totalMB = Double(size * iterations) / (1024.0 * 1024.0)
                let mbpsScalar = totalMB / durScalar

                // 3. Measure PMULL Wide
                let startPmull = DispatchTime.now()
                for _ in 0..<iterations {
                    crcPmull = ttzip_crc32_pmull_wide(crcPmull, ptr, size)
                }
                let durPmull = Double(DispatchTime.now().uptimeNanoseconds - startPmull.uptimeNanoseconds) / 1_000_000_000.0
                let mbpsPmull = totalMB / durPmull

                let delta = ((mbpsPmull - mbpsScalar) / mbpsScalar) * 100.0
                let status = delta >= 0.0 ? "🟢 UP" : (delta >= -3.0 ? "⚪ FLAT" : "🔴 REG")

                let sizeStr: String
                if size < 1024 {
                    sizeStr = "\(size) B"
                } else if size < 1048576 {
                    sizeStr = "\(size / 1024) KB"
                } else {
                    sizeStr = "\(size / 1048576) MB"
                }

                print(String(
                    format: "%-10@ | %13.1f MB/s | %13.1f MB/s | %+10.1f%% | %@",
                    sizeStr, mbpsScalar, mbpsPmull, delta, status
                ))

                // Hard assertion: zero real performance regression (< -10%) on PMULL folded sizes (>= 192 bytes)
                #if arch(arm64)
                if size >= 192 {
                    XCTAssertGreaterThanOrEqual(
                        delta, -10.0,
                        "Severe regression detected on size \(size): \(delta)%"
                    )
                }
                #endif

            }
        }
        print("======================================================================\n")
    }

    // MARK: - 6. End-to-End Single-Core ZIP Archiving Performance Impact

    func testZipSingleCoreArchivingThroughput() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ttzip_crc_bench_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create a 10MB test dataset (structured text and binary data)
        let sampleFilePath = tempDir.appendingPathComponent("corpus_10mb.bin").path
        var sampleData = Data(count: 10 * 1024 * 1024)
        for i in 0..<(10 * 1024 * 1024) {
            sampleData[i] = UInt8((i &* 31 + 7) & 0xFF)
        }
        try sampleData.write(to: URL(fileURLWithPath: sampleFilePath))

        let zipOutPath = tempDir.appendingPathComponent("output.zip").path

        // Warmup
        _ = try NativeZipEngine.shared.createZipParallel(
            outputPath: zipOutPath,
            inputPaths: [sampleFilePath],
            level: .level1
        )
        try? FileManager.default.removeItem(atPath: zipOutPath)

        let iterations = 5
        let start = DispatchTime.now()
        for _ in 0..<iterations {
            _ = try NativeZipEngine.shared.createZipParallel(
                outputPath: zipOutPath,
                inputPaths: [sampleFilePath],
                level: .level1
            )
            try? FileManager.default.removeItem(atPath: zipOutPath)
        }
        let elapsedSec = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000.0

        let totalMB = Double(10 * iterations)
        let throughputMBs = totalMB / elapsedSec

        print("[MACRO-BENCH] Single-Core ZIP Level 1 End-to-End Archiving Throughput: \(String(format: "%.1f", throughputMBs)) MB/s")
        XCTAssertGreaterThanOrEqual(throughputMBs, 1500.0, "End-to-end ZIP archiving throughput fell below 1500 MB/s!")
    }
}
