import XCTest
@testable import TTZipCore

final class TwoGbScaleEncryptedSplitStressTests: XCTestCase {
    
    let defaultPayloadMB = Int64(ProcessInfo.processInfo.environment["BENCHMARK_MB"] ?? "500") ?? 500
    var twoGbSizeBytes: Int64 { defaultPayloadMB * 1024 * 1024 }
    let password = "TTZipProEncryptedPassword#2026"
    let splitVolumeSizeBytes: Int64 = 100 * 1024 * 1024 // 100 MB per volume part
    
    /// 超大文件在带密码加密 + 分卷切割模式下的极限性能基准测试 (仅在 TTZIP_BENCH_TIER=STRESS 开启)
    func testTwoGigabyteEncryptedSplitVolumeCompressionAndDecompression() async throws {
        guard ProcessInfo.processInfo.environment["TTZIP_BENCH_TIER"] == "STRESS" else {
            throw XCTSkip("巨型加密分卷性能测试需设置环境变量 TTZIP_BENCH_TIER=STRESS 触发，常规 swift test 自动跳过。")
        }
        
        let sandbox = try IsolatedTempSandbox(prefix: "twogb_benchmark")
        defer { sandbox.cleanup() }
        
        let twoGbFilePath = sandbox.fileURL(named: "payload_2GB.bin").path
        let fileManager = FileManager.default
        
        fileManager.createFile(atPath: twoGbFilePath, contents: nil)
        let fileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: twoGbFilePath))
        defer { try? fileHandle.close() }
        
        let chunkMB = 50
        let chunkBytes = chunkMB * 1024 * 1024
        
        let patternString = "{\"engine\": \"TTZip 2GB Pro MultiCore Benchmark\", \"timestamp\": 20260806, \"level\": \"Ultra\"}\n"
        let patternBytes = Array(patternString.utf8)
        var chunkData = Data(count: chunkBytes)
        chunkData.withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) in
            guard let base = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            var seed: UInt64 = 0x987654321ABCDEF0
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
        
        let chunkCount = max(1, Int(defaultPayloadMB / 50))
        for _ in 0..<chunkCount {
            fileHandle.write(chunkData)
        }
        
        let attr = try fileManager.attributesOfItem(atPath: twoGbFilePath)
        let actualSizeBytes = attr[.size] as? Int64 ?? 0
        let actualMB = Double(actualSizeBytes) / (1024 * 1024)
        
        let outArchive7zStore = sandbox.fileURL(named: "archive_2GB_store.7z").path
        let writer = ArchiveWriter()
        
        let startCompress7zStore = Date()
        try await writer.createArchive(
            outputPath: outArchive7zStore,
            format: .sevenZip,
            level: .store,
            inputPaths: [twoGbFilePath],
            splitVolumeSizeBytes: splitVolumeSizeBytes,
            password: password
        )
        let durationCompress7zStore = max(0.001, Date().timeIntervalSince(startCompress7zStore))
        _ = durationCompress7zStore
        
        let outArchive7z = sandbox.fileURL(named: "archive_2GB.7z").path
        let startCompress7z = Date()
        try await writer.createArchive(
            outputPath: outArchive7z,
            format: .sevenZip,
            level: .normal,
            inputPaths: [twoGbFilePath],
            splitVolumeSizeBytes: splitVolumeSizeBytes,
            password: password
        )
        let durationCompress7z = max(0.001, Date().timeIntervalSince(startCompress7z))
        let speedCompress7z = actualMB / durationCompress7z
        
        let dirContents = (try? fileManager.contentsOfDirectory(atPath: sandbox.path)) ?? []
        let splitVolumes7z = dirContents.filter { $0.contains("archive_2GB.7z") && !$0.contains("store") }
        var totalCompressedSizeBytes7z: Int64 = 0
        for vol in splitVolumes7z {
            let volPath = sandbox.fileURL(named: vol).path
            if let volAttr = try? fileManager.attributesOfItem(atPath: volPath),
               let size = volAttr[.size] as? Int64 {
                totalCompressedSizeBytes7z += size
            }
        }
        _ = totalCompressedSizeBytes7z
        
        let firstVolume7z = sandbox.fileURL(named: "archive_2GB.7z.001").path
        let extractDest7z = sandbox.fileURL(named: "extracted_2GB_7z").path
        let extractor = ArchiveExtractor()
        
        let startDecompress7z = Date()
        try await extractor.extract(
            archivePath: fileManager.fileExists(atPath: firstVolume7z) ? firstVolume7z : outArchive7z,
            destinationDir: extractDest7z,
            password: password
        )
        let durationDecompress7z = max(0.001, Date().timeIntervalSince(startDecompress7z))
        let speedDecompress7z = actualMB / durationDecompress7z
        
        let outArchiveZip = sandbox.fileURL(named: "archive_2GB.zip").path
        let startCompressZip = Date()
        try await writer.createArchive(
            outputPath: outArchiveZip,
            format: .zip,
            level: .normal,
            inputPaths: [twoGbFilePath],
            splitVolumeSizeBytes: splitVolumeSizeBytes,
            password: password
        )
        let durationCompressZip = max(0.001, Date().timeIntervalSince(startCompressZip))
        _ = durationCompressZip
        
        XCTAssertGreaterThan(speedCompress7z, 5.0, "2GB 7z 密码分卷压缩速度应大于 5 MB/s")
        XCTAssertGreaterThan(speedDecompress7z, 30.0, "2GB 7z 密码分卷解压速度应大于 30 MB/s")
        XCTAssertGreaterThanOrEqual(splitVolumes7z.count, 1, "7z 应成功生成分卷文件")
    }
}
