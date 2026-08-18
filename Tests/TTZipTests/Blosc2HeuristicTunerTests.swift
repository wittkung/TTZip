// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import CTTZipBridge
@testable import TTZipCore

final class Blosc2HeuristicTunerTests: XCTestCase {

    func testHighEntropyRejectionToDirectStore() {
        let count = 16384
        var randomBytes = [UInt8](repeating: 0, count: count)
        for i in 0..<count {
            randomBytes[i] = UInt8.random(in: 0...255)
        }
        let rawData = Data(randomBytes)

        let rec = rawData.withUnsafeBytes { raw in
            ttzip_heuristic_eval_cascade(raw.baseAddress!, raw.count, 1, nil)
        }

        XCTAssertEqual(rec.codec, TTZIP_TUNER_CODEC_DIRECT, "High entropy random data must bypass compression")
        XCTAssertEqual(rec.filter_type, TTZIP_FILTER_NONE)
    }

    func testSmoothFloatArrayAutotuningToShuffleOrDelta() {
        let count = 4096 // 16KB Float32 signal
        var floats = [Float](repeating: 0, count: count)
        for i in 0..<count {
            floats[i] = sin(Float(i) * 0.05) * 100.0
        }
        let byteCount = count * 4
        let rawData = Data(bytes: floats, count: byteCount)

        let rec = rawData.withUnsafeBytes { raw in
            ttzip_heuristic_eval_cascade(raw.baseAddress!, raw.count, 4, nil)
        }

        XCTAssertNotEqual(rec.codec, TTZIP_TUNER_CODEC_DIRECT, "Smooth numerical signal must select an active codec")
        XCTAssertTrue(rec.filter_type == TTZIP_FILTER_SHUFFLE || rec.filter_type == TTZIP_FILTER_BITSHUFFLE || rec.filter_type == TTZIP_FILTER_DELTA, "Tuner must select a structured numerical filter")
        XCTAssertGreaterThan(rec.predicted_ratio, 1.5, "Tuned pipeline must predict >1.5x compression ratio")
    }

    func testStrideAutocorrelationCalculation() {
        let count = 8192
        var data = [UInt8](repeating: 0, count: count)
        // 4-byte repeating structure
        for i in 0..<count {
            data[i] = UInt8(i % 4 == 0 ? 0xAA : (i % 4 == 1 ? 0xBB : (i % 4 == 2 ? 0xCC : 0xDD)))
        }
        let rawData = Data(data)

        let corr4 = rawData.withUnsafeBytes { raw in
            ttzip_calc_autocorrelation_stride(raw.baseAddress!, raw.count, 4)
        }
        let corr3 = rawData.withUnsafeBytes { raw in
            ttzip_calc_autocorrelation_stride(raw.baseAddress!, raw.count, 3)
        }

        XCTAssertGreaterThan(corr4, 0.9, "Autocorrelation at period stride 4 must be very high (>0.9)")
        XCTAssertLessThan(corr3, corr4, "Autocorrelation at non-period stride 3 must be lower than stride 4")
    }
}
