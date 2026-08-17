// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Weitao Kung (Witt Kung) <kevintungs@163.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class CLICredentialAndErgonomicsTests: XCTestCase {
    
    // MARK: - 1. SecureCredentialResolver Tests
    
    func testResolvePasswordExplicit() {
        let pwd = SecureCredentialResolver.resolvePassword(
            explicitPassword: "MySecretPassword123!",
            passwordFile: nil,
            archiveName: "test.zip",
            isInteractive: false
        )
        XCTAssertEqual(pwd, "MySecretPassword123!")
    }
    
    func testResolvePasswordFromFile() throws {
        let tmpFile = FileManager.default.temporaryDirectory.appendingPathComponent("test_pwd_\(UUID().uuidString).txt").path
        try "FileSecretPass999\n".write(toFile: tmpFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: tmpFile) }
        
        let pwd = SecureCredentialResolver.resolvePassword(
            explicitPassword: nil,
            passwordFile: tmpFile,
            archiveName: "test.7z",
            isInteractive: false
        )
        XCTAssertEqual(pwd, "FileSecretPass999")
    }
    
    func testResolvePasswordFromEnv() {
        setenv("TTZIP_PASSWORD", "EnvSecretPass888", 1)
        
        let pwd = SecureCredentialResolver.resolvePassword(
            explicitPassword: nil,
            passwordFile: nil,
            archiveName: "test.tar.zst",
            isInteractive: false
        )
        XCTAssertEqual(pwd, "EnvSecretPass888")
        // Assert environment variable was wiped
        XCTAssertNil(ProcessInfo.processInfo.environment["TTZIP_PASSWORD"])
    }
    
    // MARK: - 2. ArchiveVisualTreeRenderer Tests
    
    func testArchiveVisualTreeRenderer() {
        let entries: [ArchiveEntry] = [
            ArchiveEntry(path: "src/main.swift", uncompressedSize: 1024, isDirectory: false),
            ArchiveEntry(path: "src/utils/math.swift", uncompressedSize: 2048, isDirectory: false),
            ArchiveEntry(path: "docs/README.md", uncompressedSize: 512, isDirectory: false),
            ArchiveEntry(path: "LICENSE", uncompressedSize: 128, isDirectory: false)
        ]
        
        let rendered = ArchiveVisualTreeRenderer.render(archivePath: "project.zip", entries: entries, maxDepth: nil)
        
        XCTAssertTrue(rendered.contains("📦 project.zip"))
        XCTAssertTrue(rendered.contains("src"))
        XCTAssertTrue(rendered.contains("main.swift"))
        XCTAssertTrue(rendered.contains("math.swift"))
        XCTAssertTrue(rendered.contains("README.md"))
        XCTAssertTrue(rendered.contains("4 files"))
    }
    
    func testArchiveVisualTreeRendererWithDepthLimit() {
        let entries: [ArchiveEntry] = [
            ArchiveEntry(path: "a/b/c/d/deep.txt", uncompressedSize: 100, isDirectory: false)
        ]
        
        let rendered = ArchiveVisualTreeRenderer.render(archivePath: "deep.zip", entries: entries, maxDepth: 1)
        XCTAssertTrue(rendered.contains("deep.zip"))
        XCTAssertTrue(rendered.contains("collapsed") || rendered.contains("..."))
    }
    
    // MARK: - 3. FileCollisionResolver Tests
    
    func testFileCollisionResolverAlwaysNever() throws {
        let tmpFile = FileManager.default.temporaryDirectory.appendingPathComponent("collide_\(UUID().uuidString).txt").path
        try "initial content".write(toFile: tmpFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: tmpFile) }
        
        let alwaysResolver = FileCollisionResolver(policy: .always)
        XCTAssertEqual(alwaysResolver.resolveCollision(destinationPath: tmpFile), .overwrite)
        
        let neverResolver = FileCollisionResolver(policy: .never)
        XCTAssertEqual(neverResolver.resolveCollision(destinationPath: tmpFile), .skip)
    }
    
    func testFileCollisionResolverBackup() throws {
        let tmpFile = FileManager.default.temporaryDirectory.appendingPathComponent("backup_target_\(UUID().uuidString).txt").path
        try "original content".write(toFile: tmpFile, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(atPath: tmpFile)
            try? FileManager.default.removeItem(atPath: "\(tmpFile).bak")
        }
        
        let backupResolver = FileCollisionResolver(policy: .backup)
        let action = backupResolver.resolveCollision(destinationPath: tmpFile)
        XCTAssertEqual(action, .overwrite)
        XCTAssertTrue(FileManager.default.fileExists(atPath: "\(tmpFile).bak"))
    }
}
