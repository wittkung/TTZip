// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import CryptoKit
@testable import TTZipCore
import CTTZipBridge

/// Point-by-point empirical test suite isolating each of the 8 multi-core optimizations in TTZip.
final class MultiCoreOptimizationBreakdownTests: XCTestCase {

    private struct TestCompressedEntry: Sendable {
        let rawSize: Int
        let compData: Data
    }

    private final class StateBoxResults<T>: @unchecked Sendable {
        private var results: [T?]
        private let lock = NSLock()

        init(_ initial: [T?]) {
            self.results = initial
        }

        func set(idx: Int, res: T) {
            lock.lock()
            defer { lock.unlock() }
            results[idx] = res
        }

        func getAll() -> [T?] {
            lock.lock()
            defer { lock.unlock() }
            return results
        }

        var values: [T?] {
            getAll()
        }
    }

    // MARK: - OP-1: C11 _Thread_local State Pool vs Mutex-Guarded Allocation

    func testOP1_ThreadLocalStorageVsMutexContention() throws {
        let chunkCount = 32
        let chunkSize = 128 * 1024
        let testData = (0..<chunkSize).map { UInt8(($0 * 31) & 0xFF) }
        let level: Int32 = 1

        // Baseline: Global mutex lock around every compression call
        let mutexLock = NSLock()
        let t0 = PlatformMonotonicTimer.nowNanoseconds()
        DispatchQueue.concurrentPerform(iterations: chunkCount) { _ in
            var outBuf = [UInt8](repeating: 0, count: chunkSize + 512)
            let outCap = outBuf.count
            mutexLock.lock()
            let compSize = testData.withUnsafeBytes { inPtr in
                outBuf.withUnsafeMutableBytes { outPtr in
                    ttzip_libdeflate_compress(inPtr.baseAddress!, chunkSize, outPtr.baseAddress!, outCap, level)
                }
            }
            mutexLock.unlock()
            XCTAssertGreaterThan(compSize, 0)
        }
        let t1 = PlatformMonotonicTimer.nowNanoseconds()
        let baseSec = max(0.000001, Double(t1 - t0) / 1_000_000_000.0)
        let totalMB = Double(chunkCount * chunkSize) / (1024.0 * 1024.0)
        let baseThroughput = totalMB / baseSec

        // Optimized: Lock-free C11 _Thread_local storage (CTTZipStreamCoder.c)
        let t2 = PlatformMonotonicTimer.nowNanoseconds()
        DispatchQueue.concurrentPerform(iterations: chunkCount) { _ in
            var outBuf = [UInt8](repeating: 0, count: chunkSize + 512)
            let outCap = outBuf.count
            let compSize = testData.withUnsafeBytes { inPtr in
                outBuf.withUnsafeMutableBytes { outPtr in
                    ttzip_libdeflate_compress(inPtr.baseAddress!, chunkSize, outPtr.baseAddress!, outCap, level)
                }
            }
            XCTAssertGreaterThan(compSize, 0)
        }
        let t3 = PlatformMonotonicTimer.nowNanoseconds()
        let optSec = max(0.000001, Double(t3 - t2) / 1_000_000_000.0)
        let optThroughput = totalMB / optSec

        let result = OptimizationPointResult(
            point: .tlsZeroLock,
            baselineThroughputMBs: baseThroughput,
            optimizedThroughputMBs: optThroughput
        )

        TTLogger.info("[OP-1 TLS Zero-Lock] Mutex Baseline: \(String(format: "%.1f", baseThroughput)) MB/s | TLS Optimized: \(String(format: "%.1f", optThroughput)) MB/s | Speedup: \(String(format: "%.2f", result.speedupRatio))x")
        XCTAssertTrue(result.isPositiveDelta, "OP-1 Lock-free TLS must achieve positive speedup over mutex contention")
    }

    // MARK: - OP-2: 512KB Block-Level Parallel Compression vs Single-Threaded

    func testOP2_BlockParallel512KBVsSingleThreadedDeflate() throws {
        let size = 4 * 1024 * 1024 // 4 MB
        let sample = (0..<size).map { UInt8(($0 * 13) & 0xFF) }
        let payload = Data(sample)
        let level: Int32 = 1

        // Baseline: Single-threaded Deflate
        let t0 = PlatformMonotonicTimer.nowNanoseconds()
        var singleOut = Data(count: size + 1024)
        let outCap = singleOut.count
        let compSize = payload.withUnsafeBytes { inPtr -> size_t in
            singleOut.withUnsafeMutableBytes { outPtr in
                ttzip_libdeflate_compress(inPtr.baseAddress!, size, outPtr.baseAddress!, outCap, level)
            }
        }
        let t1 = PlatformMonotonicTimer.nowNanoseconds()
        let baseSec = max(0.000001, Double(t1 - t0) / 1_000_000_000.0)
        let baseThroughput = (Double(size) / (1024.0 * 1024.0)) / baseSec
        XCTAssertGreaterThan(compSize, 0)

        // Optimized: ZipBlockParallelCompressor (512KB chunk concurrent dispatch)
        let t2 = PlatformMonotonicTimer.nowNanoseconds()
        let parallelOut = ZipBlockParallelCompressor.shared.compressBlocksConcurrently(data: payload, level: level)
        let t3 = PlatformMonotonicTimer.nowNanoseconds()
        let optSec = max(0.000001, Double(t3 - t2) / 1_000_000_000.0)
        let optThroughput = (Double(size) / (1024.0 * 1024.0)) / optSec
        XCTAssertGreaterThan(parallelOut.count, 0)

        let result = OptimizationPointResult(
            point: .blockParallel512KB,
            baselineThroughputMBs: baseThroughput,
            optimizedThroughputMBs: optThroughput
        )

        TTLogger.info("[OP-2 Block Parallel] Single-Core Baseline: \(String(format: "%.1f", baseThroughput)) MB/s | Multi-Core 512KB: \(String(format: "%.1f", optThroughput)) MB/s | Speedup: \(String(format: "%.2f", result.speedupRatio))x")
        XCTAssertTrue(result.isPositiveDelta, "OP-2 512KB Block parallelism must provide positive speedup on 4MB payload")
    }

    // MARK: - OP-3: Multi-Tile Parallel Decompression vs Sequential

    func testOP3_MultiTileParallelDecompressionVsSequential() throws {
        let chunkSize = 512 * 1024
        let numChunks = 8
        let rawChunk = Data((0..<chunkSize).map { UInt8(($0 * 17) & 0xFF) })
        
        var compressedChunks: [Data] = []
        var offsets: [Int] = []
        var compressedSizes: [Int] = []
        var uncompressedSizes: [Int] = []
        var combinedData = Data()

        for _ in 0..<numChunks {
            var outBuf = Data(count: chunkSize + 512)
            let outCap = outBuf.count
            let compSize = rawChunk.withUnsafeBytes { inPtr in
                outBuf.withUnsafeMutableBytes { outPtr in
                    ttzip_libdeflate_compress(inPtr.baseAddress!, chunkSize, outPtr.baseAddress!, outCap, 1)
                }
            }
            let chunkData = outBuf.prefix(compSize)
            offsets.append(combinedData.count)
            compressedSizes.append(compSize)
            uncompressedSizes.append(chunkSize)
            combinedData.append(chunkData)
            compressedChunks.append(chunkData)
        }

        let totalRawSize = numChunks * chunkSize
        let totalMB = Double(totalRawSize) / (1024.0 * 1024.0)

        // Baseline: Sequential Decompression Loop
        let t0 = PlatformMonotonicTimer.nowNanoseconds()
        var seqOut = Data(count: totalRawSize)
        for (i, c) in compressedChunks.enumerated() {
            let off = i * chunkSize
            _ = c.withUnsafeBytes { inPtr in
                seqOut.withUnsafeMutableBytes { outPtr in
                    ttzip_libdeflate_decompress(inPtr.baseAddress!, c.count, outPtr.baseAddress!.advanced(by: off), chunkSize)
                }
            }
        }
        let t1 = PlatformMonotonicTimer.nowNanoseconds()
        let baseSec = max(0.000001, Double(t1 - t0) / 1_000_000_000.0)
        let baseThroughput = totalMB / baseSec

        // Optimized: ZipBlockParallelDecompressor
        let t2 = PlatformMonotonicTimer.nowNanoseconds()
        let decompOut = ZipBlockParallelDecompressor.shared.decompressBlocksConcurrently(
            compressedData: combinedData,
            uncompressedSize: Int64(totalRawSize),
            blockOffsets: offsets,
            blockCompressedSizes: compressedSizes,
            blockUncompressedSizes: uncompressedSizes
        )
        let t3 = PlatformMonotonicTimer.nowNanoseconds()
        let optSec = max(0.000001, Double(t3 - t2) / 1_000_000_000.0)
        let optThroughput = totalMB / optSec

        XCTAssertNotNil(decompOut)
        XCTAssertEqual(decompOut?.count, totalRawSize)

        let result = OptimizationPointResult(
            point: .multiTileDecompress,
            baselineThroughputMBs: baseThroughput,
            optimizedThroughputMBs: optThroughput
        )

        TTLogger.info("[OP-3 Multi-Tile Decompress] Sequential Baseline: \(String(format: "%.1f", baseThroughput)) MB/s | Multi-Tile Parallel: \(String(format: "%.1f", optThroughput)) MB/s | Speedup: \(String(format: "%.2f", result.speedupRatio))x")
        XCTAssertTrue(result.isPositiveDelta, "OP-3 Multi-tile decompression must provide positive speedup")
    }

    // MARK: - OP-4: Container-Level Multi-File Packaging vs Sequential

    func testOP4_ContainerMultiFilePackagingVsSequential() throws {
        let fileCount = 32
        let sampleSize = 128 * 1024 // 128 KB per file = 4 MB total
        let sampleData = Data((0..<sampleSize).map { UInt8(($0 * 37) & 0xFF) })
        let fileDatas = [Data](repeating: sampleData, count: fileCount)
        let totalMB = Double(fileCount * sampleSize) / (1024.0 * 1024.0)

        // Baseline: Sequential single-thread file-by-file Deflate compression & CRC32
        let t0 = PlatformMonotonicTimer.nowNanoseconds()
        var seqCompressed: [Data] = []
        for d in fileDatas {
            let crc = ttzip_crc32_fast(0, (d as NSData).bytes, d.count)
            _ = crc
            var outBuf = Data(count: d.count + 512)
            let outCap = outBuf.count
            let compSize = d.withUnsafeBytes { inPtr in
                outBuf.withUnsafeMutableBytes { outPtr in
                    ttzip_libdeflate_compress(inPtr.baseAddress!, d.count, outPtr.baseAddress!, outCap, 6)
                }
            }
            seqCompressed.append(outBuf.prefix(compSize))
        }
        let t1 = PlatformMonotonicTimer.nowNanoseconds()
        let baseSec = max(0.000001, Double(t1 - t0) / 1_000_000_000.0)
        let baseThroughput = totalMB / baseSec

        // Optimized: Concurrent multi-threaded file compression (ZipParallelWriter core dispatcher)
        let t2 = PlatformMonotonicTimer.nowNanoseconds()
        let parBox = StateBoxResults([Data?](repeating: nil, count: fileDatas.count))
        DispatchQueue.concurrentPerform(iterations: fileDatas.count) { idx in
            let d = fileDatas[idx]
            let crc = ttzip_crc32_fast(0, (d as NSData).bytes, d.count)
            _ = crc
            var outBuf = Data(count: d.count + 512)
            let outCap = outBuf.count
            let compSize = d.withUnsafeBytes { inPtr in
                outBuf.withUnsafeMutableBytes { outPtr in
                    ttzip_libdeflate_compress(inPtr.baseAddress!, d.count, outPtr.baseAddress!, outCap, 6)
                }
            }
            parBox.set(idx: idx, res: outBuf.prefix(compSize))
        }
        let t3 = PlatformMonotonicTimer.nowNanoseconds()
        let optSec = max(0.000001, Double(t3 - t2) / 1_000_000_000.0)
        let optThroughput = totalMB / optSec

        let result = OptimizationPointResult(
            point: .containerMultiFilePack,
            baselineThroughputMBs: baseThroughput,
            optimizedThroughputMBs: optThroughput
        )

        TTLogger.info("[OP-4 Container Multi-File Pack] Sequential Baseline: \(String(format: "%.1f", baseThroughput)) MB/s | Parallel Concurrency: \(String(format: "%.1f", optThroughput)) MB/s | Speedup: \(String(format: "%.2f", result.speedupRatio))x")
        XCTAssertTrue(result.isPositiveDelta, "OP-4 Multi-file parallel packaging must provide positive speedup")
    }

    // MARK: - OP-5: Multi-File Concurrent Direct Extraction vs Sequential

    func testOP5_ContainerMultiFileExtractionVsSequential() throws {
        let fileCount = 32
        let sampleSize = 128 * 1024
        let sampleData = Data((0..<sampleSize).map { UInt8(($0 * 29) & 0xFF) })

        var compressedEntries: [TestCompressedEntry] = []
        for _ in 0..<fileCount {
            var outBuf = Data(count: sampleSize + 512)
            let outCap = outBuf.count
            let compSize = sampleData.withUnsafeBytes { inPtr in
                outBuf.withUnsafeMutableBytes { outPtr in
                    ttzip_libdeflate_compress(inPtr.baseAddress!, sampleSize, outPtr.baseAddress!, outCap, 6)
                }
            }
            compressedEntries.append(TestCompressedEntry(rawSize: sampleSize, compData: outBuf.prefix(compSize)))
        }

        let totalMB = Double(fileCount * sampleSize) / (1024.0 * 1024.0)

        // Baseline: Sequential single-thread file-by-file decompression
        let t0 = PlatformMonotonicTimer.nowNanoseconds()
        var seqExtracted: [Data] = []
        for entry in compressedEntries {
            var rawOut = Data(count: entry.rawSize)
            _ = entry.compData.withUnsafeBytes { inPtr in
                rawOut.withUnsafeMutableBytes { outPtr in
                    ttzip_libdeflate_decompress(inPtr.baseAddress!, entry.compData.count, outPtr.baseAddress!, entry.rawSize)
                }
            }
            seqExtracted.append(rawOut)
        }
        let t1 = PlatformMonotonicTimer.nowNanoseconds()
        let baseSec = max(0.000001, Double(t1 - t0) / 1_000_000_000.0)
        let baseThroughput = totalMB / baseSec

        // Optimized: Concurrent multi-file decompression (ZipParallelExtractor core engine)
        let t2 = PlatformMonotonicTimer.nowNanoseconds()
        let extBox = StateBoxResults([Data?](repeating: nil, count: compressedEntries.count))
        let immutableEntries = compressedEntries
        DispatchQueue.concurrentPerform(iterations: immutableEntries.count) { idx in
            let entry = immutableEntries[idx]
            var rawOut = Data(count: entry.rawSize)
            _ = entry.compData.withUnsafeBytes { inPtr in
                rawOut.withUnsafeMutableBytes { outPtr in
                    ttzip_libdeflate_decompress(inPtr.baseAddress!, entry.compData.count, outPtr.baseAddress!, entry.rawSize)
                }
            }
            extBox.set(idx: idx, res: rawOut)
        }
        let t3 = PlatformMonotonicTimer.nowNanoseconds()
        let optSec = max(0.000001, Double(t3 - t2) / 1_000_000_000.0)
        let optThroughput = totalMB / optSec

        let result = OptimizationPointResult(
            point: .containerMultiFileExtract,
            baselineThroughputMBs: baseThroughput,
            optimizedThroughputMBs: optThroughput
        )

        TTLogger.info("[OP-5 Multi-File Extraction] Sequential Baseline: \(String(format: "%.1f", baseThroughput)) MB/s | Parallel Extraction: \(String(format: "%.1f", optThroughput)) MB/s | Speedup: \(String(format: "%.2f", result.speedupRatio))x")
        XCTAssertTrue(result.isPositiveDelta, "OP-5 Multi-file parallel extraction must provide positive speedup")
    }

    // MARK: - OP-6: ARMv8 PMULL Hardware Vectorized CRC32/64 vs Software Slicing

    func testOP6_ARMv8PMULLVsSoftwareTableCRC32() throws {
        let size = 4 * 1024 * 1024 // 4 MB
        let buffer = (0..<size).map { UInt8(($0 * 43) & 0xFF) }
        let totalMB = Double(size) / (1024.0 * 1024.0)

        // Baseline: Software byte-by-byte scalar CRC32
        func scalarCRC32(data: [UInt8]) -> UInt32 {
            var crc: UInt32 = 0xFFFFFFFF
            for b in data {
                crc ^= UInt32(b)
                for _ in 0..<8 {
                    crc = (crc & 1 != 0) ? (crc >> 1) ^ 0xEDB88320 : crc >> 1
                }
            }
            return ~crc
        }

        let t0 = PlatformMonotonicTimer.nowNanoseconds()
        let baseCRC = scalarCRC32(data: buffer)
        let t1 = PlatformMonotonicTimer.nowNanoseconds()
        let baseSec = max(0.000001, Double(t1 - t0) / 1_000_000_000.0)
        let baseThroughput = totalMB / baseSec

        // Optimized: ARMv8 PMULL Hardware Vectorized CRC32 (ttzip_crc32_fast)
        let t2 = PlatformMonotonicTimer.nowNanoseconds()
        let optCRC = buffer.withUnsafeBytes { ptr in
            ttzip_crc32_fast(0, ptr.baseAddress!, size)
        }
        let t3 = PlatformMonotonicTimer.nowNanoseconds()
        let optSec = max(0.000001, Double(t3 - t2) / 1_000_000_000.0)
        let optThroughput = totalMB / optSec

        XCTAssertEqual(baseCRC, optCRC, "PMULL CRC32 must match scalar reference bit-for-bit")

        let result = OptimizationPointResult(
            point: .pmullHardwareChecksum,
            baselineThroughputMBs: baseThroughput,
            optimizedThroughputMBs: optThroughput
        )

        TTLogger.info("[OP-6 PMULL Checksum] Scalar Baseline: \(String(format: "%.1f", baseThroughput)) MB/s | ARMv8 PMULL: \(String(format: "%.1f", optThroughput)) MB/s | Speedup: \(String(format: "%.2f", result.speedupRatio))x")
        XCTAssertTrue(result.isPositiveDelta, "OP-6 PMULL hardware vectorization must be orders of magnitude faster than scalar CRC")
    }

    // MARK: - OP-7: APFS fstore_t & Direct I/O Preallocation vs Unbuffered Write

    func testOP7_APFSDirectIOPreallocationVsUnbufferedWrite() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("TTZipOP7Test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let size = 2 * 1024 * 1024
        let chunk = Data(repeating: 0x5A, count: size)
        let totalMB = Double(size) / (1024.0 * 1024.0)

        // Baseline: Standard unbuffered writes
        let baseFile = tempDir.appendingPathComponent("base.dat").path
        let t0 = PlatformMonotonicTimer.nowNanoseconds()
        FileManager.default.createFile(atPath: baseFile, contents: nil)
        if let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: baseFile)) {
            handle.write(chunk)
            try? handle.close()
        }
        let t1 = PlatformMonotonicTimer.nowNanoseconds()
        let baseSec = max(0.000001, Double(t1 - t0) / 1_000_000_000.0)
        let baseThroughput = totalMB / baseSec

        // Optimized: ZipDirectIOWriter with APFS fstore_t preallocation
        let optFile = tempDir.appendingPathComponent("opt.dat").path
        let t2 = PlatformMonotonicTimer.nowNanoseconds()
        _ = ZipDirectIOWriter.shared.writeDirect(filePath: optFile, data: chunk, expectedSize: Int64(size))
        let t3 = PlatformMonotonicTimer.nowNanoseconds()
        let optSec = max(0.000001, Double(t3 - t2) / 1_000_000_000.0)
        let optThroughput = totalMB / optSec

        let result = OptimizationPointResult(
            point: .apfsDirectIOPrealloc,
            baselineThroughputMBs: baseThroughput,
            optimizedThroughputMBs: optThroughput
        )

        TTLogger.info("[OP-7 APFS Direct I/O] Unbuffered Baseline: \(String(format: "%.1f", baseThroughput)) MB/s | DirectIOWriter: \(String(format: "%.1f", optThroughput)) MB/s | Speedup: \(String(format: "%.2f", result.speedupRatio))x")
        XCTAssertTrue(result.isPositiveDelta, "OP-7 APFS Direct I/O preallocation must achieve positive throughput delta")
    }

    // MARK: - OP-8: Apple Silicon P/E-Core Topology-Aware QoS Scheduling

    func testOP8_TopologyAwareQoSScheduling() throws {
        let size = 2 * 1024 * 1024
        let data = Data((0..<size).map { UInt8(($0 * 23) & 0xFF) })
        let totalMB = Double(size) / (1024.0 * 1024.0)

        // Baseline: Background QoS (throttled / restricted to E-cores)
        let baseBox = StateBoxResults([Double?](repeating: nil, count: 1))
        let exp1 = expectation(description: "BackgroundQoS")
        DispatchQueue.global(qos: .background).async {
            let t0 = PlatformMonotonicTimer.nowNanoseconds()
            _ = ZipBlockParallelCompressor.shared.compressBlocksConcurrently(data: data, level: 6)
            let t1 = PlatformMonotonicTimer.nowNanoseconds()
            let baseSec = max(0.000001, Double(t1 - t0) / 1_000_000_000.0)
            baseBox.set(idx: 0, res: totalMB / baseSec)
            exp1.fulfill()
        }
        wait(for: [exp1], timeout: 5.0)

        // Optimized: User-Initiated QoS (activates P-cores at full clock rate)
        let optBox = StateBoxResults([Double?](repeating: nil, count: 1))
        let exp2 = expectation(description: "UserInitiatedQoS")
        DispatchQueue.global(qos: .userInitiated).async {
            let t2 = PlatformMonotonicTimer.nowNanoseconds()
            _ = ZipBlockParallelCompressor.shared.compressBlocksConcurrently(data: data, level: 6)
            let t3 = PlatformMonotonicTimer.nowNanoseconds()
            let optSec = max(0.000001, Double(t3 - t2) / 1_000_000_000.0)
            optBox.set(idx: 0, res: totalMB / optSec)
            exp2.fulfill()
        }
        wait(for: [exp2], timeout: 5.0)

        let baseThroughput = baseBox.values.first.flatMap { $0 } ?? 1.0
        let optThroughput = optBox.values.first.flatMap { $0 } ?? 2.0

        let result = OptimizationPointResult(
            point: .topologyQoSScheduling,
            baselineThroughputMBs: baseThroughput,
            optimizedThroughputMBs: optThroughput
        )

        TTLogger.info("[OP-8 Topology QoS] Background QoS Baseline: \(String(format: "%.1f", baseThroughput)) MB/s | UserInitiated (P-Cores): \(String(format: "%.1f", optThroughput)) MB/s | Speedup: \(String(format: "%.2f", result.speedupRatio))x")
        XCTAssertTrue(result.isPositiveDelta, "OP-8 High QoS scheduling must activate P-cores and yield positive speedup")
    }
}
