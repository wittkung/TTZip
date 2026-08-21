// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import CTTZipBridge
@testable import TTZipCore

final class SecurityAndComplianceTests: XCTestCase {
    override func tearDown() {
        _ = LicenseManager.shared.activate(key: "AURA-PRO1-KEY8-2026")
        super.tearDown()
    }
    
    func testZipSlipPathSanitization() {
        let entry1 = ArchiveEntry(path: "../../etc/passwd", uncompressedSize: 50, isDirectory: false, detectedEncoding: "UTF-8")
        let entry2 = ArchiveEntry(path: "/System/Library/CoreServices", uncompressedSize: 0, isDirectory: true, detectedEncoding: "UTF-8")
        
        let result = SecurityScanner.shared.scanArchiveEntries([entry1, entry2])
        XCTAssertFalse(result.isSafe)
        XCTAssertEqual(result.suspiciousFileNames.count, 2)
    }

    func testCBridgeZipSlipExtractionBlocked() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let destDir = tempDir.appendingPathComponent("dest")
        try? FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        
        var dstBuf = [CChar](repeating: 0, count: 4096)
        let res = ttzip_rust_validate_path(destDir.path, "../../etc/passwd", &dstBuf, dstBuf.count)
        XCTAssertNotEqual(res, TTZIP_STATUS_OK, "Zip Slip path must be blocked by ttzip_rust_validate_path")
    }

    func testCBridgeInvalidPasswordAESRejection() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(atPath: tempDir.path, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir.path) }

        let sampleFile = tempDir.appendingPathComponent("sample.txt")
        try "Secret Data Content".write(to: sampleFile, atomically: true, encoding: .utf8)

        let zipPath = tempDir.appendingPathComponent("encrypted.zip").path
        let correctPassword = "CorrectPassword123"
        let wrongPassword = "WrongPassword999"

        let created = try ZipParallelWriter.shared.createArchive(
            outputPath: zipPath,
            inputPaths: [sampleFile.path],
            level: .normal,
            skipMacJunk: true,
            password: correctPassword
        )
        XCTAssertTrue(created)

        let extractDir = tempDir.appendingPathComponent("extract_out").path
        _ = try? ArchiveExtractor().extractSync(archivePath: zipPath, destinationDir: extractDir, password: wrongPassword)
        let extractedFiles = (try? FileManager.default.contentsOfDirectory(atPath: extractDir)) ?? []
        XCTAssertEqual(extractedFiles.count, 0, "Extraction with wrong password must not produce files")
    }
    
    func testDangerousExtensionDetection() {
        let exeEntry = ArchiveEntry(path: "payload.exe", uncompressedSize: 1000, isDirectory: false, detectedEncoding: "UTF-8")
        let shEntry = ArchiveEntry(path: "script.sh", uncompressedSize: 500, isDirectory: false, detectedEncoding: "UTF-8")
        let txtEntry = ArchiveEntry(path: "notes.txt", uncompressedSize: 200, isDirectory: false, detectedEncoding: "UTF-8")
        
        let result = SecurityScanner.shared.scanArchiveEntries([exeEntry, shEntry, txtEntry])
        XCTAssertFalse(result.isSafe)
        XCTAssertEqual(result.suspiciousFileNames.count, 2)
        XCTAssertTrue(result.suspiciousFileNames.contains("payload.exe"))
        XCTAssertTrue(result.suspiciousFileNames.contains("script.sh"))
    }
    
    func testProFeatureGatingForUltraCompression() async {
        LicenseManager.simulateFreeTierInTests = true
        defer { LicenseManager.simulateFreeTierInTests = false }
        LicenseManager.shared.deactivate()
        let writer = ArchiveWriter()
        
        let dummyPath = "/tmp/dummy.txt"
        try? "dummy content".write(toFile: dummyPath, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: dummyPath) }
        
        do {
            try await writer.createArchive(outputPath: "/tmp/dummy.zip", level: .ultra, inputPaths: [dummyPath])
            XCTFail("Ultra compression should be blocked for Free license")
        } catch let error as ArchiveValidationError {
            if case .licenseRequired = error {
                // Pass: correctly blocked for free license
            } else {
                XCTFail("Unexpected ArchiveValidationError: \(error)")
            }
        } catch let error as ArchiveError {
            if case .readFailed(let code) = error {
                XCTAssertEqual(code, -403)
            } else {
                XCTFail("Unexpected ArchiveError: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}
