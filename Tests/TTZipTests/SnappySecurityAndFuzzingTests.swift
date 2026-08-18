// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore
import CTTZipBridge

final class SnappySecurityAndFuzzingTests: XCTestCase {

    var blockEngine: SnappyBlockEngine!
    var framingStream: SnappyFramingStream!

    override func setUp() {
        super.setUp()
        blockEngine = SnappyBlockEngine.shared
        framingStream = SnappyFramingStream.shared
    }

    // MARK: - 13-Dimensional Reverse Injection Fuzzing Matrix

    /// Dimension 1: 0-byte input
    func testD01_EmptyBuffer() {
        XCTAssertNoThrow(try blockEngine.decompress(compressedData: Data()))
        XCTAssertNoThrow(try framingStream.decode(framedData: Data()))
    }

    /// Dimension 2: Truncated stream header (< 10 bytes)
    func testD02_TruncatedStreamHeader() {
        let partial = Data([0xFF, 0x06, 0x00, 0x00, 0x73, 0x4E])
        XCTAssertThrowsError(try framingStream.decode(framedData: partial)) { error in
            XCTAssertTrue(error is SnappyError)
        }
    }

    /// Dimension 3: Corrupted magic header
    func testD03_InvalidStreamMagic() {
        let invalid = Data([0xFF, 0x06, 0x00, 0x00, 0x5A, 0x49, 0x50, 0x50, 0x59, 0x21])
        XCTAssertThrowsError(try framingStream.decode(framedData: invalid)) { error in
            XCTAssertTrue(error is SnappyError)
        }
    }

    /// Dimension 4: Truncated chunk header (valid 10-byte ID + 2 bytes chunk header)
    func testD04_TruncatedChunkHeader() {
        var data = SnappyFramingStream.streamIdentifier
        data.append(contentsOf: [0x00, 0x10]) // Incomplete 4-byte chunk header
        XCTAssertThrowsError(try framingStream.decode(framedData: data)) { error in
            XCTAssertTrue(error is SnappyError)
        }
    }

    /// Dimension 5: Oversized chunk length (> 64KB + 4)
    func testD05_OversizedChunkLength() {
        var data = SnappyFramingStream.streamIdentifier
        // Chunk type 0x00 (compressed), length = 0x020000 (131072 bytes > 64KB + 4)
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00])
        XCTAssertThrowsError(try framingStream.decode(framedData: data)) { error in
            XCTAssertTrue(error is SnappyError)
        }
    }

    /// Dimension 6: Non-terminating Varint32 prefix (all bytes have MSB 0x80)
    func testD06_NonTerminatingVarint() {
        let badVarint = Data([0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x01])
        XCTAssertThrowsError(try blockEngine.decompress(compressedData: badVarint)) { error in
            XCTAssertTrue(error is SnappyError)
        }
    }

    /// Dimension 7: Varint says 1GB but actual payload is only 3 bytes
    func testD07_ZeroLengthPayloadWithOversizedVarint() {
        let fakeLength = Data([0xFF, 0xFF, 0xFF, 0x7F, 0x00]) // Varint = 268435455 bytes
        XCTAssertThrowsError(try blockEngine.decompress(compressedData: fakeLength)) { error in
            XCTAssertTrue(error is SnappyError)
        }
    }

    /// Dimension 8: Corrupted Tag bytes
    func testD08_CorruptedTagByte() {
        // Varint length = 20, followed by random invalid element tags
        let data = Data([0x14, 0xFE, 0xDC, 0xBA, 0x98])
        XCTAssertThrowsError(try blockEngine.decompress(compressedData: data)) { error in
            XCTAssertTrue(error is SnappyError)
        }
    }

    /// Dimension 9: Literal length declaration exceeding available input
    func testD09_LiteralRunOverrun() {
        // Varint length = 100, literal tag for 60-byte literal, but only 2 bytes follow
        let data = Data([0x64, 0xF0, 0x01, 0x02])
        XCTAssertThrowsError(try blockEngine.decompress(compressedData: data)) { error in
            XCTAssertTrue(error is SnappyError)
        }
    }

    /// Dimension 10: Copy offset zero (illegal in LZ77)
    func testD10_CopyOffsetZero() {
        // Varint length = 20, 4-byte literal "abcd", followed by Copy 1-byte tag with offset 0
        let data = Data([0x14, 0x0C, 0x61, 0x62, 0x63, 0x64, 0x01, 0x00])
        XCTAssertThrowsError(try blockEngine.decompress(compressedData: data)) { error in
            XCTAssertTrue(error is SnappyError)
        }
    }

    /// Dimension 11: Copy offset referencing beyond written buffer (OOB lookback)
    func testD11_CopyOffsetOutOfBounds() {
        // Varint length = 20, 2-byte literal "ab", followed by Copy 2-byte tag with offset 5000
        let data = Data([0x14, 0x04, 0x61, 0x62, 0x02, 0x88, 0x13])
        XCTAssertThrowsError(try blockEngine.decompress(compressedData: data)) { error in
            XCTAssertTrue(error is SnappyError)
        }
    }

    /// Dimension 12: Masked CRC32C Checksum mismatch
    func testD12_MaskedCRC32CMismatch() throws {
        let validPayload = "High-performance checksum integrity test"
        var framed = try framingStream.encode(data: Data(validPayload.utf8))
        if framed.count > 16 {
            framed[15] ^= 0xFF // Invert bits in payload
        }
        XCTAssertThrowsError(try framingStream.decode(framedData: framed)) { error in
            XCTAssertTrue(error is SnappyError)
        }
    }

    /// Dimension 13: Reserved unskippable chunk type (0x02..0x7F)
    func testD13_UnskippableReservedChunk() {
        var data = SnappyFramingStream.streamIdentifier
        // Chunk type 0x05 (reserved unskippable), length 4, CRC 0
        data.append(contentsOf: [0x05, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        XCTAssertThrowsError(try framingStream.decode(framedData: data)) { error in
            XCTAssertTrue(error is SnappyError)
        }
    }

    // MARK: - Random Mutation Pseudo-Fuzzing Pass (500 Iterations)

    func testRandomBitFlipMutationFuzzing() throws {
        let seedText = "The quick brown fox jumps over the lazy dog. TTZip Apple Silicon Snappy in-process."
        let validCompressed = try blockEngine.compress(data: Data(seedText.utf8))

        var rngState: UInt64 = 0xDEADBEEFCAFEBABE
        func nextRand() -> UInt64 {
            rngState = rngState &* 6364136223846793005 &+ 1442695040888963407
            return rngState
        }

        for _ in 0..<500 {
            var mutated = validCompressed
            let mutations = Int(nextRand() % 4) + 1
            for _ in 0..<mutations {
                let pos = Int(nextRand() % UInt64(mutated.count))
                let bit = UInt8(1 << (nextRand() % 8))
                mutated[pos] ^= bit
            }

            // Must either cleanly decompress or return an error without crashing or hanging
            _ = try? blockEngine.decompress(compressedData: mutated)
        }
    }
}
