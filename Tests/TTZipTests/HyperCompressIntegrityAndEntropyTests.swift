import XCTest
import CryptoKit
import CTTZipBridge
@testable import TTZipCore

/// HyperCompressBench 混合熵分流、Match-Finder Early-Exit 与解压哈希真实预言机闭环验证
final class HyperCompressIntegrityAndEntropyTests: XCTestCase {
    
    // MARK: - 1. 100% 逐文件解压哈希一致性验证 (Oracle-First 闭环)
    
    func testRoundTripByteLevelIntegrity() async throws {
        let profile = MicroCorpusProfile(
            profileId: "test-integrity",
            fileCount: 200,
            minFileSizeBytes: 1024,
            maxFileSizeBytes: 8192,
            jsonRatio: 0.5,
            logRatio: 0.5,
            highEntropyRatio: 0.0,
            maxDirectoryDepth: 3,
            directoryFanout: 6
        )
        let generator = HyperCompressCorpusGenerator(profile: profile)
        let generated = try generator.writeToTemporaryDirectory()
        defer { generated.cleanup() }
        
        let tempZip = FileManager.default.temporaryDirectory
            .appendingPathComponent("integrity_\(UUID().uuidString).zip")
        let extractDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("extracted_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempZip)
            try? FileManager.default.removeItem(at: extractDir)
        }
        
        // 1. 批量压缩
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: tempZip.path,
            format: .zip,
            level: .normal,
            inputPaths: [generated.rootURL.path]
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempZip.path))
        
        // 2. 解压
        let extractor = ArchiveExtractor()
        try await extractor.extract(archivePath: tempZip.path, destinationDir: extractDir.path)
        
        // 3. 逐文件比对原始哈希 (SHA-256 & CRC32)
        var verifiedCount = 0
        for item in generated.items {
            let extractedFileURL = extractDir
                .appendingPathComponent(generated.rootURL.lastPathComponent)
                .appendingPathComponent(item.relativePath)
            
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: extractedFileURL.path),
                "解压后必须存在对应文件: \(item.relativePath)"
            )
            
            if let extractedData = try? Data(contentsOf: extractedFileURL) {
                XCTAssertEqual(
                    extractedData.count,
                    item.byteLength,
                    "文件大小必须与原始数据严格一致: \(item.relativePath)"
                )
                
                // CRC32 校验
                var extractedCRC: UInt32 = 0
                extractedData.withUnsafeBytes { rawBuf in
                    if let ptr = rawBuf.baseAddress {
                        extractedCRC = ttzip_compute_buffer_crc32(ptr, rawBuf.count)
                    }
                }
                XCTAssertEqual(extractedCRC, item.crc32, "CRC32 校验和必须一致: \(item.relativePath)")
                
                // SHA-256 校验
                let digest = SHA256.hash(data: extractedData)
                let sha256Hex = digest.map { String(format: "%02x", $0) }.joined()
                XCTAssertEqual(sha256Hex, item.sha256Hex, "SHA-256 密码学哈希必须一致: \(item.relativePath)")
                
                verifiedCount += 1
            }
        }
        
        XCTAssertEqual(verifiedCount, generated.items.count, "必须 100% 验证全部微文件")
    }
    
    // MARK: - 2. 混合熵不可压缩碎片膨胀率与 Early-Exit 验证
    
    func testMixedEntropyEarlyExitEfficiency() async throws {
        let profile = MicroCorpusProfile(
            profileId: "high-entropy-test",
            fileCount: 100,
            minFileSizeBytes: 16384,
            maxFileSizeBytes: 65536,
            jsonRatio: 0.0,
            logRatio: 0.0,
            highEntropyRatio: 1.0 // 100% 高熵不可压缩
        )
        let generator = HyperCompressCorpusGenerator(profile: profile)
        let generated = try generator.writeToTemporaryDirectory()
        defer { generated.cleanup() }
        
        let rawBytes = generated.items.reduce(0) { $0 + $1.byteLength }
        let tempZip = FileManager.default.temporaryDirectory
            .appendingPathComponent("entropy_\(UUID().uuidString).zip")
        defer { try? FileManager.default.removeItem(at: tempZip) }
        
        let start = CACurrentMediaTime()
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: tempZip.path,
            format: .zip,
            level: .fastest,
            inputPaths: [generated.rootURL.path]
        )
        let elapsed = CACurrentMediaTime() - start
        
        let attr = try FileManager.default.attributesOfItem(atPath: tempZip.path)
        let zipBytes = attr[.size] as? Int64 ?? 0
        
        // 高熵不可压缩数据压缩后体积膨胀不得超过 3.0% (加上 ZIP 容器 Header 和 Deflate 块头)
        let maxAllowedBytes = Int64(Double(rawBytes) * 1.03) + 8192
        XCTAssertLessThanOrEqual(
            zipBytes,
            maxAllowedBytes,
            "不可压缩高熵碎片压缩后不得发生异常膨胀"
        )
        
        let throughputMBs = (Double(rawBytes) / (1024 * 1024)) / elapsed
        XCTAssertGreaterThan(throughputMBs, 30.0, "高熵碎片 Early-Exit 吞吐速率必须保持在较高水准")
    }
}
