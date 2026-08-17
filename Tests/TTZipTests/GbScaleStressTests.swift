import XCTest
@testable import TTZipCore

final class GbScaleStressTests: XCTestCase {
    
    /// 1.0 GB 超大文件流式压缩、解压与内存稳定性测试 (仅在 TTZIP_BENCH_TIER=STRESS 开启)
    func testOneGigabyteStreamingCompressionAndDecompression() async throws {
        guard ProcessInfo.processInfo.environment["TTZIP_BENCH_TIER"] == "STRESS" else {
            throw XCTSkip("巨型 GB 级性能测试需设置环境变量 TTZIP_BENCH_TIER=STRESS 触发，常规 swift test 自动跳过。")
        }
        
        let sandbox = try IsolatedTempSandbox(prefix: "gb_benchmark")
        defer { sandbox.cleanup() }
        
        let oneGbFilePath = sandbox.fileURL(named: "payload_1GB.bin").path
        let fileManager = FileManager.default
        
        fileManager.createFile(atPath: oneGbFilePath, contents: nil)
        let fileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: oneGbFilePath))
        defer { try? fileHandle.close() }
        
        let chunkMB = 50
        let chunkBytes = chunkMB * 1024 * 1024
        
        let patternString = "{\"id\": 1024, \"title\": \"TTZipEnterpriseTestPayload2026\", \"code\": \"func process() { print(\\\"TTZip\\\") }\"}\n"
        let patternBytes = Array(patternString.utf8)
        var chunkData = Data(count: chunkBytes)
        chunkData.withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) in
            guard let base = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            var seed: UInt64 = 0x123456789ABCDEF0
            for i in 0..<chunkBytes {
                if i % 2 == 0 {
                    base[i] = patternBytes[i % patternBytes.count]
                } else {
                    seed ^= (seed << 13)
                    seed ^= (seed >> 7)
                    seed ^= (seed << 17)
                    base[i] = UInt8(truncatingIfNeeded: seed & 0xFF)
                }
            }
        }
        
        for _ in 0..<20 { // 20 * 50MB = 1000MB ≈ 1GB
            fileHandle.write(chunkData)
        }
        
        let attr = try fileManager.attributesOfItem(atPath: oneGbFilePath)
        let actualFileSizeBytes = attr[.size] as? Int64 ?? 0
        let actualGB = Double(actualFileSizeBytes) / (1024 * 1024 * 1024)
        let actualMB = Double(actualFileSizeBytes) / (1024 * 1024)
        
        let outArchive = sandbox.fileURL(named: "archive_1GB.tar.zst").path
        let writer = ArchiveWriter()
        
        let compressStart = Date()
        try await writer.createArchive(outputPath: outArchive, format: .tarZst, level: .normal, inputPaths: [oneGbFilePath])
        let compressDuration = max(0.001, Date().timeIntervalSince(compressStart))
        let compressSpeedMBps = actualMB / compressDuration
        
        let archiveAttr = try fileManager.attributesOfItem(atPath: outArchive)
        let compressedSizeBytes = Double(archiveAttr[.size] as? Int64 ?? 0)
        let ratioPercent = (1.0 - (compressedSizeBytes / Double(actualFileSizeBytes))) * 100.0
        
        let extractDest = sandbox.fileURL(named: "extracted_1GB").path
        let extractor = ArchiveExtractor()
        
        let decompressStart = Date()
        try await extractor.extract(archivePath: outArchive, destinationDir: extractDest)
        let decompressDuration = max(0.001, Date().timeIntervalSince(decompressStart))
        let decompressSpeedMBps = actualMB / decompressDuration
        
        TTLogger.info("\n==================================================")
        TTLogger.info("📊 TTZip 1.0 GB 极限性能基准报告:")
        TTLogger.info("--------------------------------------------------")
        TTLogger.info(String(format: "原始文件体积: %.2f GB (%.2f MB)", actualGB, actualMB))
        TTLogger.info(String(format: "压缩包体积  : %.2f MB", compressedSizeBytes / (1024 * 1024)))
        TTLogger.info(String(format: "压缩率      : %.2f%%", ratioPercent))
        TTLogger.info(String(format: "1GB 压缩速度 : %.2f MB/s (耗时: %.3f 秒)", compressSpeedMBps, compressDuration))
        TTLogger.info(String(format: "1GB 解压速度 : %.2f MB/s (耗时: %.3f 秒)", decompressSpeedMBps, decompressDuration))
        TTLogger.info("==================================================\n")
        
        XCTAssertGreaterThan(compressSpeedMBps, 50.0, "1GB 压缩吞吐速率应大于 50 MB/s")
        XCTAssertGreaterThan(decompressSpeedMBps, 100.0, "1GB 解压吞吐速率应大于 100 MB/s")
        XCTAssertTrue(fileManager.fileExists(atPath: outArchive))
    }
}
