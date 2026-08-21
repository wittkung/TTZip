// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class ArchiveCompressionTypesTests: XCTestCase {
    
    func testArchiveCompressionFormatResolutions() {
        XCTAssertEqual(ArchiveCompressionFormat.from(extensionOrName: "zip"), .zip)
        XCTAssertEqual(ArchiveCompressionFormat.from(extensionOrName: ".7z"), .sevenZip)
        XCTAssertEqual(ArchiveCompressionFormat.from(extensionOrName: "tar.gz"), .tarGz)
        XCTAssertEqual(ArchiveCompressionFormat.from(extensionOrName: "tgz"), .tarGz)
        XCTAssertEqual(ArchiveCompressionFormat.from(extensionOrName: "tar.zst"), .tarZst)
        XCTAssertEqual(ArchiveCompressionFormat.from(extensionOrName: "tzst"), .tarZst)
        XCTAssertEqual(ArchiveCompressionFormat.from(extensionOrName: "dmg"), .dmg)
        XCTAssertEqual(ArchiveCompressionFormat.from(extensionOrName: "iso"), .iso)
        
        XCTAssertTrue(ArchiveCompressionFormat.isArchiveExtension("zip"))
        XCTAssertTrue(ArchiveCompressionFormat.isArchiveExtension("7z"))
        XCTAssertTrue(ArchiveCompressionFormat.isArchiveExtension("001", path: "archive.7z.001"))
        XCTAssertFalse(ArchiveCompressionFormat.isArchiveExtension("txt"))
        
        XCTAssertEqual(ArchiveCompressionFormat.kindDescription(forExtension: "zip", isArchive: false), "ZIP Archive")
        XCTAssertEqual(ArchiveCompressionFormat.kindDescription(forExtension: "txt", isArchive: false), "Text Document")
        XCTAssertEqual(ArchiveCompressionFormat.kindDescription(forExtension: "unknown", isArchive: true), "Archive Package")
    }
    
    func testArchiveCompressionLevelAndProfiles() {
        let level6 = ArchiveCompressionLevel(levelInt: 6)
        XCTAssertEqual(level6, .level6)
        XCTAssertEqual(level6.effectiveZipRawLevel, ZipCompressionProfile.extremePeak.deflateLevel)
        
        let store = ArchiveCompressionLevel.store
        XCTAssertEqual(store.effectiveZipRawLevel, 0)
        
        let ultra = ArchiveCompressionLevel.ultra
        XCTAssertEqual(ultra, .level9)
        
        let cloned = ArchiveAdvancedOptions.defaultOptions.clone()
        XCTAssertEqual(cloned.cpuThreads, ArchiveAdvancedOptions.defaultOptions.cpuThreads)
        XCTAssertEqual(cloned.zipOptions, ArchiveAdvancedOptions.defaultOptions.zipOptions)
    }
    
    func testArchiveEntryMetadataInteroperability() {
        let entry = ArchiveEntry(
            path: "docs/manual.pdf",
            uncompressedSize: 1024 * 1024,
            isDirectory: false,
            detectedEncoding: "UTF-8",
            isEncrypted: true,
            isDataEncrypted: true,
            encryptionMethod: "AES-256"
        )
        
        let metadata = ArchiveEntryMetadata(entry: entry)
        XCTAssertEqual(metadata.path, "docs/manual.pdf")
        XCTAssertEqual(metadata.uncompressedSize, 1024 * 1024)
        XCTAssertEqual(metadata.isDirectory, false)
        XCTAssertTrue(metadata.isEncrypted)
        XCTAssertEqual(metadata.encryptionMethod, "AES-256")
        XCTAssertEqual(metadata.mimeType, "application/pdf")
    }
    
    func testTypealiasesGateway() {
        let format: CompressionFormat = .zip
        XCTAssertEqual(format.fileExtension, ".zip")
        
        let level: CompressionLevel = .normal
        XCTAssertEqual(level.rawValue, 6)
        
        let options: CompressionOptions = .defaultOptions
        XCTAssertEqual(options.zipEncryptionMethod, "AES-256")
        
        let meta = EntryMetadata(path: "test.txt", uncompressedSize: 42)
        XCTAssertEqual(meta.id, "test.txt")
        XCTAssertEqual(meta.uncompressedSize, 42)
    }
}
