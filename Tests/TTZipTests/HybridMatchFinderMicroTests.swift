// Tests/TTZipTests/HybridMatchFinderMicroTests.swift
// TTZip Hybrid SWAR/NEON Match Finder Micro-Architecture Tests & Benchmarks

import XCTest
import CTTZipBridge
@testable import TTZipCore

final class HybridMatchFinderMicroTests: XCTestCase {

    // MARK: - 1. Exhaustive Prefix Match Length Correctness (0 to 273 Bytes)

    func testPrefixMatchLengthSweepFrom0To273() throws {
        let maxTestLength = 300
        var baseBuffer = [UInt8](repeating: 0x41, count: maxTestLength) // 'A'
        for i in 0..<maxTestLength {
            baseBuffer[i] = UInt8(i % 251) // pseudo-random deterministic sequence
        }

        baseBuffer.withUnsafeBytes { rawBase in
            let basePtr = rawBase.baseAddress!.assumingMemoryBound(to: UInt8.self)

            // Test every exact match length target from 0 to 273
            for targetMatchLen in 0...273 {
                var candidateBuffer = [UInt8](baseBuffer)
                if targetMatchLen < maxTestLength {
                    // Introduce a deliberate mismatch at targetMatchLen
                    candidateBuffer[targetMatchLen] ^= 0xFF
                }

                candidateBuffer.withUnsafeBytes { rawCand in
                    let candPtr = rawCand.baseAddress!.assumingMemoryBound(to: UInt8.self)

                    // Test with max_len = 273 (LZMA max)
                    let found273 = ttzip_hybrid_match_len_neon(basePtr, candPtr, 273)
                    let expected273 = min(UInt32(targetMatchLen), 273)
                    XCTAssertEqual(
                        found273, expected273,
                        "Target match length \(targetMatchLen) with max_len=273 failed: got \(found273), expected \(expected273)"
                    )

                    // Test with max_len = 258 (Deflate max)
                    let found258 = ttzip_hybrid_match_len_neon(basePtr, candPtr, 258)
                    let expected258 = min(UInt32(targetMatchLen), 258)
                    XCTAssertEqual(
                        found258, expected258,
                        "Target match length \(targetMatchLen) with max_len=258 failed: got \(found258), expected \(expected258)"
                    )

                    // Test with exact max_len = targetMatchLen
                    if targetMatchLen > 0 {
                        let foundExact = ttzip_hybrid_match_len_neon(basePtr, candPtr, UInt32(targetMatchLen))
                        XCTAssertEqual(
                            foundExact, UInt32(targetMatchLen),
                            "Exact max_len \(targetMatchLen) failed: got \(foundExact)"
                        )
                    }

                    // Test backward compatibility alias ttzip_match_len_neon
                    let legacyFound = ttzip_match_len_neon(basePtr, candPtr, 273)
                    XCTAssertEqual(legacyFound, found273, "Legacy wrapper must return identical match length")
                }
            }
        }
    }

    // MARK: - 2. Edge Cases & Boundary Clamping

    func testEdgeCasesAndBoundsSafety() {
        let buf1: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8]
        let buf2: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8]

        buf1.withUnsafeBytes { r1 in
            let p1 = r1.baseAddress!.assumingMemoryBound(to: UInt8.self)
            buf2.withUnsafeBytes { r2 in
                let p2 = r2.baseAddress!.assumingMemoryBound(to: UInt8.self)

                // max_len = 0
                XCTAssertEqual(ttzip_hybrid_match_len_neon(p1, p2, 0), 0)

                // Short max_len < 8
                for limit in 1...7 {
                    let res = ttzip_hybrid_match_len_neon(p1, p2, UInt32(limit))
                    XCTAssertEqual(res, UInt32(limit), "Short max_len \(limit) should match exactly \(limit)")
                }

                // NULL pointers
                XCTAssertEqual(ttzip_hybrid_match_len_neon(nil, p2, 10), 0)
                XCTAssertEqual(ttzip_hybrid_match_len_neon(p1, nil, 10), 0)
            }
        }
    }

    // MARK: - 3. Unaligned Memory Pointers

    func testUnalignedPointerAccess() {
        let bufferSize = 1024
        var masterBuffer = [UInt8](repeating: 0, count: bufferSize)
        for i in 0..<bufferSize {
            masterBuffer[i] = UInt8((i * 37 + 13) & 0xFF)
        }

        masterBuffer.withUnsafeBytes { rawMaster in
            let masterPtr = rawMaster.baseAddress!.assumingMemoryBound(to: UInt8.self)

            // Test various unaligned offsets (1, 2, 3, 5, 7, 9, 11, 13, 15)
            let offsets = [0, 1, 2, 3, 4, 5, 7, 9, 11, 13, 15]
            for off1 in offsets {
                for off2 in offsets {
                    let ptr1 = masterPtr.advanced(by: off1)
                    let ptr2 = masterPtr.advanced(by: off2)

                    let maxLen: UInt32 = 258
                    let res = ttzip_hybrid_match_len_neon(ptr1, ptr2, maxLen)

                    // Reference scalar calculation
                    var expected: UInt32 = 0
                    while expected < maxLen && ptr1[Int(expected)] == ptr2[Int(expected)] {
                        expected += 1
                    }

                    XCTAssertEqual(
                        res, expected,
                        "Unaligned test off1=\(off1), off2=\(off2) failed: got \(res), expected \(expected)"
                    )
                }
            }
        }
    }

    // MARK: - 4. Contract Compliance Verification

    func testContractComplianceAgainstJsonSchema() {
        // Contract properties:
        // input: src0_offset >= 0, src1_offset >= 0, max_len in [0, 273], nice_len in [3, 273]
        // result: match_length in [0, 273], dispatch_path in ["swar_gpr", "neon_vector", "scalar_tail"]

        let testPattern: [UInt8] = Array(repeating: 0x55, count: 512)
        testPattern.withUnsafeBytes { raw in
            let ptr = raw.baseAddress!.assumingMemoryBound(to: UInt8.self)

            let sampleConfigs: [(offset0: Int, offset1: Int, maxLen: UInt32, niceLen: UInt32)] = [
                (0, 0, 273, 32),
                (0, 8, 258, 258),
                (3, 7, 128, 16),
                (1, 1, 64, 8),
                (0, 0, 0, 3),
                (16, 32, 273, 273)
            ]

            for cfg in sampleConfigs {
                let p0 = ptr.advanced(by: cfg.offset0)
                let p1 = ptr.advanced(by: cfg.offset1)
                let matchLen = ttzip_hybrid_match_len_neon(p0, p1, cfg.maxLen)

                // Contract assertion: match_length must be in [0, max_len] and [0, 273]
                XCTAssertGreaterThanOrEqual(matchLen, 0)
                XCTAssertLessThanOrEqual(matchLen, cfg.maxLen)
                XCTAssertLessThanOrEqual(matchLen, 273)
            }
        }
    }

    // MARK: - 5. Micro-Benchmark: Short Match Fast-Fail vs Long Match NEON Unrolling

    func testMicroBenchmarkHybridMatcherPerformance() {
        let iterations = 2_000_000

        // Case A: Short Match (< 8 bytes, representative of >80% of LZ77 comparisons)
        let shortTarget: [UInt8] = [0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xAA]
        let shortCand: [UInt8]   = [0x11, 0x22, 0x33, 0x44, 0xEE, 0x66, 0x77, 0x88, 0x99, 0xAA] // Mismatch at byte 4

        var shortTotalLen: UInt32 = 0
        let startShort = CFAbsoluteTimeGetCurrent()
        shortTarget.withUnsafeBytes { rTarget in
            let pTarget = rTarget.baseAddress!.assumingMemoryBound(to: UInt8.self)
            shortCand.withUnsafeBytes { rCand in
                let pCand = rCand.baseAddress!.assumingMemoryBound(to: UInt8.self)
                for _ in 0..<iterations {
                    shortTotalLen &+= ttzip_hybrid_match_len_neon(pTarget, pCand, 258)
                }
            }
        }
        let elapsedShort = CFAbsoluteTimeGetCurrent() - startShort
        let shortOpsPerSec = Double(iterations) / elapsedShort
        XCTAssertEqual(shortTotalLen, UInt32(iterations * 4))

        // Case B: Long Match (258 bytes, Deflate maximum length)
        let longTarget: [UInt8] = Array(repeating: 0x7A, count: 300)
        let longCand: [UInt8]   = Array(repeating: 0x7A, count: 300)

        var longTotalLen: UInt32 = 0
        let startLong = CFAbsoluteTimeGetCurrent()
        longTarget.withUnsafeBytes { rTarget in
            let pTarget = rTarget.baseAddress!.assumingMemoryBound(to: UInt8.self)
            longCand.withUnsafeBytes { rCand in
                let pCand = rCand.baseAddress!.assumingMemoryBound(to: UInt8.self)
                for _ in 0..<iterations {
                    longTotalLen &+= ttzip_hybrid_match_len_neon(pTarget, pCand, 258)
                }
            }
        }
        let elapsedLong = CFAbsoluteTimeGetCurrent() - startLong
        let longOpsPerSec = Double(iterations) / elapsedLong
        XCTAssertEqual(longTotalLen, UInt32(iterations * 258))

        print("\n=======================================================")
        print("  [Hybrid Match Finder Micro-Benchmark]")
        print("  - Short Match (<8B GPR Fast-Fail):")
        print("      * Iterations: \(iterations)")
        print("      * Elapsed:    \(String(format: "%.4f", elapsedShort)) s")
        print("      * Rate:       \(String(format: "%.2f", shortOpsPerSec / 1_000_000.0)) M comparisons/s")
        print("  - Long Match (258B NEON Vector Unroll):")
        print("      * Iterations: \(iterations)")
        print("      * Elapsed:    \(String(format: "%.4f", elapsedLong)) s")
        print("      * Rate:       \(String(format: "%.2f", longOpsPerSec / 1_000_000.0)) M comparisons/s")
        print("=======================================================\n")

        #if DEBUG
        XCTAssertGreaterThan(shortOpsPerSec, 10_000_000.0, "Short match fast-fail rate in Debug must exceed 10M ops/s")
        XCTAssertGreaterThan(longOpsPerSec, 4_000_000.0, "Long match 258B rate in Debug must exceed 4M ops/s")
        #else
        XCTAssertGreaterThan(shortOpsPerSec, 20_000_000.0, "Short match fast-fail rate in Release must exceed 20M ops/s")
        XCTAssertGreaterThan(longOpsPerSec, 10_000_000.0, "Long match 258B rate in Release must exceed 10M ops/s")
        #endif
    }

    // MARK: - 6. Double-Fast Dual-Table Match Finder Verification

    func testDoubleFastDualTableMatchFinder() throws {
        // Create repeated pattern data: "0123456789ABCDEF" repeated
        let pattern: [UInt8] = Array("0123456789ABCDEF0123456789ABCDEF".utf8)
        var buffer: [UInt8] = []
        for _ in 0..<100 {
            buffer.append(contentsOf: pattern)
        }

        buffer.withUnsafeBytes { raw in
            let ptr = raw.baseAddress!.assumingMemoryBound(to: UInt8.self)
            var df = ttzip_double_fast_t()

            // 1. Test standard init
            let initRes = ttzip_double_fast_init(&df, ptr, UInt32(buffer.count), 65536, 32)
            XCTAssertEqual(initRes, 0, "Double-Fast init should succeed")

            var matches = [ttzip_match_t](repeating: ttzip_match_t(len: 0, dist: 0), count: 16)
            var matchCount: UInt32 = 0

            // Skip first pattern
            ttzip_double_fast_skip(&df, 32)

            // Search matches in second repetition
            matchCount = ttzip_double_fast_get_matches(&df, &matches, 16)
            XCTAssertGreaterThan(matchCount, 0, "Should find matches on repeated pattern")
            if matchCount > 0 {
                XCTAssertGreaterThanOrEqual(matches[0].len, 4, "Found match length should be >= 4")
            }

            ttzip_double_fast_free(&df)

            // 2. Test workspace-backed zero-allocation init
            let workspaceSize = 2 * 65536 * MemoryLayout<UInt32>.size // 512KB
            let workspace = UnsafeMutableRawPointer.allocate(byteCount: workspaceSize, alignment: 16)
            defer { workspace.deallocate() }

            var dfWorkspace = ttzip_double_fast_t()
            let initWsRes = ttzip_double_fast_init_workspace(
                &dfWorkspace, ptr, UInt32(buffer.count), 65536, 32, workspace, workspaceSize
            )
            XCTAssertEqual(initWsRes, 0, "Double-Fast workspace init should succeed")
            XCTAssertFalse(dfWorkspace.owns_workspace, "Should not own caller-provided workspace")

            ttzip_double_fast_skip(&dfWorkspace, 32)
            let wsMatchCount = ttzip_double_fast_get_matches(&dfWorkspace, &matches, 16)
            XCTAssertGreaterThan(wsMatchCount, 0, "Workspace Double-Fast should find matches")

            ttzip_double_fast_free(&dfWorkspace)
        }
    }
}
