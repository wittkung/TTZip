// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import Foundation
@testable import TTZipCore

/// Validates expected behavior and invariants.
///
/// ， `--filter` ：
/// - ZIP: `swift test --filter testZipDiagnostic`
/// - 7z: `swift test --filter testSevenZipDiagnostic`
/// - ZSTD: `swift test --filter testZstdDiagnostic`
/// - GZIP: `swift test --filter testGzipDiagnostic`
/// - TAR: `swift test --filter testTarDiagnostic`
/// - ...
final class AllFormatDiagnosticSuiteTests: XCTestCase {

    /// ( )
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
            throw XCTSkip("\(format.rawValue.uppercased()) format native C packing creation is not yet supported, skipping test")
        }
        let config = FormatDiagnosticConfig(
            format: format,
            levelsToTest: levels,
            testPasswordEncryption: testEncryption
        )
        let pass = try FormatDiagnosticSuiteRunner.shared.runDiagnosticSuite(config: config)
        XCTAssertTrue(pass, "❌ [Diagnostic assertion failure] \(format.rawValue.uppercased()) (\(format.fileExtension)) 格式单项诊断测试未达到 100% 通过率", file: file, line: line)
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
