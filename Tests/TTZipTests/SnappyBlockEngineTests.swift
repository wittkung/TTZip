// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class SnappyBlockEngineTests: XCTestCase {

    var engine: SnappyBlockEngine!

    override func setUp() {
        super.setUp()
        engine = SnappyBlockEngine.shared
    }

    func testEngineAvailability() {
        XCTAssertTrue(engine.isAvailable, "Google Snappy native engine should be available")
    }

    func testEmptyDataRoundTrip() throws {
        let empty = Data()
        let compressed = try engine.compress(data: empty)
        XCTAssertTrue(compressed.isEmpty)
        let decompressed = try engine.decompress(compressedData: compressed)
        XCTAssertTrue(decompressed.isEmpty)
    }

    func testSmallStringRoundTrip() throws {
        let text = "Hello, world! Google Snappy native in-process engine for TTZip macOS Sonoma."
        let data = Data(text.utf8)
        let compressed = try engine.compress(data: data)
        XCTAssertFalse(compressed.isEmpty)

        let parsedLen = try engine.uncompressedLength(of: compressed)
        XCTAssertEqual(parsedLen, data.count)

        let decompressed = try engine.decompress(compressedData: compressed)
        XCTAssertEqual(decompressed, data)
        XCTAssertEqual(String(data: decompressed, encoding: .utf8), text)
    }

    func testLargeRepetitiveBufferRoundTrip() throws {
        let pattern = "AppleSiliconMSeriesHighThroughputZeroCopyArchivingEngine2026TTZip!"
        var largeData = Data()
        for _ in 0..<10_000 {
            largeData.append(pattern.data(using: .utf8)!)
        }
        XCTAssertEqual(largeData.count, pattern.utf8.count * 10_000)

        let compressed = try engine.compress(data: largeData)
        XCTAssertLessThan(compressed.count, largeData.count / 10, "Repetitive data should achieve high compression ratio")

        XCTAssertTrue(engine.validate(compressedData: compressed))

        let decompressed = try engine.decompress(compressedData: compressed)
        XCTAssertEqual(decompressed.count, largeData.count)
        XCTAssertEqual(decompressed, largeData)
    }

    func testRandomUncompressibleBufferRoundTrip() throws {
        var randomData = Data(count: 65536)
        for i in 0..<randomData.count {
            randomData[i] = UInt8((i * 109 + 89) & 0xFF)
        }

        let compressed = try engine.compress(data: randomData)
        let decompressed = try engine.decompress(compressedData: compressed)
        XCTAssertEqual(decompressed, randomData)
    }

    func testCRC32CAndMasking() {
        let data = Data("123456789".utf8)
        let crc = engine.crc32c(data: data)
        // Standard Castagnoli CRC-32C for "123456789" is 0xe3069283
        XCTAssertEqual(crc, 0xe3069283, "CRC32C for '123456789' should match standard Castagnoli vector")

        let masked = engine.maskCRC32C(crc)
        let unmasked = engine.unmaskCRC32C(masked)
        XCTAssertEqual(unmasked, crc, "Masked CRC32C unmasking must restore original CRC32C")
    }

    func testMaxCompressedLengthSafetyBound() {
        let sourceLen = 1000
        let maxComp = engine.maxCompressedLength(for: sourceLen)
        XCTAssertGreaterThanOrEqual(maxComp, sourceLen + 32)
    }
}
