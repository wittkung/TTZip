import XCTest
@testable import TTZipCore
import CTTZipBridge

final class ChunkedDeflateStreamingTests: XCTestCase {
    
    private var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("TTZipChunkedTest_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        super.tearDown()
    }
    
    func testChunkedStreamWriterSmallData() throws {
        let outPath = tempDirectory.appendingPathComponent("test_small.deflate").path
        let fd = open(outPath, O_CREAT | O_TRUNC | O_WRONLY, 0644)
        XCTAssertGreaterThanOrEqual(fd, 0)
        
        let writer = try XCTUnwrap(ChunkedDeflateStreamWriter(outFd: fd, level: 6))
        
        let sampleData = "Hello, TTZip Chunked DEFLATE Stream!".data(using: .utf8)!
        XCTAssertTrue(writer.write(data: sampleData))
        
        let result = try XCTUnwrap(writer.finish())
        close(fd)
        
        XCTAssertGreaterThan(result.totalCompressed, 0)
        XCTAssertGreaterThan(result.finalCrc32, 0)
        
        // 校验生成的文件存在且大小与 totalCompressed 一致
        let attr = try FileManager.default.attributesOfItem(atPath: outPath)
        let diskSize = try XCTUnwrap(attr[.size] as? UInt64)
        XCTAssertEqual(diskSize, result.totalCompressed)
    }
    
    func testChunkedStreamWriterMultiMegaBytes() throws {
        let outPath = tempDirectory.appendingPathComponent("test_multimb.deflate").path
        let fd = open(outPath, O_CREAT | O_TRUNC | O_WRONLY, 0644)
        XCTAssertGreaterThanOrEqual(fd, 0)
        
        let writer = try XCTUnwrap(ChunkedDeflateStreamWriter(outFd: fd, level: 1))
        
        // 构造 3.5MB 的可预测重复数据
        let pattern = "TTZipFastStreamingPayload2026_AppleSilicon_M_Series#".data(using: .utf8)!
        var totalBytesWritten: Int = 0
        let targetBytes: Int = 3 * 1024 * 1024 + 512 * 1024 // 3.5MB
        
        while totalBytesWritten < targetBytes {
            let toWrite = min(pattern.count, targetBytes - totalBytesWritten)
            XCTAssertTrue(writer.write(data: pattern.prefix(toWrite)))
            totalBytesWritten += toWrite
        }
        
        let result = try XCTUnwrap(writer.finish())
        close(fd)
        
        XCTAssertGreaterThan(result.totalCompressed, 0)
        XCTAssertLessThan(result.totalCompressed, UInt64(targetBytes)) // 验证产生有效压缩
        XCTAssertGreaterThan(result.finalCrc32, 0)
        
        let attr = try FileManager.default.attributesOfItem(atPath: outPath)
        let diskSize = try XCTUnwrap(attr[.size] as? UInt64)
        XCTAssertEqual(diskSize, result.totalCompressed)
    }
    
    func testAdaptiveThresholdConstant() {
        XCTAssertEqual(ChunkedDeflateStreamWriter.adaptiveThresholdBytes, 256 * 1024 * 1024)
    }
}
