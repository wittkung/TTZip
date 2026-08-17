// Tests/TTZipTests/FastLZMA2Tests.swift
// TTZip Fast-LZMA2 Engine & Hybrid Router Unit Tests

import XCTest
import CTTZipBridge
@testable import TTZipCore

final class FastLZMA2Tests: XCTestCase {

    func testFastLZMA2BlockCompression() throws {
        let inputString = "TTZip Fast-LZMA2 High Performance Engine Test " + String(repeating: "Hello World 1234567890! ", count: 2000)
        let inputData = inputString.data(using: .utf8)!
        
        let srcCount = inputData.count
        let dstCapacity = srcCount + 64 * 1024
        
        let dstPtr = UnsafeMutablePointer<UInt8>.allocate(capacity: dstCapacity)
        defer { dstPtr.deallocate() }
        
        var compressedLen: Int = 0
        var outDict: UInt32 = 0
        
        inputData.withUnsafeBytes { rawBuffer in
            let srcPtr = rawBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self)
            let res = ttzip_fl2_compress_block(
                srcPtr,
                srcCount,
                dstPtr,
                dstCapacity,
                &compressedLen,
                5,
                false,
                &outDict,
                4
            )
            XCTAssertEqual(res, 0, "Fast-LZMA2 块压缩必须成功")
            XCTAssertGreaterThan(compressedLen, 0, "压缩产物长度必须大于 0")
            XCTAssertLessThan(compressedLen, srcCount, "压缩后体积应显著小于原始体积")
            XCTAssertGreaterThan(outDict, 0, "输出字典大小必须大于 0")
        }
    }

    func testFastLZMA2ZeroBlockBypass() throws {
        let zeroCount = 1024 * 1024 // 1MB zero
        let zeroData = Data(count: zeroCount)
        let dstCapacity = 64 * 1024
        let dstPtr = UnsafeMutablePointer<UInt8>.allocate(capacity: dstCapacity)
        defer { dstPtr.deallocate() }

        var compressedLen: Int = 0
        var outDict: UInt32 = 0

        zeroData.withUnsafeBytes { rawBuffer in
            let srcPtr = rawBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self)
            let res = ttzip_fl2_compress_block(
                srcPtr,
                zeroCount,
                dstPtr,
                dstCapacity,
                &compressedLen,
                5,
                true, // is_zero_block hint
                &outDict,
                1
            )
            XCTAssertEqual(res, 0, "零块快速旁路必须成功")
            XCTAssertLessThan(compressedLen, 1024, "1MB 零数据压缩后应小于 1KB")
        }
    }

    func testFastLZMA2StreamLifecycle() throws {
        let streamCtx = ttzip_fl2_stream_create(5, 16 * 1024 * 1024, 2)
        XCTAssertNotNil(streamCtx, "流式上下文创建必须成功")

        let chunk = "Stream data chunk test ".data(using: .utf8)!
        let outBuf = UnsafeMutablePointer<UInt8>.allocate(capacity: 64 * 1024)
        defer { outBuf.deallocate() }

        var consumed: Int = 0
        var produced: Int = 0

        chunk.withUnsafeBytes { rawBuffer in
            let inPtr = rawBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self)
            let res = ttzip_fl2_stream_process(
                streamCtx,
                inPtr,
                chunk.count,
                &consumed,
                outBuf,
                64 * 1024,
                &produced,
                true // is_end
            )
            XCTAssertEqual(res, 0, "流式处理必须成功")
            XCTAssertEqual(consumed, chunk.count, "输入数据必须全量消费")
        }

        ttzip_fl2_stream_free(streamCtx)
    }

    func testSevenZipLZMA2HybridStrategyResolution() {
        let l1Strategy = SevenZipLZMA2HybridStrategy.resolve(level: .fastest)
        XCTAssertEqual(l1Strategy.routeMode, .neonFastPath)
        XCTAssertEqual(l1Strategy.level, 1)

        let l5Strategy = SevenZipLZMA2HybridStrategy.resolve(level: .level5)
        XCTAssertEqual(l5Strategy.routeMode, .fastLZMA2Parallel)
        XCTAssertEqual(l5Strategy.level, 5)

        let l6Strategy = SevenZipLZMA2HybridStrategy.resolve(level: .normal)
        XCTAssertEqual(l6Strategy.routeMode, .fastLZMA2Parallel)
        XCTAssertEqual(l6Strategy.level, 6)

        let zeroStrategy = SevenZipLZMA2HybridStrategy.resolve(level: .normal, isZeroBlock: true)
        XCTAssertEqual(zeroStrategy.routeMode, .zeroBlockBypass)
    }

    func testEndToEndSevenZipArchiveWithFastLZMA2() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sampleFile = tempDir.appendingPathComponent("sample.txt")
        let sampleContent = "TTZip Fast-LZMA2 End-to-End Validation " + String(repeating: "Benchmark 2026! ", count: 5000)
        try sampleContent.write(to: sampleFile, atomically: true, encoding: .utf8)

        let archivePath = tempDir.appendingPathComponent("test_fl2.7z").path
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: archivePath,
            format: .sevenZip,
            level: .normal, // Level 5 (triggers FL2)
            inputPaths: [sampleFile.path]
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: archivePath), "7z 归档必须成功生成")

        let extractDir = tempDir.appendingPathComponent("extracted")
        let extractor = ArchiveExtractor()
        try await extractor.extract(archivePath: archivePath, destinationDir: extractDir.path)

        let extractedFile = extractDir.appendingPathComponent("sample.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedFile.path), "解压文件必须存在")
        let restored = try String(contentsOf: extractedFile, encoding: .utf8)
        XCTAssertEqual(restored, sampleContent, "解压还原内容必须完全一致")
    }
}
