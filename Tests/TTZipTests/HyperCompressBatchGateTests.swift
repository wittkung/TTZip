import XCTest
import CTTZipBridge
@testable import TTZipCore

/// HyperCompressBench 小文件微型碎片批处理 Fast-Path 性能门禁测试 (500+ 文件 >= 50 MB/s Debug / >= 70 MB/s Release)
final class HyperCompressBatchGateTests: XCTestCase {
    
    // MARK: - 1. ZIP 小文件批处理 Fast-Path 门禁
    
    func testHyperCompressBatchZipFastPathGate() async throws {
        let generator = HyperCompressCorpusGenerator(profile: .standardCiGate)
        let generated = try generator.writeToTemporaryDirectory()
        defer { generated.cleanup() }
        
        let totalBytes = Int64(generated.items.reduce(0) { $0 + $1.byteLength })
        
        let metrics = try await AsyncBenchmarkRunner.measure(
            name: "HyperCompress ZIP Batch (500 Files)",
            payloadBytes: totalBytes,
            iterations: 2,
            setUp: { _ in },
            block: { sandbox in
                let outArchive = sandbox.fileURL(named: "hypercompress_batch.zip").path
                let writer = ArchiveWriter()
                try await writer.createArchive(
                    outputPath: outArchive,
                    format: .zip,
                    level: .fastest,
                    inputPaths: [generated.rootURL.path]
                )
                XCTAssertTrue(FileManager.default.fileExists(atPath: outArchive))
            }
        )
        
        #if DEBUG
        XCTAssertGreaterThanOrEqual(metrics.throughputMBs, 50.0, "HyperCompress ZIP 500 小文件批处理吞吐必须 >= 50.0 MB/s (Debug 门禁)")
        #else
        XCTAssertGreaterThanOrEqual(metrics.throughputMBs, 70.0, "HyperCompress ZIP 500 小文件批处理吞吐必须 >= 70.0 MB/s (Release 门禁)")
        #endif
    }
    
    // MARK: - 2. TAR.ZST 小文件批处理 Fast-Path 门禁
    
    func testHyperCompressBatchTarZstFastPathGate() async throws {
        let generator = HyperCompressCorpusGenerator(profile: .standardCiGate)
        let generated = try generator.writeToTemporaryDirectory()
        defer { generated.cleanup() }
        
        let totalBytes = Int64(generated.items.reduce(0) { $0 + $1.byteLength })
        
        let metrics = try await AsyncBenchmarkRunner.measure(
            name: "HyperCompress TAR.ZST Batch (500 Files)",
            payloadBytes: totalBytes,
            iterations: 2,
            setUp: { _ in },
            block: { sandbox in
                let outArchive = sandbox.fileURL(named: "hypercompress_batch.tar.zst").path
                let writer = ArchiveWriter()
                try await writer.createArchive(
                    outputPath: outArchive,
                    format: .tarZst,
                    level: .level1,
                    inputPaths: [generated.rootURL.path]
                )
                XCTAssertTrue(FileManager.default.fileExists(atPath: outArchive))
            }
        )
        
        #if DEBUG
        XCTAssertGreaterThanOrEqual(metrics.throughputMBs, 50.0, "HyperCompress TAR.ZST 500 小文件批处理吞吐必须 >= 50.0 MB/s (Debug 门禁)")
        #else
        XCTAssertGreaterThanOrEqual(metrics.throughputMBs, 70.0, "HyperCompress TAR.ZST 500 小文件批处理吞吐必须 >= 70.0 MB/s (Release 门禁)")
        #endif
    }
    
    // MARK: - 3. 7Z 小文件批处理 Fast-Path 门禁
    
    func testHyperCompressBatch7zFastPathGate() async throws {
        let generator = HyperCompressCorpusGenerator(profile: .standardCiGate)
        let generated = try generator.writeToTemporaryDirectory()
        defer { generated.cleanup() }
        
        let totalBytes = Int64(generated.items.reduce(0) { $0 + $1.byteLength })
        
        let metrics = try await AsyncBenchmarkRunner.measure(
            name: "HyperCompress 7Z Batch (500 Files)",
            payloadBytes: totalBytes,
            iterations: 2,
            setUp: { _ in },
            block: { sandbox in
                let outArchive = sandbox.fileURL(named: "hypercompress_batch.7z").path
                let writer = ArchiveWriter()
                try await writer.createArchive(
                    outputPath: outArchive,
                    format: .sevenZip,
                    level: .fastest,
                    inputPaths: [generated.rootURL.path]
                )
                XCTAssertTrue(FileManager.default.fileExists(atPath: outArchive))
            }
        )
        
        #if DEBUG
        XCTAssertGreaterThanOrEqual(metrics.throughputMBs, 50.0, "HyperCompress 7Z 500 小文件批处理吞吐必须 >= 50.0 MB/s (Debug 门禁)")
        #else
        XCTAssertGreaterThanOrEqual(metrics.throughputMBs, 70.0, "HyperCompress 7Z 500 小文件批处理吞吐必须 >= 70.0 MB/s (Release 门禁)")
        #endif
    }
}
