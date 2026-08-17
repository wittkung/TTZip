import XCTest
@testable import TTZipCore
import CTTZipBridge

final class AccelerationInfrastructureTests: XCTestCase {
    
    var tempDirPath: String!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("AccelInfra_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        tempDirPath = tempDir.path
    }
    
    override func tearDownWithError() throws {
        if let path = tempDirPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        try super.tearDownWithError()
    }
    
    /// 1. 验证 Apple LZFSE 原生 C 硬件加速编解码
    func testAppleLZFSERoundtrip() throws {
        XCTAssertTrue(ttzip_lzfse_is_available(), "Apple LZFSE library must be available on macOS")
        
        let sampleText = "Apple Silicon Native LZFSE Hardware Acceleration Payload Stream Test 2026 " + String(repeating: "TTZip High Throughput ", count: 100)
        let sampleData = sampleText.data(using: .utf8)!
        
        let srcFile = (tempDirPath as NSString).appendingPathComponent("lzfse_src.bin")
        let compFile = (tempDirPath as NSString).appendingPathComponent("lzfse_compressed.bin")
        let decompFile = (tempDirPath as NSString).appendingPathComponent("lzfse_decompressed.bin")
        
        try sampleData.write(to: URL(fileURLWithPath: srcFile))
        
        // 文件流压缩
        let compStatus = ttzip_lzfse_compress_file_stream(srcFile, compFile)
        XCTAssertEqual(compStatus, 0, "LZFSE file stream compression must return TTZIP_OK")
        XCTAssertTrue(FileManager.default.fileExists(atPath: compFile))
        
        // 文件流解压
        let decompStatus = ttzip_lzfse_decompress_file_stream(compFile, decompFile)
        XCTAssertEqual(decompStatus, 0, "LZFSE file stream decompression must return TTZIP_OK")
        
        let restoredText = try String(contentsOfFile: decompFile, encoding: .utf8)
        XCTAssertEqual(restoredText, sampleText, "LZFSE decompressed payload must match original exactly")
    }
    
    /// 2. 验证 UnRAR 纯 C 直连引擎基础接口
    func testUnRAREngineAvailability() {
        let inspectRes = ttzip_unrar_inspect_entry_count("/non_existent_file.rar")
        XCTAssertEqual(inspectRes, -1, "Inspecting non-existent RAR file should return -1 gracefully")
    }
}
