import XCTest
import CTTZipBridge
@testable import TTZipCore

/// 验证 APFS 零拷贝技术架构在生产环境中的可逆性、CRC32 校验与降级能力
final class ZipStoreZeroCopyTests: XCTestCase {

    func testApfsZeroCopyArchitecture() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ttzip_apfs_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sampleFile = tempDir.appendingPathComponent("sample.bin")
        let sampleData = Data((0..<1024 * 1024).map { UInt8($0 & 0xFF) }) // 1MB
        try sampleData.write(to: sampleFile)

        let outArchive = tempDir.appendingPathComponent("test_store_zerocopy.zip")

        // 1. 测试显式开启零拷贝模式
        let success = try ZipStoreStreamWriter.shared.createStoreArchive(
            outputPath: outArchive.path,
            inputPaths: [sampleFile.path],
            skipMacJunk: true,
            enableZeroCopy: true
        )
        XCTAssertTrue(success, "APFS 零拷贝归档打包应执行成功")
        XCTAssertTrue(FileManager.default.fileExists(atPath: outArchive.path))

        // 2. 验证生成的 ZIP 文件可以通过标准解压引擎完全还原
        let extractDir = tempDir.appendingPathComponent("extracted")
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)

        let extractStatus = ttzip_extract_zip_c_parallel(outArchive.path, extractDir.path, true, nil)
        XCTAssertEqual(extractStatus, 0, "零拷贝生成的 ZIP 包必须可被标准解压器无损解压")

        let extractedFile = extractDir.appendingPathComponent("sample.bin")
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedFile.path))
        let extractedData = try Data(contentsOf: extractedFile)
        XCTAssertEqual(extractedData.count, sampleData.count, "解压还原文件大小必须一致")
        XCTAssertEqual(extractedData, sampleData, "解压还原数据内容必须与源文件完全一致")
    }

    func testPhysicalStoreWithoutZeroCopy() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ttzip_phys_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sampleFile = tempDir.appendingPathComponent("sample.bin")
        let sampleData = Data((0..<1024 * 1024).map { UInt8(($0 * 31) & 0xFF) }) // 1MB
        try sampleData.write(to: sampleFile)

        let outArchive = tempDir.appendingPathComponent("test_store_physical.zip")

        // 2. 测试默认物理写盘（不使用零拷贝）
        let success = try ZipStoreStreamWriter.shared.createStoreArchive(
            outputPath: outArchive.path,
            inputPaths: [sampleFile.path],
            skipMacJunk: true,
            enableZeroCopy: false
        )
        XCTAssertTrue(success, "物理写盘 Store 归档打包应执行成功")
        XCTAssertTrue(FileManager.default.fileExists(atPath: outArchive.path))

        let extractDir = tempDir.appendingPathComponent("extracted_phys")
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)

        let extractStatus = ttzip_extract_zip_c_parallel(outArchive.path, extractDir.path, true, nil)
        XCTAssertEqual(extractStatus, 0, "物理写盘生成的 ZIP 包必须可被标准解压器无损解压")

        let extractedFile = extractDir.appendingPathComponent("sample.bin")
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedFile.path))
        let extractedData = try Data(contentsOf: extractedFile)
        XCTAssertEqual(extractedData, sampleData, "物理写盘解压还原数据必须与源文件完全一致")
    }
}
