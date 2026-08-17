import XCTest
@testable import TTZipCore
import CTTZipBridge

final class ArchiveEntropyEvaluatorTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ttzip_entropy_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        ArchiveEntropyEvaluator.isSmartStoreBypassEnabled = true
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        ArchiveEntropyEvaluator.isSmartStoreBypassEnabled = true
        try super.tearDownWithError()
    }

    /// 1. 测试低熵数据 (日志/文本/高码率未压缩数据)
    func testLowEntropyDataNotBypassed() throws {
        let textPayload = String(repeating: "TTZip High-Performance Engine 2026 Structured Log Entry with Redundancy\n", count: 20000)
        let data = textPayload.data(using: .utf8)!
        
        let entropy = ArchiveEntropyEvaluator.estimateEntropyDynamic(
            buffer: (data as NSData).bytes,
            count: data.count
        )
        
        XCTAssertLessThan(entropy, 6.0, "文本与结构化数据 Shannon 熵应 < 6.0")
        XCTAssertFalse(
            ArchiveEntropyEvaluator.shouldBypassCompression(data: data),
            "低熵可压缩数据绝对不应跳过压缩"
        )
    }

    /// 2. 测试高熵数据 (真随机数/加密载荷)
    func testHighEntropyDataBypassed() throws {
        var randomBytes = [UInt8](repeating: 0, count: 2 * 1024 * 1024)
        for i in 0..<randomBytes.count {
            randomBytes[i] = UInt8.random(in: 0...255)
        }
        let data = Data(randomBytes)
        
        let entropy = ArchiveEntropyEvaluator.estimateEntropyDynamic(
            buffer: (data as NSData).bytes,
            count: data.count
        )
        
        XCTAssertGreaterThan(entropy, 7.90, "真随机数与密文 Shannon 熵应 > 7.90")
        XCTAssertTrue(
            ArchiveEntropyEvaluator.shouldBypassCompression(data: data),
            "高熵不可压缩数据应触发 Store 直通旁路"
        )
    }

    /// 3. 测试多点等距跨步采样 (文件级测试，消除头部元数据偏差)
    func testFileEntropyStridedSampling() throws {
        let testFile = tempDir.appendingPathComponent("strided_sample.bin")
        
        // 构造混合文件：头部 1MB 为低熵全零，其余 19MB 为均匀高熵数据
        FileManager.default.createFile(atPath: testFile.path, contents: nil)
        let handle = try FileHandle(forWritingTo: testFile)
        
        let zero1MB = Data(count: 1024 * 1024)
        try handle.write(contentsOf: zero1MB)
        
        var rand19MB = [UInt8](repeating: 0, count: 19 * 1024 * 1024)
        for i in 0..<rand19MB.count {
            rand19MB[i] = UInt8(i & 0xFF)
        }
        try handle.write(contentsOf: Data(rand19MB))
        try handle.close()
        
        let dynamicEntropy = ArchiveEntropyEvaluator.estimateFileEntropyDynamic(filePath: testFile.path)
        XCTAssertGreaterThan(
            dynamicEntropy,
            7.0,
            "多点跨步采样应有效跨越头部低熵区并探测到后续主体的高熵分布"
        )
    }

    /// 4. 测试用户设置面板开关
    func testSmartStoreBypassUserToggle() throws {
        var randomBytes = [UInt8](repeating: 0, count: 2 * 1024 * 1024)
        for i in 0..<randomBytes.count { randomBytes[i] = UInt8.random(in: 0...255) }
        let data = Data(randomBytes)
        
        ArchiveEntropyEvaluator.isSmartStoreBypassEnabled = false
        XCTAssertFalse(
            ArchiveEntropyEvaluator.shouldBypassCompression(data: data),
            "当用户关闭智能直通时，即使极高熵数据也应强制压缩"
        )
        
        ArchiveEntropyEvaluator.isSmartStoreBypassEnabled = true
        XCTAssertTrue(
            ArchiveEntropyEvaluator.shouldBypassCompression(data: data),
            "当用户开启智能直通时，极高熵数据应自动直通"
        )
    }
}
