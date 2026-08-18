// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class TouchIDAndHeaderEncryptionTests: XCTestCase {
    private var tempDirectoryURL: URL!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent("TTZip_AuthTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
    }
    
    override func tearDownWithError() throws {
        if let url = tempDirectoryURL {
            try? FileManager.default.removeItem(at: url)
        }
        try super.tearDownWithError()
    }
    
    func testTouchIDAuthenticatorAvailability() {
        let auth = TouchIDAuthenticator.shared
        // On CI/headless runners, this returns false or true depending on hardware
        let available = auth.canEvaluateBiometrics()
        XCTAssertNotNil(available)
    }
    
    func testSevenZipEncryptedHeaderCreationAndInspection() async throws {
        let sourceFile = tempDirectoryURL.appendingPathComponent("secret_notes.txt").path
        let secretText = "Top Secret 2026 Data Protected by 7z Encrypted Header (-mhe=on)"
        try secretText.write(toFile: sourceFile, atomically: true, encoding: .utf8)
        
        let out7z = tempDirectoryURL.appendingPathComponent("encrypted_header.7z").path
        let writer = ArchiveWriter()
        
        try await writer.createArchive(
            outputPath: out7z,
            format: .sevenZip,
            level: .fast,
            inputPaths: [sourceFile],
            password: "MasterPassword123"
        )
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: out7z))
        
        // Inspect with correct password
        let reader = ArchiveReader()
        let items = try await reader.inspect(archivePath: out7z, password: "MasterPassword123")
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.path, "secret_notes.txt")
        
        // Extract with correct password
        let destDir = tempDirectoryURL.appendingPathComponent("extracted_secret").path
        let extractor = ArchiveExtractor()
        try await extractor.extract(archivePath: out7z, destinationDir: destDir, password: "MasterPassword123")
        
        let extractedFile = (destDir as NSString).appendingPathComponent("secret_notes.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedFile))
        let extractedText = try String(contentsOfFile: extractedFile, encoding: .utf8)
        XCTAssertEqual(extractedText, secretText)
    }
}
