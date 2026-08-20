// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.

import XCTest
import CTTZipBridge
@testable import TTZipCore

final class SwarOptimizationBenchmarkTests: XCTestCase {

    func testAsciiScanThroughput() throws {
        let size = 64 * 1024 // 64KB sample
        var asciiBytes = [UInt8](repeating: UInt8(ascii: "a"), count: size)
        asciiBytes[size - 1] = 0 // null terminated

        let iterations = TestBenchmarkTier.benchmarkIterations(default: 100, benchmark: 100_000)
        let startTime = CFAbsoluteTimeGetCurrent()

        var isValid = true
        for _ in 0..<iterations {
            asciiBytes.withUnsafeBytes { rawBuffer in
                isValid = isValid && ttzip_is_ascii_fast(rawBuffer.baseAddress, size)
            }
        }
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        XCTAssertTrue(isValid)

        if TestBenchmarkTier.isBenchmarkMode {
            let totalMB = (Double(size) * Double(iterations)) / (1024.0 * 1024.0)
            let throughputMBS = totalMB / elapsed
            XCTAssertGreaterThan(throughputMBS, 2000.0, "ASCII scan throughput must exceed 2,000 MB/s")
        }
    }

    func testEncodingDetectionSpeedup() throws {
        let sampleText = "Documents/Dev/TTZip/Sources/TTZipCore/ArchiveEngineFamily.swift"
        let sampleData = sampleText.data(using: .utf8)!
        let iterations = TestBenchmarkTier.benchmarkIterations(default: 100, benchmark: 1_000_000)

        let startTime = CFAbsoluteTimeGetCurrent()
        var matchCount = 0
        sampleData.withUnsafeBytes { rawBuffer in
            let ptr = rawBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self)
            for _ in 0..<iterations {
                let encoding = ttzip_detect_encoding_fast(ptr, sampleData.count)
                if strcmp(encoding, "UTF-8") == 0 {
                    matchCount += 1
                }
            }
        }
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        XCTAssertEqual(matchCount, iterations)

        if TestBenchmarkTier.isBenchmarkMode {
            let opsPerSec = Double(iterations) / elapsed
            XCTAssertGreaterThan(opsPerSec, 5_000_000.0, "Encoding detection rate must exceed 5M ops/s")
        }
    }

    func testFormatSniffingThroughput() throws {
        let zipHeader: [UInt8] = [0x50, 0x4B, 0x03, 0x04, 0x14, 0x00, 0x00, 0x00]
        let sevenzHeader: [UInt8] = [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C, 0x00, 0x04]
        let zstdHeader: [UInt8] = [0x28, 0xB5, 0x2F, 0xFD, 0x00, 0x00, 0x00, 0x00]
        let lz4Header: [UInt8] = [0x04, 0x22, 0x4D, 0x18, 0x60, 0x70, 0x73, 0x00]
        let xzHeader: [UInt8] = [0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00, 0x00, 0x00]

        let headers = [zipHeader, sevenzHeader, zstdHeader, lz4Header, xzHeader]
        let rawHeaders = headers.map { h -> (UnsafePointer<UInt8>, Int) in
            let ptr = UnsafeMutablePointer<UInt8>.allocate(capacity: h.count)
            ptr.initialize(from: h, count: h.count)
            return (UnsafePointer<UInt8>(ptr), h.count)
        }
        defer {
            for (p, count) in rawHeaders {
                let mutableP = UnsafeMutablePointer<UInt8>(mutating: p)
                mutableP.deinitialize(count: count)
                mutableP.deallocate()
            }
        }

        let iterations = TestBenchmarkTier.benchmarkIterations(default: 100, benchmark: 2_000_000)

        let startTime = CFAbsoluteTimeGetCurrent()
        var validCount = 0

        for _ in 0..<iterations {
            for (p, count) in rawHeaders {
                let fmt = ttzip_detect_format_from_header(p, count)
                if fmt != TTZIP_NATIVE_FMT_UNKNOWN {
                    validCount += 1
                }
            }
        }
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        XCTAssertEqual(validCount, iterations * headers.count)

        if TestBenchmarkTier.isBenchmarkMode {
            let totalOps = Double(iterations * headers.count)
            let opsPerSec = totalOps / elapsed
            XCTAssertGreaterThan(opsPerSec, 10_000_000.0, "Header format sniffing rate must exceed 10M sniffs/s")
        }
    }
}
