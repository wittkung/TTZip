// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//
//  SystemDifferentialTests.swift
//  TTZipTests
//
//  Created for libarchive Differential Oracle Integration on 2026-08-16.
//

import XCTest
@testable import TTZipCore

final class SystemDifferentialTests: XCTestCase {
    
    private var sandboxDir: URL!
    
    override func setUpWithError() throws {
        sandboxDir = FileManager.default.temporaryDirectory.appendingPathComponent("TTZipSystemDiff_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: sandboxDir, withIntermediateDirectories: true)
    }
    
    override func tearDownWithError() throws {
        if let dir = sandboxDir {
            try? FileManager.default.removeItem(at: dir)
        }
    }
    
    // MARK: - 1. System Tool Availability & Differential Tests
    
    func testSystemTarUnzipAvailability() {
        let fileManager = FileManager.default
        let tarExists = fileManager.fileExists(atPath: "/usr/bin/tar")
        let unzipExists = fileManager.fileExists(atPath: "/usr/bin/unzip")
        
        XCTAssertTrue(tarExists, "/usr/bin/tar must be available on macOS")
        XCTAssertTrue(unzipExists, "/usr/bin/unzip must be available on macOS")
    }
    
    func testDifferentialTarCreationAndVerification() throws {
        let sourceFile = sandboxDir.appendingPathComponent("payload.txt")
        let testContent = "libarchive engineering excellence & differential oracle test payload.\n"
        try testContent.write(to: sourceFile, atomically: true, encoding: .utf8)
        
        let tarFile = sandboxDir.appendingPathComponent("output.tar")
        
        // Use system tar to package
        let tarProcess = Process()
        tarProcess.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        tarProcess.currentDirectoryURL = sandboxDir
        tarProcess.arguments = ["-cf", tarFile.lastPathComponent, sourceFile.lastPathComponent]
        try tarProcess.run()
        tarProcess.waitUntilExit()
        
        XCTAssertEqual(tarProcess.terminationStatus, 0, "System tar command must exit successfully")
        XCTAssertTrue(FileManager.default.fileExists(atPath: tarFile.path), "Tar archive must be created")
        
        // Validate tar file header
        let tarData = try Data(contentsOf: tarFile)
        XCTAssertGreaterThan(tarData.count, 512, "Tar file must contain at least 1 512-byte header")
        
        // Assert POSIX ustar magic at offset 257
        if tarData.count >= 512 {
            let magic = String(data: tarData.subdata(in: 257..<262), encoding: .ascii)
            XCTAssertTrue(magic == "ustar" || magic?.starts(with: "ustar") == true, "Archive must contain ustar magic")
        }
    }
    
    func testTTZipCompressToSystemUnzipDifferential() async throws {
        let sourceFile = sandboxDir.appendingPathComponent("ttzip_source.txt")
        let testContent = "TTZip High-Performance Compressor System Differential Payload 2026\n"
        try testContent.write(to: sourceFile, atomically: true, encoding: .utf8)
        
        let zipFile = sandboxDir.appendingPathComponent("ttzip_output.zip")
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: zipFile.path,
            format: .zip,
            level: .normal,
            inputPaths: [sourceFile.path]
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: zipFile.path), "TTZip archive must exist on disk")
        
        // Test extraction integrity with system /usr/bin/unzip -t
        let unzipProcess = Process()
        unzipProcess.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        unzipProcess.arguments = ["-t", zipFile.path]
        try unzipProcess.run()
        unzipProcess.waitUntilExit()
        XCTAssertEqual(unzipProcess.terminationStatus, 0, "System unzip -t must successfully verify TTZip archive")
    }
    
    func testSystemTarToTTZipExtractDifferential() async throws {
        let sourceFile = sandboxDir.appendingPathComponent("system_tar_payload.txt")
        let testContent = "Differential Oracle Cross Verification: System Tar to TTZip Extractor\n"
        try testContent.write(to: sourceFile, atomically: true, encoding: .utf8)
        
        let tarFile = sandboxDir.appendingPathComponent("system_created.tar")
        let tarProcess = Process()
        tarProcess.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        tarProcess.currentDirectoryURL = sandboxDir
        tarProcess.arguments = ["-cf", tarFile.lastPathComponent, sourceFile.lastPathComponent]
        try tarProcess.run()
        tarProcess.waitUntilExit()
        XCTAssertEqual(tarProcess.terminationStatus, 0)
        
        let extractDir = sandboxDir.appendingPathComponent("extracted_by_ttzip")
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
        
        let extractor = ArchiveExtractor()
        try await extractor.extract(
            archivePath: tarFile.path,
            destinationDir: extractDir.path,
            options: ArchiveFilterOptions()
        )
        
        let extractedFile = extractDir.appendingPathComponent(sourceFile.lastPathComponent)
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedFile.path))
        let extractedContent = try String(contentsOf: extractedFile, encoding: .utf8)
        XCTAssertEqual(extractedContent, testContent, "Extracted content must match original payload exactly")
    }
}
