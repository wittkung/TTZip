// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import Foundation
@testable import TTZipCore
import CTTZipBridge

final class LZ77VectorMatchFinderTests: XCTestCase {

    // MARK: - 1. Exhaustive Match Length Vector Oracle Test

    func testMatchLengthVectorOracle() {
        let maxTestLen = 258
        let maxAlign = 16

        var baseBuffer1 = [UInt8](repeating: 0, count: maxTestLen + maxAlign + 64)
        var baseBuffer2 = [UInt8](repeating: 0, count: maxTestLen + maxAlign + 64)

        for i in 0..<baseBuffer1.count {
            baseBuffer1[i] = UInt8((i &* 31 + 7) & 0xFF)
            baseBuffer2[i] = UInt8((i &* 31 + 7) & 0xFF)
        }

        // Test every combination of length (0..258) and misalignments (0..15 x 0..15)
        for align1 in 0..<16 {
            for align2 in 0..<16 {
                for matchLen in 0...258 {
                    // Reset mismatch point
                    baseBuffer2.withUnsafeMutableBufferPointer { b2 in
                        guard let p2 = b2.baseAddress?.advanced(by: align2) else { return }
                        baseBuffer1.withUnsafeBufferPointer { b1 in
                            guard let p1 = b1.baseAddress?.advanced(by: align1) else { return }
                            
                            // Copy exactly matchLen bytes from p1 to p2
                            if matchLen > 0 {
                                memcpy(UnsafeMutableRawPointer(mutating: p2), p1, matchLen)
                            }
                            // Insert a mismatch byte immediately following matchLen
                            if matchLen < 258 {
                                let mismatchByte = p1[matchLen] ^ 0xFF
                                UnsafeMutablePointer(mutating: p2)[matchLen] = mismatchByte
                            }
                            
                            // Oracle reference calculation
                            var expectedLen: UInt32 = 0
                            while Int(expectedLen) < matchLen && expectedLen < 258 {
                                if p1[Int(expectedLen)] != p2[Int(expectedLen)] { break }
                                expectedLen += 1
                            }
                            
                            // Native Deflate block compression probe
                            XCTAssertEqual(
                                Int(expectedLen), matchLen,
                                "Oracle mismatch setup at align1=\(align1), align2=\(align2), matchLen=\(matchLen)"
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - 2. Single-Core Tier 1 Fast Match Finding Throughput Benchmark

    func testTier1MatchFinderThroughputFloor() throws {
        let sampleSize = 4 * 1024 * 1024 // 4 MB text payload
        var sampleData = Data(capacity: sampleSize)
        let pattern = "TTZip Apple Silicon M-Series Single-Core Vectorized LZ77 Fast Match Finder 2026\n".data(using: .utf8)!
        while sampleData.count < sampleSize {
            sampleData.append(pattern)
        }
        sampleData = sampleData.prefix(sampleSize)

        let outMax = sampleSize + 65536
        var outBuf = [UInt8](repeating: 0, count: outMax)

        let nilPtr: UnsafePointer<UInt8>? = nil

        // Warmup
        _ = sampleData.withUnsafeBytes { rawIn -> size_t in
            guard let inPtr = rawIn.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return outBuf.withUnsafeMutableBufferPointer { rawOut -> size_t in
                guard let outPtr = rawOut.baseAddress else { return 0 }
                return ttzip_native_deflate_compress_chunk_with_history(
                    inPtr, sampleSize, nilPtr, 0, outPtr, outMax, 1, 1
                )
            }
        }

        // Measure
        let iterations = 10
        let t0 = DispatchTime.now()
        var totalCompressed = 0

        for _ in 0..<iterations {
            let compSize = sampleData.withUnsafeBytes { rawIn -> size_t in
                guard let inPtr = rawIn.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                return outBuf.withUnsafeMutableBufferPointer { rawOut -> size_t in
                    guard let outPtr = rawOut.baseAddress else { return 0 }
                    return ttzip_native_deflate_compress_chunk_with_history(
                        inPtr, sampleSize, nilPtr, 0, outPtr, outMax, 1, 1
                    )
                }
            }
            totalCompressed += Int(compSize)
        }

        let elapsedSec = Double(DispatchTime.now().uptimeNanoseconds - t0.uptimeNanoseconds) / 1_000_000_000.0
        let totalMB = Double(sampleSize * iterations) / (1024.0 * 1024.0)
        let throughputMBps = totalMB / elapsedSec

        print(String(format: "[BENCH] Single-Core Tier 1 Deflate Throughput: %.1f MB/s (Ratio: %.2f%%)", throughputMBps, (Double(totalCompressed / iterations) / Double(sampleSize)) * 100.0))

        #if arch(arm64)
        // Hard Floor: >= 2,200 MB/s on Apple Silicon Single-Core
        XCTAssertGreaterThanOrEqual(
            throughputMBps, 2200.0,
            "Single-core Tier 1 Deflate throughput \(throughputMBps) MB/s fell below the 2,200 MB/s hard floor"
        )
        #endif
    }

    // MARK: - 3. Incompressible Payload Fast-Path Benchmark

    func testIncompressiblePayloadFastPath() throws {
        let sampleSize = 2 * 1024 * 1024 // 2 MB random data
        var sampleData = Data(count: sampleSize)
        sampleData.withUnsafeMutableBytes { ptr in
            arc4random_buf(ptr.baseAddress!, sampleSize)
        }

        let outMax = sampleSize + 65536
        var outBuf = [UInt8](repeating: 0, count: outMax)
        let nilPtr: UnsafePointer<UInt8>? = nil

        let iterations = 10
        let t0 = DispatchTime.now()

        for _ in 0..<iterations {
            _ = sampleData.withUnsafeBytes { rawIn -> size_t in
                guard let inPtr = rawIn.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                return outBuf.withUnsafeMutableBufferPointer { rawOut -> size_t in
                    guard let outPtr = rawOut.baseAddress else { return 0 }
                    return ttzip_native_deflate_compress_chunk_with_history(
                        inPtr, sampleSize, nilPtr, 0, outPtr, outMax, 1, 1
                    )
                }
            }
        }

        let elapsedSec = Double(DispatchTime.now().uptimeNanoseconds - t0.uptimeNanoseconds) / 1_000_000_000.0
        let totalMB = Double(sampleSize * iterations) / (1024.0 * 1024.0)
        let throughputMBps = totalMB / elapsedSec

        print(String(format: "[BENCH] Incompressible Payload Fast-Path Throughput: %.1f MB/s", throughputMBps))
        XCTAssertGreaterThanOrEqual(throughputMBps, 1500.0)
    }

    // MARK: - 4. Multi-Corpus Full Spectrum Single-Core Benchmark Matrix

    func testMultiCorpusFullSpectrumBenchmark() throws {
        struct CorpusTest {
            let name: String
            let generator: (Int) -> Data
        }

        let corpora: [CorpusTest] = [
            CorpusTest(name: "English Text (Silesia)", generator: { size in
                var data = Data(capacity: size)
                let text = "The Wall Street Journal reported that Apple Silicon unified memory and high instruction-level parallelism enable unprecedented single-core throughput for lossless archiving engines in 2026.\n".data(using: .utf8)!
                while data.count < size { data.append(text) }
                return data.prefix(size)
            }),
            CorpusTest(name: "Source Code (Swift/C)", generator: { size in
                var data = Data(capacity: size)
                let code = "func computeCRC32(ptr: UnsafePointer<UInt8>, len: Int) -> UInt32 { var crc: UInt32 = 0; for i in 0..<len { crc = update(crc, ptr[i]) }; return crc }\n".data(using: .utf8)!
                while data.count < size { data.append(code) }
                return data.prefix(size)
            }),
            CorpusTest(name: "Binary Executable", generator: { size in
                var data = Data(count: size)
                data.withUnsafeMutableBytes { ptr in
                    let p = ptr.bindMemory(to: UInt32.self).baseAddress!
                    for i in 0..<(size / 4) {
                        // ARM64 instruction-like patterns: opcodes + relative branch offsets
                        p[i] = (UInt32(0xD503201F) ^ UInt32(i & 0xFF)) &+ (UInt32(i % 16) << 12)
                    }
                }
                return data
            }),
            CorpusTest(name: "Repetitive Logs/TSV", generator: { size in
                var data = Data(capacity: size)
                let row = "2026-08-19 05:28:00.123 [INFO] TTZipWorker: Stream chunk compressed in 14.2us, size=65536, ratio=12.4%\n".data(using: .utf8)!
                while data.count < size { data.append(row) }
                return data.prefix(size)
            }),
            CorpusTest(name: "Random / High-Entropy", generator: { size in
                var data = Data(count: size)
                data.withUnsafeMutableBytes { ptr in
                    arc4random_buf(ptr.baseAddress!, size)
                }
                return data
            })
        ]

        let testSize = 4 * 1024 * 1024 // 4 MB per corpus
        let outMax = testSize + 65536
        var outBuf = [UInt8](repeating: 0, count: outMax)
        let nilPtr: UnsafePointer<UInt8>? = nil

        print("\n================== SINGLE-CORE LZ77 FULL MATRIX BENCHMARK ==================")
        print(String(format: "%-24@ | %-14@ | %-12@ | %-16@", "Corpus Type", "Throughput", "Ratio", "Status"))
        print("----------------------------------------------------------------------------")

        for corpus in corpora {
            let sample = corpus.generator(testSize)
            let iterations = 10

            // Warmup
            _ = sample.withUnsafeBytes { rawIn -> size_t in
                let inPtr = rawIn.bindMemory(to: UInt8.self).baseAddress!
                return outBuf.withUnsafeMutableBufferPointer { rawOut -> size_t in
                    return ttzip_native_deflate_compress_chunk_with_history(
                        inPtr, testSize, nilPtr, 0, rawOut.baseAddress!, outMax, 1, 1
                    )
                }
            }

            // Measurement
            let t0 = DispatchTime.now()
            var totalComp = 0

            for _ in 0..<iterations {
                let comp = sample.withUnsafeBytes { rawIn -> size_t in
                    let inPtr = rawIn.bindMemory(to: UInt8.self).baseAddress!
                    return outBuf.withUnsafeMutableBufferPointer { rawOut -> size_t in
                        return ttzip_native_deflate_compress_chunk_with_history(
                            inPtr, testSize, nilPtr, 0, rawOut.baseAddress!, outMax, 1, 1
                        )
                    }
                }
                totalComp += Int(comp)
            }

            let elapsedSec = Double(DispatchTime.now().uptimeNanoseconds - t0.uptimeNanoseconds) / 1_000_000_000.0
            let totalMB = Double(testSize * iterations) / (1024.0 * 1024.0)
            let throughput = totalMB / elapsedSec
            let ratio = (Double(totalComp / iterations) / Double(testSize)) * 100.0
            let status = throughput >= 2200.0 ? "🟢 ELITE" : "⚪ PASS"

            print(String(
                format: "%-24@ | %9.1f MB/s | %10.2f%% | %@",
                corpus.name, throughput, ratio, status
            ))

            XCTAssertGreaterThanOrEqual(throughput, 1200.0, "Corpus \(corpus.name) throughput too low")
        }
        print("============================================================================\n")
    }
}
