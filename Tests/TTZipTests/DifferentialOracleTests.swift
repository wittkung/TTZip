//
//  DifferentialOracleTests.swift
//  TTZipTests
//
//  Created for Feature 070: CLI Test System & Differential Oracle Standards.
//

import XCTest
import Foundation
@testable import TTZipCore

final class DifferentialOracleTests: XCTestCase {
    
    private var sandbox: IsolatedTempSandbox!
    
    override func setUpWithError() throws {
        sandbox = try IsolatedTempSandbox(prefix: "diff_oracle_tests")
    }
    
    override func tearDownWithError() throws {
        sandbox?.cleanup()
        sandbox = nil
    }
    
    // MARK: - 1. Registry Discovery Tests
    
    func testRegistryOracleDiscovery() {
        let registry = DifferentialOracleRegistry.shared
        _ = registry.discoverOracles()
        
        // Assert mandatory oracles are discovered on macOS
        XCTAssertTrue(registry.mandatoryOraclesAvailable(), "Mandatory oracles (/usr/bin/tar, /usr/bin/unzip) must be available on macOS")
        XCTAssertNotNil(registry.oraclePath(for: "tar"), "tar oracle must resolve to a valid path")
        XCTAssertNotNil(registry.oraclePath(for: "unzip"), "unzip oracle must resolve to a valid path")
        
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: registry.oraclePath(for: "tar")!), "Resolved tar must be executable")
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: registry.oraclePath(for: "unzip")!), "Resolved unzip must be executable")
        
        // Assert defaultOracle mapping for core formats
        XCTAssertNotNil(registry.defaultOracle(for: .tar), "Default oracle for TAR must exist")
        XCTAssertNotNil(registry.defaultOracle(for: .zip), "Default oracle for ZIP must exist")
    }
    
    // MARK: - 2. TAR Roundtrip Against /usr/bin/tar
    
    func testTarRoundtripAgainstSystemTar() async throws {
        let sourceDir = try sandbox.createSubdirectory("tar_source")
        
        // Create root files
        let rootDoc = sourceDir.appendingPathComponent("document.txt")
        let rootDocContent = "TTZip & /usr/bin/tar Bidirectional Differential Test Payload 2026\n"
        try rootDocContent.write(to: rootDoc, atomically: true, encoding: .utf8)
        
        // Create nested directories and files
        let subDir = sourceDir.appendingPathComponent("nested_sub")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        
        let nestedDoc = subDir.appendingPathComponent("inner_payload.txt")
        let nestedContent = "Inner level nested file content for hierarchy preservation.\n"
        try nestedContent.write(to: nestedDoc, atomically: true, encoding: .utf8)
        
        let deepDir = subDir.appendingPathComponent("level2")
        try FileManager.default.createDirectory(at: deepDir, withIntermediateDirectories: true)
        
        let binaryFile = deepDir.appendingPathComponent("binary.dat")
        var binaryBytes = [UInt8](repeating: 0, count: 4096)
        for i in 0..<binaryBytes.count {
            binaryBytes[i] = UInt8((i * 37 + 13) & 0xFF)
        }
        try Data(binaryBytes).write(to: binaryFile)
        
        // Create relative symbolic link
        let symlinkPath = sourceDir.appendingPathComponent("link_to_doc").path
        try FileManager.default.createSymbolicLink(atPath: symlinkPath, withDestinationPath: "document.txt")
        
        let runSandbox = try sandbox.createSubdirectory("tar_run")
        
        let report = try await DifferentialOracleTestHarness.executeRoundtrip(
            format: .tar,
            sourceDir: sourceDir.path,
            oracle: "/usr/bin/tar",
            tempSandbox: runSandbox.path
        )
        
        XCTAssertTrue(report.isPassed, "TAR roundtrip against /usr/bin/tar must pass with 0 divergences. Errors: \(report.divergenceErrors)")
        XCTAssertTrue(report.divergenceErrors.isEmpty, "Divergence error list must be empty: \(report.divergenceErrors)")
        XCTAssertGreaterThanOrEqual(report.ttzipManifest.totalFileCount, 3, "Extracted tree must have at least 3 files")
        XCTAssertGreaterThanOrEqual(report.ttzipManifest.totalSymlinkCount, 1, "Extracted tree must have preserved symlink")
    }
    
    // MARK: - 3. ZIP Roundtrip Against /usr/bin/unzip
    
    func testZipRoundtripAgainstSystemUnzip() async throws {
        let sourceDir = try sandbox.createSubdirectory("zip_source")
        
        // Create test hierarchy
        let mainFile = sourceDir.appendingPathComponent("readme.md")
        let mainContent = "# TTZip Differential Oracle ZIP Test\nPrecision standards verification.\n"
        try mainContent.write(to: mainFile, atomically: true, encoding: .utf8)
        
        let subDir = sourceDir.appendingPathComponent("assets")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        
        let dataFile = subDir.appendingPathComponent("data.bin")
        var dataBytes = [UInt8](repeating: 0, count: 8192)
        for i in 0..<dataBytes.count {
            dataBytes[i] = UInt8((i * 59 + 7) & 0xFF)
        }
        try Data(dataBytes).write(to: dataFile)
        
        let runSandbox = try sandbox.createSubdirectory("zip_run")
        
        let report = try await DifferentialOracleTestHarness.executeRoundtrip(
            format: .zip,
            sourceDir: sourceDir.path,
            oracle: "/usr/bin/unzip",
            tempSandbox: runSandbox.path
        )
        
        XCTAssertTrue(report.isPassed, "ZIP roundtrip against /usr/bin/unzip must pass with 0 divergences. Errors: \(report.divergenceErrors)")
        XCTAssertTrue(report.divergenceErrors.isEmpty, "Divergence errors must be empty: \(report.divergenceErrors)")
        XCTAssertGreaterThanOrEqual(report.ttzipManifest.totalFileCount, 2, "Extracted tree must have at least 2 files")
    }
    
    // MARK: - 4. Optional bsdtar Roundtrip
    
    func testTarRoundtripAgainstBsdtar() async throws {
        guard let bsdtarPath = DifferentialOracleRegistry.shared.oraclePath(for: "bsdtar") else {
            throw XCTSkip("bsdtar oracle binary not found on this environment")
        }
        
        let sourceDir = try sandbox.createSubdirectory("bsdtar_source")
        let fileA = sourceDir.appendingPathComponent("fileA.txt")
        try "Content A for bsdtar testing\n".write(to: fileA, atomically: true, encoding: .utf8)
        
        let runSandbox = try sandbox.createSubdirectory("bsdtar_run")
        
        let report = try await DifferentialOracleTestHarness.executeRoundtrip(
            format: .tar,
            sourceDir: sourceDir.path,
            oracle: bsdtarPath,
            tempSandbox: runSandbox.path
        )
        
        XCTAssertTrue(report.isPassed, "TAR roundtrip against bsdtar must pass. Errors: \(report.divergenceErrors)")
        XCTAssertTrue(report.divergenceErrors.isEmpty)
    }
    
    // MARK: - 5. Optional 7zz Roundtrip
    
    func testSevenZipRoundtripAgainst7zz() async throws {
        guard let sevenZipPath = DifferentialOracleRegistry.shared.oraclePath(for: "7zz") ?? DifferentialOracleRegistry.shared.oraclePath(for: "7z") else {
            throw XCTSkip("7zz / 7z oracle binary not found on this environment")
        }
        
        let sourceDir = try sandbox.createSubdirectory("sevenzip_source")
        let doc = sourceDir.appendingPathComponent("7z_doc.txt")
        try "7-Zip differential oracle verification payload.\n".write(to: doc, atomically: true, encoding: .utf8)
        
        let runSandbox = try sandbox.createSubdirectory("sevenzip_run")
        
        let report = try await DifferentialOracleTestHarness.executeRoundtrip(
            format: .sevenZip,
            sourceDir: sourceDir.path,
            oracle: sevenZipPath,
            tempSandbox: runSandbox.path
        )
        
        XCTAssertTrue(report.isPassed, "7Z roundtrip against 7zz must pass. Errors: \(report.divergenceErrors)")
        XCTAssertTrue(report.divergenceErrors.isEmpty)
    }
    
    // MARK: - 6. 5-Dimension Manifest Verifier Unit Tests
    
    func testDifferentialManifestVerifierFiveDimensions() {
        let entryA = ManifestEntry(
            relativePath: "test/file.txt",
            entryType: .regularFile,
            byteSize: 100,
            sha256Checksum: "aaaabbbbccccdddd",
            posixMode: 0o644,
            symlinkTarget: nil
        )
        
        let manifestA = FileTreeManifest(
            rootDirectory: "/tmp/a",
            entries: ["test/file.txt": entryA],
            totalByteSize: 100,
            totalFileCount: 1,
            totalDirectoryCount: 0,
            totalSymlinkCount: 0
        )
        
        // 1. Identical comparison passes
        let passReport = DifferentialManifestVerifier.compare(ttzip: manifestA, oracle: manifestA, format: .tar, oracleName: "test")
        XCTAssertTrue(passReport.isPassed)
        XCTAssertTrue(passReport.divergenceErrors.isEmpty)
        
        // 2. Missing entry detected
        let emptyManifest = FileTreeManifest(rootDirectory: "/tmp/empty", entries: [:], totalByteSize: 0, totalFileCount: 0, totalDirectoryCount: 0, totalSymlinkCount: 0)
        let missingReport = DifferentialManifestVerifier.compare(ttzip: emptyManifest, oracle: manifestA, format: .tar, oracleName: "test")
        XCTAssertFalse(missingReport.isPassed)
        XCTAssertTrue(missingReport.divergenceErrors.contains(where: { $0.contains("Missing entry") }))
        
        // 3. Extra entry detected
        let extraReport = DifferentialManifestVerifier.compare(ttzip: manifestA, oracle: emptyManifest, format: .tar, oracleName: "test")
        XCTAssertFalse(extraReport.isPassed)
        XCTAssertTrue(extraReport.divergenceErrors.contains(where: { $0.contains("Unexpected extra entry") }))
        
        // 4. SHA-256 mismatch detected
        let entryBadChecksum = ManifestEntry(
            relativePath: "test/file.txt",
            entryType: .regularFile,
            byteSize: 100,
            sha256Checksum: "ffffffffffffffff",
            posixMode: 0o644,
            symlinkTarget: nil
        )
        let manifestBadChecksum = FileTreeManifest(rootDirectory: "/tmp/b", entries: ["test/file.txt": entryBadChecksum], totalByteSize: 100, totalFileCount: 1, totalDirectoryCount: 0, totalSymlinkCount: 0)
        let diffChecksumReport = DifferentialManifestVerifier.compare(ttzip: manifestBadChecksum, oracle: manifestA, format: .tar, oracleName: "test")
        XCTAssertFalse(diffChecksumReport.isPassed)
        XCTAssertTrue(diffChecksumReport.divergenceErrors.contains(where: { $0.contains("SHA-256 checksum mismatch") }))
        
        // 5. Symlink target mismatch detected
        let linkA = ManifestEntry(relativePath: "link", entryType: .symbolicLink, byteSize: 0, sha256Checksum: "", posixMode: 0o755, symlinkTarget: "targetA")
        let linkB = ManifestEntry(relativePath: "link", entryType: .symbolicLink, byteSize: 0, sha256Checksum: "", posixMode: 0o755, symlinkTarget: "targetB")
        let manifestLinkA = FileTreeManifest(rootDirectory: "/tmp/l1", entries: ["link": linkA], totalByteSize: 0, totalFileCount: 0, totalDirectoryCount: 0, totalSymlinkCount: 1)
        let manifestLinkB = FileTreeManifest(rootDirectory: "/tmp/l2", entries: ["link": linkB], totalByteSize: 0, totalFileCount: 0, totalDirectoryCount: 0, totalSymlinkCount: 1)
        let diffLinkReport = DifferentialManifestVerifier.compare(ttzip: manifestLinkA, oracle: manifestLinkB, format: .tar, oracleName: "test")
        XCTAssertFalse(diffLinkReport.isPassed)
        XCTAssertTrue(diffLinkReport.divergenceErrors.contains(where: { $0.contains("symlink target mismatch") }))
        
        // 6. POSIX mode mismatch detected
        let entryBadMode = ManifestEntry(
            relativePath: "test/file.txt",
            entryType: .regularFile,
            byteSize: 100,
            sha256Checksum: "aaaabbbbccccdddd",
            posixMode: 0o777,
            symlinkTarget: nil
        )
        let manifestBadMode = FileTreeManifest(rootDirectory: "/tmp/m", entries: ["test/file.txt": entryBadMode], totalByteSize: 100, totalFileCount: 1, totalDirectoryCount: 0, totalSymlinkCount: 0)
        let diffModeReport = DifferentialManifestVerifier.compare(ttzip: manifestBadMode, oracle: manifestA, format: .tar, oracleName: "test")
        XCTAssertFalse(diffModeReport.isPassed)
        XCTAssertTrue(diffModeReport.divergenceErrors.contains(where: { $0.contains("POSIX permission mismatch") }))
    }
    
    // MARK: - 7. Deep Hierarchy & SHA-256 Checksum Verification
    
    func testDirectoryHierarchyAndSha256Integrity() async throws {
        let sourceDir = try sandbox.createSubdirectory("deep_hierarchy_source")
        
        // Build 4-level deep directory structure
        let level1 = sourceDir.appendingPathComponent("l1")
        let level2 = level1.appendingPathComponent("l2")
        let level3 = level2.appendingPathComponent("l3")
        try FileManager.default.createDirectory(at: level3, withIntermediateDirectories: true)
        
        let file1 = level1.appendingPathComponent("f1.txt")
        let file2 = level2.appendingPathComponent("f2.txt")
        let file3 = level3.appendingPathComponent("f3.bin")
        
        try "Level 1 Payload\n".write(to: file1, atomically: true, encoding: .utf8)
        try "Level 2 Payload with extra characters\n".write(to: file2, atomically: true, encoding: .utf8)
        
        var randomBytes = [UInt8](repeating: 0, count: 16384)
        for i in 0..<randomBytes.count {
            randomBytes[i] = UInt8((i * 101 + 47) & 0xFF)
        }
        try Data(randomBytes).write(to: file3)
        
        let runSandbox = try sandbox.createSubdirectory("deep_run")
        
        let report = try await DifferentialOracleTestHarness.executeRoundtrip(
            format: .tar,
            sourceDir: sourceDir.path,
            oracle: "/usr/bin/tar",
            tempSandbox: runSandbox.path
        )
        
        XCTAssertTrue(report.isPassed, "Deep hierarchy roundtrip must pass: \(report.divergenceErrors)")
        XCTAssertEqual(report.ttzipManifest.totalFileCount, 3)
        XCTAssertGreaterThanOrEqual(report.ttzipManifest.totalDirectoryCount, 3)
        
        // Assert every file has a valid 64-character SHA-256 hash
        for (relPath, entry) in report.ttzipManifest.entries where entry.entryType == .regularFile {
            XCTAssertEqual(entry.sha256Checksum.count, 64, "SHA-256 for \(relPath) must be 64 hex characters")
        }
    }
    
    // MARK: - 8. Symlink Preservation & POSIX Permissions
    
    func testSymlinkPreservationAndPosixPermissions() async throws {
        let sourceDir = try sandbox.createSubdirectory("symlink_perm_source")
        
        let targetFile = sourceDir.appendingPathComponent("original.txt")
        try "Symlink target data payload.\n".write(to: targetFile, atomically: true, encoding: .utf8)
        
        // Set POSIX permissions 0o644
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: targetFile.path)
        
        // Create symlink
        let symlinkPath = sourceDir.appendingPathComponent("symlink_ref.txt").path
        try FileManager.default.createSymbolicLink(atPath: symlinkPath, withDestinationPath: "original.txt")
        
        let runSandbox = try sandbox.createSubdirectory("symlink_perm_run")
        
        let report = try await DifferentialOracleTestHarness.executeRoundtrip(
            format: .tar,
            sourceDir: sourceDir.path,
            oracle: "/usr/bin/tar",
            tempSandbox: runSandbox.path
        )
        
        XCTAssertTrue(report.isPassed, "Symlink & permission roundtrip must pass: \(report.divergenceErrors)")
        
        if let linkEntry = report.ttzipManifest.entries["symlink_ref.txt"] {
            XCTAssertEqual(linkEntry.entryType, .symbolicLink)
            XCTAssertEqual(linkEntry.symlinkTarget, "original.txt")
        } else {
            XCTFail("Missing symlink entry in extracted manifest")
        }
        
        if let origEntry = report.ttzipManifest.entries["original.txt"] {
            XCTAssertEqual(origEntry.entryType, .regularFile)
            XCTAssertEqual(origEntry.posixMode, 0o644)
        } else {
            XCTFail("Missing regular file entry in extracted manifest")
        }
    }
}
