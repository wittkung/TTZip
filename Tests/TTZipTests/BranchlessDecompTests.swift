// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import CTTZipBridge
@testable import TTZipCore

final class BranchlessDecompTests: XCTestCase {

    func testHuffman11BitFastLookup() {
        // Setup a canonical Huffman code length array for 8 symbols
        // Canonical assignment:
        // sym 0: len 1 -> code 0 (fills 1024 LUT entries)
        // sym 1: len 2 -> code 10 (fills 512 LUT entries)
        // sym 2: len 3 -> code 110 (fills 256 LUT entries)
        // sym 3: len 3 -> code 111 (fills 256 LUT entries)
        let codeLengths: [UInt8] = [1, 2, 3, 3, 0, 0, 0, 0]
        var lut = ttzip_huffman_lut_t()

        let buildRes = codeLengths.withUnsafeBufferPointer { ptr in
            ttzip_huffman_build_lut(&lut, ptr.baseAddress, UInt32(ptr.count))
        }
        XCTAssertEqual(buildRes, 0, "Huffman LUT construction must succeed")
        XCTAssertEqual(lut.max_code_len, 3)

        // Encode stream with bitstream:
        // 0 (sym 0, 1 bit), 10 (sym 1, 2 bits), 110 (sym 2, 3 bits), 111 (sym 3, 3 bits), 0 (sym 0, 1 bit)
        // Bits: 0 10 110 111 0 = 0101 1011 1000 0000 = 0x5B, 0x80
        let encodedBytes: [UInt8] = [0x5B, 0x80, 0x00, 0x00]
        var reader = ttzip_bitstream_reader_t()

        encodedBytes.withUnsafeBufferPointer { inPtr in
            ttzip_bitstream_init(&reader, inPtr.baseAddress, inPtr.count)

            var sym0: UInt16 = 0
            let len0 = ttzip_huffman_decode_symbol(&reader, &lut, &sym0)
            XCTAssertEqual(sym0, 0)
            XCTAssertEqual(len0, 1)

            var sym1: UInt16 = 0
            let len1 = ttzip_huffman_decode_symbol(&reader, &lut, &sym1)
            XCTAssertEqual(sym1, 1)
            XCTAssertEqual(len1, 2)

            var sym2: UInt16 = 0
            let len2 = ttzip_huffman_decode_symbol(&reader, &lut, &sym2)
            XCTAssertEqual(sym2, 2)
            XCTAssertEqual(len2, 3)

            var sym3: UInt16 = 0
            let len3 = ttzip_huffman_decode_symbol(&reader, &lut, &sym3)
            XCTAssertEqual(sym3, 3)
            XCTAssertEqual(len3, 3)

            var sym4: UInt16 = 0
            let len4 = ttzip_huffman_decode_symbol(&reader, &lut, &sym4)
            XCTAssertEqual(sym4, 0)
            XCTAssertEqual(len4, 1)
        }
    }

    func testCircularRingDictFastAndSlowPath() {
        let dictSize: size_t = 65536 // 64KB (Power of 2)
        let dictBuf = UnsafeMutablePointer<UInt8>.allocate(capacity: dictSize)
        defer { dictBuf.deallocate() }
        dictBuf.initialize(repeating: 0, count: dictSize)

        var dict = ttzip_ring_dict_t()
        let initRes = ttzip_ring_dict_init(&dict, dictBuf, dictSize)
        XCTAssertEqual(initRes, 0)
        XCTAssertEqual(dict.dict_size_mask, dictSize - 1)

        // Seed initial 16 bytes: "0123456789ABCDEF"
        let seed = Array("0123456789ABCDEF".utf8)
        for i in 0..<seed.count {
            dictBuf[i] = seed[i]
        }
        dict.write_pos = seed.count
        dict.total_written = seed.count

        // 1. Fast-Path: Copy 16 bytes from dist 16 (linear, non-wrapping)
        let copyRes1 = ttzip_ring_dict_copy_match(&dict, 16, 16)
        XCTAssertEqual(copyRes1, 0)
        XCTAssertEqual(dict.write_pos, 32)
        XCTAssertEqual(dict.total_written, 32)
        XCTAssertEqual(dictBuf[16], UInt8(ascii: "0"))
        XCTAssertEqual(dictBuf[31], UInt8(ascii: "F"))

        // Move write_pos near the end to test Slow-Path boundary wrap
        dict.write_pos = dictSize - 8
        let copyRes2 = ttzip_ring_dict_copy_match(&dict, 16, 32)
        XCTAssertEqual(copyRes2, 0)
        XCTAssertEqual(dict.write_pos, 24) // (65536 - 8 + 32) % 65536 = 24
        XCTAssertEqual(dict.total_written, 32 + 32)
    }

    func testOverlapAndRleMatchCopy() {
        let dictSize: size_t = 32768
        let dictBuf = UnsafeMutablePointer<UInt8>.allocate(capacity: dictSize)
        defer { dictBuf.deallocate() }
        dictBuf.initialize(repeating: 0, count: dictSize)

        var dict = ttzip_ring_dict_t()
        let initRes = ttzip_ring_dict_init(&dict, dictBuf, dictSize)
        XCTAssertEqual(initRes, 0)

        // Seed byte 0xAA at pos 0
        dictBuf[0] = 0xAA
        dict.write_pos = 1
        dict.total_written = 1

        // Test RLE match: dist = 1, length = 64
        let rleRes = ttzip_ring_dict_copy_match(&dict, 1, 64)
        XCTAssertEqual(rleRes, 0)
        XCTAssertEqual(dict.write_pos, 65)
        for i in 0...64 {
            XCTAssertEqual(dictBuf[i], 0xAA)
        }

        // Test Self-Overlapping match: pattern "XYZ" (length 3, dist 3, repeat 21 bytes)
        dictBuf[65] = UInt8(ascii: "X")
        dictBuf[66] = UInt8(ascii: "Y")
        dictBuf[67] = UInt8(ascii: "Z")
        dict.write_pos = 68
        dict.total_written += 3

        let overlapRes = ttzip_ring_dict_copy_match(&dict, 3, 18)
        XCTAssertEqual(overlapRes, 0)
        XCTAssertEqual(dict.write_pos, 86)

        // Verify periodic "XYZXYZ..." pattern
        let expectedPattern = Array("XYZXYZXYZXYZXYZXYZ".utf8)
        for j in 0..<18 {
            XCTAssertEqual(dictBuf[68 + j], expectedPattern[j])
        }
    }

    func testInvalidParamHandling() {
        var dict = ttzip_ring_dict_t()
        let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: 40000)
        defer { buf.deallocate() }

        // Non-power of two dict size must fail
        let badRes = ttzip_ring_dict_init(&dict, buf, 35000)
        XCTAssertEqual(badRes, -2)

        // Dict size < 32KB must fail
        let smallRes = ttzip_ring_dict_init(&dict, buf, 16384)
        XCTAssertEqual(smallRes, -1)
    }
}
