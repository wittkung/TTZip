// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import CTTZipBridge
@testable import TTZipCore

@_silgen_name("lzma_crc64")
private func lzma_crc64(_ buf: UnsafePointer<UInt8>?, _ size: Int, _ crc: UInt64) -> UInt64

/// Test suite validating ARM64 PMULL hardware-accelerated CRC64 calculation against scalar baselines and LZMA oracle.
final class CRC64HardwareTests: XCTestCase {

    // MARK: - 1. Golden Test Vector & Oracle Validation

    /// Validates standard golden test vectors against liblzma reference implementation and CTTZipBridge kernels.
    func testGoldenVectorAndDifferential() {
        let ascii9 = "123456789".data(using: .utf8)!
        let expectedXZCRC: UInt64 = 0x995DC9BBDF1939FA

        // 1. lzma_crc64 oracle
        let computedLZMA = ascii9.withUnsafeBytes { raw in
            lzma_crc64(raw.baseAddress?.assumingMemoryBound(to: UInt8.self), raw.count, 0)
        }
        XCTAssertEqual(computedLZMA, expectedXZCRC, "lzma_crc64 oracle value mismatch!")

        // 2. Swift Data wrapper
        let computedSwift = CRC64Checksum.calculate(for: ascii9)
        XCTAssertEqual(computedSwift, expectedXZCRC, "CRC64 (Swift Data) for '123456789' mismatch!")

        // 3. C bridge auto-dispatch
        let computedC = ascii9.withUnsafeBytes { raw in
            ttzip_crc64(raw.baseAddress?.assumingMemoryBound(to: UInt8.self), raw.count, 0)
        }
        XCTAssertEqual(computedC, expectedXZCRC, "CRC64 (C ttzip_crc64) for '123456789' mismatch!")

        // 4. PMULL hardware kernel
        let computedPMULL = ascii9.withUnsafeBytes { raw in
            ttzip_crc64_pmull(raw.baseAddress?.assumingMemoryBound(to: UInt8.self), raw.count, 0)
        }
        XCTAssertEqual(computedPMULL, expectedXZCRC, "CRC64 (ttzip_crc64_pmull) for '123456789' mismatch!")

        // 5. Scalar slice-by-8 kernel
        let computedScalar = ascii9.withUnsafeBytes { raw in
            ttzip_crc64_scalar(raw.baseAddress?.assumingMemoryBound(to: UInt8.self), raw.count, 0)
        }
        XCTAssertEqual(computedScalar, expectedXZCRC, "CRC64 (ttzip_crc64_scalar) for '123456789' mismatch!")
    }

    // MARK: - 2. Boundary & Invariant Safety

    /// Validates zero-length and null pointer invariants.
    func testZeroLengthAndNull() {
        let emptyData = Data()
        let seed: UInt64 = 0x123456789ABCDEF0

        XCTAssertEqual(CRC64Checksum.calculate(for: emptyData, seed: seed), seed)
        XCTAssertEqual(ttzip_crc64(nil, 0, seed), seed)
        XCTAssertEqual(ttzip_crc64_pmull(nil, 0, seed), seed)
        XCTAssertEqual(ttzip_crc64_scalar(nil, 0, seed), seed)
    }

    // MARK: - 3. 0~256 Exhaustive Differential Testing

    /// Validates exhaustive differential identity across lengths 0 to 256.
    func testExhaustiveDifferential0To256() {
        var pattern = [UInt8](repeating: 0, count: 512)
        for i in 0..<512 {
            pattern[i] = UInt8((i * 37 + 13) & 0xFF)
        }

        for length in 0...256 {
            let data = Data(pattern[0..<length])
            let pmullCRC = data.withUnsafeBytes { raw in
                ttzip_crc64_pmull(raw.baseAddress?.assumingMemoryBound(to: UInt8.self), raw.count, 0)
            }
            let scalarCRC = data.withUnsafeBytes { raw in
                ttzip_crc64_scalar(raw.baseAddress?.assumingMemoryBound(to: UInt8.self), raw.count, 0)
            }
            let lzmaCRC = data.withUnsafeBytes { raw in
                lzma_crc64(raw.baseAddress?.assumingMemoryBound(to: UInt8.self), raw.count, 0)
            }
            let swiftCRC = CRC64Checksum.calculate(for: data)

            XCTAssertEqual(pmullCRC, scalarCRC, "Differential mismatch between PMULL and Scalar at length \(length)")
            XCTAssertEqual(pmullCRC, lzmaCRC, "Differential mismatch between PMULL and lzma_crc64 at length \(length)")
            XCTAssertEqual(swiftCRC, pmullCRC, "Differential mismatch between Swift wrapper and PMULL at length \(length)")
        }
    }

    // MARK: - 4. Unaligned & Multi-Slice Safety

    /// Validates unaligned slice pointers and offsets against reference implementations.
    func testUnalignedAndOffsetSlices() {
        let bufferSize = 2048
        var rawMemory = [UInt8](repeating: 0, count: bufferSize)
        for i in 0..<bufferSize {
            rawMemory[i] = UInt8((i * 101 + 7) & 0xFF)
        }

        let offsets = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 15, 16, 17, 31, 32, 33, 63, 64, 65, 127, 128]
        let lengths = [0, 1, 3, 7, 8, 9, 15, 16, 17, 31, 32, 47, 48, 63, 64, 65, 127, 128, 255, 256, 512, 1024]

        rawMemory.withUnsafeBufferPointer { bufPtr in
            guard let base = bufPtr.baseAddress else { return }

            for offset in offsets {
                for length in lengths {
                    guard offset + length <= bufferSize else { continue }
                    let slicePtr = base.advanced(by: offset)

                    let pmullCRC = ttzip_crc64_pmull(slicePtr, length, 0)
                    let scalarCRC = ttzip_crc64_scalar(slicePtr, length, 0)
                    let lzmaCRC = lzma_crc64(slicePtr, length, 0)
                    let cAutoCRC = ttzip_crc64(slicePtr, length, 0)

                    XCTAssertEqual(pmullCRC, scalarCRC, "Unaligned slice mismatch between PMULL and Scalar at offset \(offset), length \(length)")
                    XCTAssertEqual(pmullCRC, lzmaCRC, "Unaligned slice mismatch between PMULL and lzma_crc64 at offset \(offset), length \(length)")
                    XCTAssertEqual(cAutoCRC, pmullCRC, "C Auto dispatch mismatch at offset \(offset), length \(length)")
                }
            }
        }
    }

    // MARK: - 5. 10MB Throughput Performance Floor Gate

    /// Verifies hardware CRC64 throughput meets performance floor requirements.
    func testThroughputPerformanceFloor() {
        let bufferSize = 10 * 1024 * 1024 // 10MB
        var testData = [UInt8](repeating: 0xAB, count: bufferSize)
        for i in 0..<1024 {
            testData[i] = UInt8(i & 0xFF)
        }

        // Warm-up pass
        testData.withUnsafeBufferPointer { bufPtr in
            _ = ttzip_crc64(bufPtr.baseAddress, bufPtr.count, 0)
        }

        let iterations = 100
        let startTime = CFAbsoluteTimeGetCurrent()

        var checksum: UInt64 = 0
        testData.withUnsafeBufferPointer { bufPtr in
            guard let base = bufPtr.baseAddress else { return }
            for _ in 0..<iterations {
                checksum ^= ttzip_crc64(base, bufPtr.count, 0)
            }
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        let totalMB = Double(bufferSize * iterations) / (1024.0 * 1024.0)
        let throughputMBps = totalMB / elapsed

        TTLogger.debug(String(format: "=== [CRC64 Hardware PMULL] 10MB Buffer Throughput: %.1f MB/s (Elapsed: %.4f s, Checksum: %016llX) ===", throughputMBps, elapsed, checksum))

        #if arch(arm64)
        #if DEBUG
        let floorMBps: Double = 25000.0
        #else
        let floorMBps: Double = 35000.0
        #endif
        XCTAssertGreaterThanOrEqual(throughputMBps, floorMBps, "ARM64 PMULL CRC64 throughput \(throughputMBps) MB/s fell below hard floor \(floorMBps) MB/s!")
        #endif
    }

    // MARK: - 6. Comparative Speedup Benchmark

    /// Executes comparative speedup benchmark comparing PMULL against Slice-by-8 and liblzma baselines.
    func testComparativeSpeedupBenchmark() {
        let scenarios: [(name: String, size: Int, iterations: Int)] = [
            ("64 KB Slice", 64 * 1024, TestBenchmarkTier.benchmarkIterations(default: 50, benchmark: 2000)),
            ("1 MB Buffer", 1 * 1024 * 1024, TestBenchmarkTier.benchmarkIterations(default: 10, benchmark: 500)),
            ("10 MB Block", 10 * 1024 * 1024, TestBenchmarkTier.benchmarkIterations(default: 2, benchmark: 100)),
            ("50 MB Large", 50 * 1024 * 1024, TestBenchmarkTier.benchmarkIterations(default: 1, benchmark: 20))
        ]

        TTLogger.debug("\n=========================================================================================================")
        TTLogger.debug("                 TTZip ARM64 PMULL CRC64 Hardware Acceleration vs Scalar Benchmark")
        TTLogger.debug("=========================================================================================================")
        TTLogger.debug(String(format: "%-16@ | %-12@ | %-18@ | %-18@ | %-18@ | %-12@", "Test Scenario", "Single Payload", "Baseline (lzma_crc64)", "Scalar (Slice-by-8)", "PMULL Hardware", "Speedup"))
        TTLogger.debug("---------------------------------------------------------------------------------------------------------")

        for s in scenarios {
            var data = [UInt8](repeating: 0x5A, count: s.size)
            for i in 0..<min(s.size, 4096) {
                data[i] = UInt8(i & 0xFF)
            }

            data.withUnsafeBufferPointer { bufPtr in
                guard let base = bufPtr.baseAddress else { return }

                // 1. lzma_crc64
                _ = lzma_crc64(base, s.size, 0)
                let t0 = CFAbsoluteTimeGetCurrent()
                for _ in 0..<s.iterations {
                    _ = lzma_crc64(base, s.size, 0)
                }
                let elapsedLZMA = CFAbsoluteTimeGetCurrent() - t0
                let mbLZMA = (Double(s.size * s.iterations) / (1024.0 * 1024.0)) / elapsedLZMA

                // 2. Slice-by-8
                _ = ttzip_crc64_scalar(base, s.size, 0)
                let t1 = CFAbsoluteTimeGetCurrent()
                for _ in 0..<s.iterations {
                    _ = ttzip_crc64_scalar(base, s.size, 0)
                }
                let elapsedScalar = CFAbsoluteTimeGetCurrent() - t1
                let mbScalar = (Double(s.size * s.iterations) / (1024.0 * 1024.0)) / elapsedScalar

                // 3. PMULL
                _ = ttzip_crc64_pmull(base, s.size, 0)
                let t2 = CFAbsoluteTimeGetCurrent()
                for _ in 0..<s.iterations {
                    _ = ttzip_crc64_pmull(base, s.size, 0)
                }
                let elapsedPMULL = CFAbsoluteTimeGetCurrent() - t2
                let mbPMULL = (Double(s.size * s.iterations) / (1024.0 * 1024.0)) / elapsedPMULL

                let speedupVsLZMA = mbPMULL / mbLZMA
                let deltaPercent = ((mbPMULL - mbLZMA) / mbLZMA) * 100.0

                let sizeStr = s.size >= 1024 * 1024 ? "\(s.size / (1024 * 1024)) MB" : "\(s.size / 1024) KB"
                let lzmaStr = String(format: "%.1f MB/s", mbLZMA)
                let scalarStr = String(format: "%.1f MB/s", mbScalar)
                let pmullStr = String(format: "%.1f MB/s", mbPMULL)
                let speedupStr = String(format: "%.1fx (+%.1f%%)", speedupVsLZMA, deltaPercent)

                TTLogger.debug(String(format: "%-16@ | %-12@ | %-18@ | %-18@ | %-18@ | %-12@", s.name as NSString, sizeStr as NSString, lzmaStr as NSString, scalarStr as NSString, pmullStr as NSString, speedupStr as NSString))
            }
        }
        TTLogger.debug("=========================================================================================================\n")
    }
}
