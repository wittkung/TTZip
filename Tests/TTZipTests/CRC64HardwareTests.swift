import XCTest
import CTTZipBridge
@testable import TTZipCore

@_silgen_name("lzma_crc64")
private func lzma_crc64(_ buf: UnsafePointer<UInt8>?, _ size: Int, _ crc: UInt64) -> UInt64

final class CRC64HardwareTests: XCTestCase {

    // MARK: - 1. 黄金测试向量与系统预言机对比测试 (Golden Test Vector & Oracle Validation)

    func testGoldenVectorAndDifferential() {
        let ascii9 = "123456789".data(using: .utf8)!
        let expectedXZCRC: UInt64 = 0x995DC9BBDF1939FA

        // 1. 系统黄金预言机 lzma_crc64
        let computedLZMA = ascii9.withUnsafeBytes { raw in
            lzma_crc64(raw.baseAddress?.assumingMemoryBound(to: UInt8.self), raw.count, 0)
        }
        XCTAssertEqual(computedLZMA, expectedXZCRC, "lzma_crc64 oracle value mismatch!")

        // 2. Swift Data 封装
        let computedSwift = CRC64Checksum.calculate(for: ascii9)
        XCTAssertEqual(computedSwift, expectedXZCRC, "CRC64 (Swift Data) for '123456789' mismatch!")

        // 3. C 原生自动分发接口
        let computedC = ascii9.withUnsafeBytes { raw in
            ttzip_crc64(raw.baseAddress?.assumingMemoryBound(to: UInt8.self), raw.count, 0)
        }
        XCTAssertEqual(computedC, expectedXZCRC, "CRC64 (C ttzip_crc64) for '123456789' mismatch!")

        // 4. PMULL 硬件加速接口
        let computedPMULL = ascii9.withUnsafeBytes { raw in
            ttzip_crc64_pmull(raw.baseAddress?.assumingMemoryBound(to: UInt8.self), raw.count, 0)
        }
        XCTAssertEqual(computedPMULL, expectedXZCRC, "CRC64 (ttzip_crc64_pmull) for '123456789' mismatch!")

        // 5. 标量查表接口
        let computedScalar = ascii9.withUnsafeBytes { raw in
            ttzip_crc64_scalar(raw.baseAddress?.assumingMemoryBound(to: UInt8.self), raw.count, 0)
        }
        XCTAssertEqual(computedScalar, expectedXZCRC, "CRC64 (ttzip_crc64_scalar) for '123456789' mismatch!")
    }

    // MARK: - 2. 零长度与边界条件确界 (Boundary & Invariant Safety)

    func testZeroLengthAndNull() {
        let emptyData = Data()
        let seed: UInt64 = 0x123456789ABCDEF0

        XCTAssertEqual(CRC64Checksum.calculate(for: emptyData, seed: seed), seed)
        XCTAssertEqual(ttzip_crc64(nil, 0, seed), seed)
        XCTAssertEqual(ttzip_crc64_pmull(nil, 0, seed), seed)
        XCTAssertEqual(ttzip_crc64_scalar(nil, 0, seed), seed)
    }

    // MARK: - 3. 0~256 字节穷举差分比对 (Exhaustive Differential Testing)

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

    // MARK: - 4. 任意非对齐内存切片差分 (Unaligned & Multi-Slice Safety)

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

    // MARK: - 5. 10MB 吞吐性能门禁测试 (Throughput Performance Floor Gate)

    func testThroughputPerformanceFloor() {
        let bufferSize = 10 * 1024 * 1024 // 10MB
        var testData = [UInt8](repeating: 0xAB, count: bufferSize)
        for i in 0..<1024 {
            testData[i] = UInt8(i & 0xFF)
        }

        // 预热 (Warm-up)
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

        print(String(format: "=== [CRC64 Hardware PMULL] 10MB Buffer Throughput: %.1f MB/s (Elapsed: %.4f s, Checksum: %016llX) ===", throughputMBps, elapsed, checksum))

        #if arch(arm64)
        #if DEBUG
        let floorMBps: Double = 25000.0
        #else
        let floorMBps: Double = 35000.0
        #endif
        XCTAssertGreaterThanOrEqual(throughputMBps, floorMBps, "ARM64 PMULL CRC64 throughput \(throughputMBps) MB/s fell below hard floor \(floorMBps) MB/s!")
        #endif
    }

    // MARK: - 6. 全矩阵差分对比基准测试 (Comparative Speedup Benchmark)

    func testComparativeSpeedupBenchmark() {
        let scenarios: [(name: String, size: Int, iterations: Int)] = [
            ("64 KB 短切片", 64 * 1024, 2000),
            ("1 MB 中等缓冲", 1 * 1024 * 1024, 500),
            ("10 MB 标准块", 10 * 1024 * 1024, 100),
            ("50 MB 大文件", 50 * 1024 * 1024, 20)
        ]

        print("\n=========================================================================================================")
        print("                 TTZip ARM64 PMULL CRC64 硬件加速 vs 标量基准实测性能比对表")
        print("=========================================================================================================")
        print(String(format: "%-16@ | %-12@ | %-18@ | %-18@ | %-18@ | %-12@", "测试场景", "单次载荷", "基线 (lzma_crc64)", "标量 (Slice-by-8)", "PMULL 硬件加速", "加速比 (Speedup)"))
        print("---------------------------------------------------------------------------------------------------------")

        for s in scenarios {
            var data = [UInt8](repeating: 0x5A, count: s.size)
            for i in 0..<min(s.size, 4096) {
                data[i] = UInt8(i & 0xFF)
            }

            data.withUnsafeBufferPointer { bufPtr in
                guard let base = bufPtr.baseAddress else { return }

                // 1. 基线 lzma_crc64
                _ = lzma_crc64(base, s.size, 0)
                let t0 = CFAbsoluteTimeGetCurrent()
                for _ in 0..<s.iterations {
                    _ = lzma_crc64(base, s.size, 0)
                }
                let elapsedLZMA = CFAbsoluteTimeGetCurrent() - t0
                let mbLZMA = (Double(s.size * s.iterations) / (1024.0 * 1024.0)) / elapsedLZMA

                // 2. 标量 Slice-by-8
                _ = ttzip_crc64_scalar(base, s.size, 0)
                let t1 = CFAbsoluteTimeGetCurrent()
                for _ in 0..<s.iterations {
                    _ = ttzip_crc64_scalar(base, s.size, 0)
                }
                let elapsedScalar = CFAbsoluteTimeGetCurrent() - t1
                let mbScalar = (Double(s.size * s.iterations) / (1024.0 * 1024.0)) / elapsedScalar

                // 3. PMULL 硬件加速
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

                print(String(format: "%-16@ | %-12@ | %-18@ | %-18@ | %-18@ | %-12@", s.name as NSString, sizeStr as NSString, lzmaStr as NSString, scalarStr as NSString, pmullStr as NSString, speedupStr as NSString))
            }
        }
        print("=========================================================================================================\n")
    }
}
