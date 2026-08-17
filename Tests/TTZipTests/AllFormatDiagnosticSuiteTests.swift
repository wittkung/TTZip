import XCTest
import Foundation
@testable import TTZipCore

/// 全格式整合单项诊断测试主套件
///
/// 既可以一次性无缝测试全格式，也可在命令行通过 `--filter` 快速单项调试任意指定格式：
/// - 单项测试 ZIP: `swift test --filter testZipDiagnostic`
/// - 单项测试 7z:  `swift test --filter testSevenZipDiagnostic`
/// - 单项测试 ZSTD: `swift test --filter testZstdDiagnostic`
/// - 单项测试 GZIP: `swift test --filter testGzipDiagnostic`
/// - 单项测试 TAR:  `swift test --filter testTarDiagnostic`
/// - ... 依此类推
final class AllFormatDiagnosticSuiteTests: XCTestCase {

    /// 统一的高阶诊断断言抽取器 (零冗余代码)
    private static let supportedCreationFormats: Set<ArchiveCompressionFormat> = [
        .zip, .sevenZip, .tar, .tarGz, .gz, .tarZst, .zst, .tarBz2, .bz2, .tarXz, .xz,
        .lzip, .lz4, .brotli, .lrzip, .aar, .wim, .dmg, .iso
    ]

    private func assertDiagnosticPass(
        for format: ArchiveCompressionFormat,
        levels: [ArchiveCompressionLevel] = [.store, .level1, .level6, .level9],
        testEncryption: Bool = false,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        guard Self.supportedCreationFormats.contains(format) else {
            throw XCTSkip("\(format.rawValue.uppercased()) 归档格式暂未集成原生 C 打包创建支持，跳过打包诊断测试")
        }
        let config = FormatDiagnosticConfig(
            format: format,
            levelsToTest: levels,
            testPasswordEncryption: testEncryption
        )
        let pass = try FormatDiagnosticSuiteRunner.shared.runDiagnosticSuite(config: config)
        XCTAssertTrue(pass, "❌ [诊断测试断言失败] \(format.rawValue.uppercased()) (\(format.fileExtension)) 格式单项诊断测试未达到 100% 通过率", file: file, line: line)
    }

    func testZipDiagnostic() throws { try assertDiagnosticPass(for: .zip, testEncryption: true) }
    func testSevenZipDiagnostic() throws { try assertDiagnosticPass(for: .sevenZip, testEncryption: true) }
    func testZstdDiagnostic() throws { try assertDiagnosticPass(for: .tarZst, levels: [.level1, .level6, .level9]) }
    func testGzipDiagnostic() throws { try assertDiagnosticPass(for: .tarGz) }
    func testTarDiagnostic() throws { try assertDiagnosticPass(for: .tar, levels: [.store]) }
    func testBzip2Diagnostic() throws { try assertDiagnosticPass(for: .tarBz2) }
    func testXzDiagnostic() throws { try assertDiagnosticPass(for: .tarXz) }
    func testLzipDiagnostic() throws { try assertDiagnosticPass(for: .lzip, levels: [.level1, .level6]) }
    func testLz4Diagnostic() throws { try assertDiagnosticPass(for: .lz4, levels: [.level1, .level6]) }
    func testBrotliDiagnostic() throws { try assertDiagnosticPass(for: .brotli, levels: [.level1, .level6]) }
    func testLrzipDiagnostic() throws { try assertDiagnosticPass(for: .lrzip, levels: [.level1, .level6]) }
    func testAarDiagnostic() throws { try assertDiagnosticPass(for: .aar, levels: [.store]) }
    func testSnappyDiagnostic() throws { try assertDiagnosticPass(for: .snappy, levels: [.level1, .level6]) }
    func testWimDiagnostic() throws { try assertDiagnosticPass(for: .wim, levels: [.store, .level6]) }
    func testDmgDiagnostic() throws { try assertDiagnosticPass(for: .dmg, levels: [.store]) }
    func testIsoDiagnostic() throws { try assertDiagnosticPass(for: .iso, levels: [.store]) }
}
