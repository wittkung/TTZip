// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class SnappyFramingStreamTests: XCTestCase {

    var framing: SnappyFramingStream!

    override func setUp() {
        super.setUp()
        framing = SnappyFramingStream.shared
    }

    func testStreamIdentifierValidation() {
        let validHeader = Data([0xFF, 0x06, 0x00, 0x00, 0x73, 0x4E, 0x61, 0x50, 0x70, 0x59])
        XCTAssertTrue(framing.isFramedSnappy(data: validHeader))

        let invalidHeader = Data([0x00, 0x06, 0x00, 0x00, 0x73, 0x4E, 0x61, 0x50, 0x70, 0x59])
        XCTAssertFalse(framing.isFramedSnappy(data: invalidHeader))

        let shortHeader = Data([0xFF, 0x06])
        XCTAssertFalse(framing.isFramedSnappy(data: shortHeader))
    }

    func testEmptyStreamEncodingAndDecoding() throws {
        let empty = Data()
        let encoded = try framing.encode(data: empty)
        XCTAssertEqual(encoded, SnappyFramingStream.streamIdentifier)

        let decoded = try framing.decode(framedData: encoded)
        XCTAssertTrue(decoded.isEmpty)
    }

    func testSmallStreamRoundTrip() throws {
        let text = "Apple Silicon Sonoma 14+ / Sequoia 15+ Native Snappy Framed Stream Testing"
        let data = Data(text.utf8)

        let encoded = try framing.encode(data: data)
        XCTAssertTrue(framing.isFramedSnappy(data: encoded))
        XCTAssertGreaterThan(encoded.count, 10)

        let decoded = try framing.decode(framedData: encoded)
        XCTAssertEqual(decoded, data)
        XCTAssertEqual(String(data: decoded, encoding: .utf8), text)
    }

    func testMultiChunkStreamRoundTrip() throws {
        // Create 200KB payload (spans 4 chunks of 64KB)
        var largeData = Data(count: 200 * 1024)
        for i in 0..<largeData.count {
            largeData[i] = UInt8((i ^ (i >> 3)) & 0xFF)
        }

        let encoded = try framing.encode(data: largeData)
        XCTAssertTrue(framing.isFramedSnappy(data: encoded))

        let decoded = try framing.decode(framedData: encoded)
        XCTAssertEqual(decoded.count, largeData.count)
        XCTAssertEqual(decoded, largeData)
    }

    func testUncompressibleChunkFallback() throws {
        // High-entropy random payload (should fall back to chunk type 0x01 uncompressed)
        var randomData = Data(count: 65536)
        for i in 0..<randomData.count {
            randomData[i] = UInt8((i * 199 + 17) & 0xFF)
        }

        let encoded = try framing.encode(data: randomData)
        XCTAssertTrue(framing.isFramedSnappy(data: encoded))

        let decoded = try framing.decode(framedData: encoded)
        XCTAssertEqual(decoded, randomData)
    }

    func testCorruptedCRC32CTrigger() throws {
        let data = Data("This is critical data protected by Castagnoli CRC32C.".utf8)
        var encoded = try framing.encode(data: data)

        // Corrupt a byte in the payload (past the 10-byte stream ID and 8-byte chunk header)
        if encoded.count > 20 {
            encoded[19] ^= 0x01
        }

        XCTAssertThrowsError(try framing.decode(framedData: encoded)) { error in
            guard let snappyError = error as? SnappyError else {
                XCTFail("Expected SnappyError, got \(error)")
                return
            }
            if case .crc32cMismatch = snappyError {
                // Expected
            } else {
                // If the corruption corrupted the framing tag itself, corruptTag is also valid
                XCTAssertTrue(snappyError == .crc32cMismatch(expected: 0, actual: 0) || snappyError == .corruptTag)
            }
        }
    }
}
