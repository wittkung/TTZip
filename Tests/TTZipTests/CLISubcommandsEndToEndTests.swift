// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class CLISubcommandsEndToEndTests: XCTestCase {
    
    // MARK: - 1. Shell Completion Generators
    
    func testFishCompletionGeneration() {
        let completion = CLICommandSpec.generateFishCompletion()
        XCTAssertTrue(completion.contains("complete -c ttzip-cli"))
        XCTAssertTrue(completion.contains("__fish_use_subcommand"))
        XCTAssertTrue(completion.contains("archive"))
        XCTAssertTrue(completion.contains("extract"))
        XCTAssertTrue(completion.contains("cat"))
        XCTAssertTrue(completion.contains("tree"))
        XCTAssertTrue(completion.contains("hash"))
    }
    
    func testNushellCompletionGeneration() {
        let completion = CLICommandSpec.generateNushellCompletion()
        XCTAssertTrue(completion.contains("export extern \"ttzip-cli\""))
        XCTAssertTrue(completion.contains("export extern \"ttzip-cli archive\""))
        XCTAssertTrue(completion.contains("export extern \"ttzip-cli extract\""))
        XCTAssertTrue(completion.contains("export extern \"ttzip-cli cat\""))
        XCTAssertTrue(completion.contains("export extern \"ttzip-cli tree\""))
        XCTAssertTrue(completion.contains("export extern \"ttzip-cli hash\""))
    }
    
    func testZshCompletionGeneration() {
        let completion = CLICommandSpec.generateZshCompletion()
        XCTAssertTrue(completion.contains("#compdef ttzip-cli"))
        XCTAssertTrue(completion.contains("archive:"))
        XCTAssertTrue(completion.contains("cat:"))
        XCTAssertTrue(completion.contains("tree:"))
        XCTAssertTrue(completion.contains("hash:"))
    }
    
    func testBashCompletionGeneration() {
        let completion = CLICommandSpec.generateBashCompletion()
        XCTAssertTrue(completion.contains("_ttzip_cli_completions()"))
        XCTAssertTrue(completion.contains("archive"))
        XCTAssertTrue(completion.contains("cat"))
        XCTAssertTrue(completion.contains("tree"))
        XCTAssertTrue(completion.contains("hash"))
    }
    
    // MARK: - 2. End-to-End Archive Creation & Tree & Stream Cat
    
    func testEndToEndCreateAndInspect() async throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("ttzip_cli_e2e_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        
        let file1 = tmpDir.appendingPathComponent("hello.txt")
        let file2 = tmpDir.appendingPathComponent("sub/world.txt")
        try FileManager.default.createDirectory(at: file2.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "Hello TTZip CLI Streaming!".write(to: file1, atomically: true, encoding: .utf8)
        try "World of High Performance Native Archiving".write(to: file2, atomically: true, encoding: .utf8)
        
        let outArchive = tmpDir.appendingPathComponent("test_bundle.zip").path
        
        // 1. Create Archive via Facade
        _ = try await TTZipEngineFacade.shared.quickCompress(
            inputs: [file1.path, file2.path],
            outputPath: outArchive,
            format: .zip,
            level: .normal
        )
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: outArchive))
        
        // 2. Inspect Archive
        let inspectRes = try await TTZipEngineFacade.shared.inspectArchive(archivePath: outArchive)
        XCTAssertGreaterThanOrEqual(inspectRes.entries.count, 2)
        
        // 3. Render Tree
        let treeOutput = ArchiveVisualTreeRenderer.render(archivePath: outArchive, entries: inspectRes.entries)
        XCTAssertTrue(treeOutput.contains("test_bundle.zip"))
        XCTAssertTrue(treeOutput.contains("hello.txt"))
        
        // 4. Verify Hash Integrity
        let hashRes = try await TTZipEngineFacade.shared.verifyIntegrity(archivePath: outArchive)
        XCTAssertFalse(hashRes.crc32.isEmpty)
        XCTAssertFalse(hashRes.sha256.isEmpty)
    }
}
