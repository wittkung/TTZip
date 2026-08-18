// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import Foundation
@testable import TTZipCore
@testable import CTTZipBridge

final class ArchiveSpecIntegrityTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    /// 1. C EOCD CDFH
    func testCTTZipParserSafety() throws {
        let sampleZip = tempDir.appendingPathComponent("sample_parser_test.zip")
        let writer = ArchiveWriter()
        
        let testFile = tempDir.appendingPathComponent("test_file.txt")
        try "TTZip Spec Integrity Test Content".data(using: .utf8)?.write(to: testFile)

        let exp = expectation(description: "Archive creation completed")
        Task {
            try await writer.createArchive(
                outputPath: sampleZip.path,
                format: .zip,
                level: .normal,
                inputPaths: [testFile.path]
            )
            exp.fulfill()
        }
        wait(for: [exp], timeout: 10.0)

        let fd = open(sampleZip.path, O_RDONLY)
        XCTAssertGreaterThan(fd, 0)
        defer { close(fd) }

        var st = stat()
        fstat(fd, &st)
        let fileBytes = size_t(st.st_size)

        guard let mapped = mmap(nil, fileBytes, PROT_READ, MAP_SHARED, fd, 0) else {
            XCTFail("mmap failed")
            return
        }
        let mappedBytes = mapped.assumingMemoryBound(to: UInt8.self)
        defer { munmap(mapped, fileBytes) }

        var eocd = ttzip_eocd_info_t()
        let foundEocd = ttzip_find_eocd(mappedBytes, fileBytes, &eocd)
        XCTAssertTrue(foundEocd, "EOCD must be found defensively by CTTZipParser")
        XCTAssertGreaterThan(eocd.total_entries, 0)

        var entry = ttzip_parsed_entry_t()
        var nextPos: size_t = 0
        let parsedEntry = ttzip_parse_cdfh_entry(mappedBytes, fileBytes, size_t(eocd.cd_offset), &entry, &nextPos)
        XCTAssertTrue(parsedEntry, "CDFH entry must be parsed defensively without unaligned pointer faults")
        XCTAssertFalse(entry.is_directory)
        XCTAssertEqual(entry.uncompressed_size, UInt64("TTZip Spec Integrity Test Content".count))
    }

    /// 2. WinZip AES-256 0x9901
    func testWinZipAES256EncryptedRoundtrip() throws {
        let zipPath = tempDir.appendingPathComponent("aes_test.zip")
        let extDir = tempDir.appendingPathComponent("ext_out")
        try FileManager.default.createDirectory(at: extDir, withIntermediateDirectories: true)

        let sourceFile = tempDir.appendingPathComponent("payload.bin")
        let dummyData = Data(repeating: 0xAB, count: 1024 * 1024) // 1MB payload
        try dummyData.write(to: sourceFile)

        let writer = ArchiveWriter()
        let extractor = ArchiveExtractor()

        let expCreate = expectation(description: "AES Zip creation")
        Task {
            try await writer.createArchive(
                outputPath: zipPath.path,
                format: .zip,
                level: .normal,
                inputPaths: [sourceFile.path],
                password: "MySecurePassword123!"
            )
            expCreate.fulfill()
        }
        wait(for: [expCreate], timeout: 10.0)

        let expExtract = expectation(description: "AES Zip extraction")
        Task {
            try await extractor.extract(
                archivePath: zipPath.path,
                destinationDir: extDir.path,
                password: "MySecurePassword123!"
            )
            expExtract.fulfill()
        }
        wait(for: [expExtract], timeout: 10.0)

        let checker = ArchiveIntegrityChecker()
        let result = checker.verifyExtractedDirectory(
            directoryPath: extDir.path,
            expectedOriginalBytes: Int64(dummyData.count),
            sourceFilePath: sourceFile.path,
            label: "WinZipAES256Test"
        )
        XCTAssertTrue(result.isValid, "Extracted file CRC32 and total bytes must match source file 100%")
    }

    /// 3. Level 1 + WinZip AES-256 Store
    func testStoreFallbackWinZipAESIntegrity() throws {
        let zipPath = tempDir.appendingPathComponent("store_fallback_aes.zip")
        let extDir = tempDir.appendingPathComponent("ext_fallback_out")
        try FileManager.default.createDirectory(at: extDir, withIntermediateDirectories: true)

        let sourceFile = tempDir.appendingPathComponent("high_entropy.bin")
        var randomBytes = [UInt8](repeating: 0, count: 2 * 1024 * 1024)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        let randomData = Data(randomBytes)
        try randomData.write(to: sourceFile)

        let writer = ArchiveWriter()
        let extractor = ArchiveExtractor()

        let expCreate = expectation(description: "Store Fallback AES Zip creation")
        Task {
            try await writer.createArchive(
                outputPath: zipPath.path,
                format: .zip,
                level: .fastest, // Level 1
                inputPaths: [sourceFile.path],
                password: "FallbackPassword999!"
            )
            expCreate.fulfill()
        }
        wait(for: [expCreate], timeout: 10.0)

        let expExtract = expectation(description: "Store Fallback AES Zip extraction")
        Task {
            try await extractor.extract(
                archivePath: zipPath.path,
                destinationDir: extDir.path,
                password: "FallbackPassword999!"
            )
            expExtract.fulfill()
        }
        wait(for: [expExtract], timeout: 10.0)

        let checker = ArchiveIntegrityChecker()
        let result = checker.verifyExtractedDirectory(
            directoryPath: extDir.path,
            expectedOriginalBytes: Int64(randomData.count),
            sourceFilePath: sourceFile.path,
            label: "StoreFallbackAES256Test"
        )
        XCTAssertTrue(result.isValid, "High-entropy random payload with AES Store fallback must extract with 100% CRC32 match")
    }
}
