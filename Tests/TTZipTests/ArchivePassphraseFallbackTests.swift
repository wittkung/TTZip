// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import Foundation
@testable import TTZipCore

final class ArchivePassphraseFallbackTests: XCTestCase {
    
    // MARK: - US4: Multi-Candidate Passphrase Fallback Pipeline (T016, T017, T018)
    
    func testMultiCandidatePassphraseFallbackInInspection() async throws {
        let fixturePath = try TestFixtureLoader.encryptedFixturePath(named: "test_read_format_zip_winzip_aes256.zip")
        let reader = ArchiveReader()
        
        let candidateList = ["invalid_pwd_1", "invalid_pwd_2", "password"]
        let entries = try await reader.inspect(archivePath: fixturePath, password: nil, candidatePasswords: candidateList)
        
        XCTAssertFalse(entries.isEmpty, "Inspection with candidate list containing correct password must succeed")
    }
    
    func testMultiCandidatePassphraseFallbackInExtraction() async throws {
        let fixturePath = try TestFixtureLoader.encryptedFixturePath(named: "test_read_format_zip_winzip_aes256.zip")
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_fallback_ext_\(UUID().uuidString)").path
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }
        
        let extractor = ArchiveExtractor()
        
        // Pass candidate list through vault or extraction
        let candidateList = ["wrong1", "wrong2", "password"]
        var extracted = false
        for pwd in candidateList {
            do {
                try await extractor.extract(archivePath: fixturePath, destinationDir: tempDir, password: pwd)
                extracted = true
                break
            } catch {
                continue
            }
        }
        
        XCTAssertTrue(extracted, "Extraction must succeed when the valid password in the candidate list is reached")
        
        let readmePath = (tempDir as NSString).appendingPathComponent("README")
        XCTAssertTrue(FileManager.default.fileExists(atPath: readmePath), "Extracted README file must exist")
    }
    
    func testAllInvalidPassphrasesExhaustionFailsSafely() async throws {
        let fixturePath = try TestFixtureLoader.encryptedFixturePath(named: "test_read_format_zip_winzip_aes256.zip")
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_fallback_fail_\(UUID().uuidString)").path
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }
        
        let extractor = ArchiveExtractor()
        let candidateList = ["wrong1", "wrong2", "wrong3"]
        
        var anySuccess = false
        for pwd in candidateList {
            do {
                try await extractor.extract(archivePath: fixturePath, destinationDir: tempDir, password: pwd)
                anySuccess = true
                break
            } catch {
                continue
            }
        }
        
        XCTAssertFalse(anySuccess, "Extraction must fail safely when all candidates are exhausted")
    }
}
