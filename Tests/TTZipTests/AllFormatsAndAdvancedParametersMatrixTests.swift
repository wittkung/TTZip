// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import Foundation
@testable import TTZipCore

/// 100%
/// 16 、 、 、 、 、 (LDM)、ZeroCopy
final class AllFormatsAndAdvancedParametersMatrixTests: XCTestCase {

    var tempDirPath: String!
    var sampleFiles: [String] = []

    override func setUpWithError() throws {
        try super.setUpWithError()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("MatrixTest_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        tempDirPath = tempDir.path

        // Verify expected invariant
        let subDir = (tempDirPath as NSString).appendingPathComponent("sub_folder")
        try FileManager.default.createDirectory(atPath: subDir, withIntermediateDirectories: true)

        let file1 = (tempDirPath as NSString).appendingPathComponent("doc1.txt")
        let file2 = (tempDirPath as NSString).appendingPathComponent("doc2.json")
        let file3 = (subDir as NSString).appendingPathComponent("nested.bin")

        try "Hello TTZip 2026 Native Engine Matrix Test".write(toFile: file1, atomically: true, encoding: .utf8)
        try "{\"engine\": \"TTZip\", \"version\": \"6.0\", \"inProcess\": true}".write(toFile: file2, atomically: true, encoding: .utf8)
        let binData = Data((0..<4096).map { UInt8($0 % 256) })
        try binData.write(to: URL(fileURLWithPath: file3))

        sampleFiles = [file1, file2, subDir]
    }

    override func tearDownWithError() throws {
        if let path = tempDirPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        try super.tearDownWithError()
    }

    // MARK: - 1. ZIP

    /// 1: ZIP + AES-256 + UTF-8 + POSIX + Level 6
    func testZip_AES256_UTF8_POSIX_Level6() async throws {
        let out = (tempDirPath as NSString).appendingPathComponent("zip_aes256.zip")
        let password = "SecretZipPassword#2026"
        let advOpts = ArchiveAdvancedOptions(
            cpuThreads: 4,
            zipOptions: ZipFormatOptions(
                zipEncryptionMethod: "AES-256",
                zipEncodingUTF8: true,
                preservePosixAttributes: true
            )
        )

        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: out,
            format: .zip,
            level: .level6,
            inputPaths: sampleFiles,
            password: password,
            advancedOptions: advOpts
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: out))

        let reader = ArchiveReader()
        let entries = try await reader.inspect(archivePath: out, password: password)
        XCTAssertGreaterThanOrEqual(entries.count, 2)

        let extractDir = (tempDirPath as NSString).appendingPathComponent("extracted_zip_aes256")
        let extractor = ArchiveExtractor()
        try await extractor.extract(archivePath: out, destinationDir: extractDir, password: password)

        let restoredFile1 = (extractDir as NSString).appendingPathComponent("doc1.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: restoredFile1))
    }

    /// 2: ZIP + Store (Level 0) + APFS Extent
    func testZip_Store_ZeroCopy() async throws {
        let out = (tempDirPath as NSString).appendingPathComponent("zip_zerocopy.zip")
        let advOpts = ArchiveAdvancedOptions(
            zipOptions: ZipFormatOptions(
                zip64Mode: "Always",
                enableZeroCopy: true
            )
        )

        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: out,
            format: .zip,
            level: .store,
            inputPaths: sampleFiles,
            advancedOptions: advOpts
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: out))

        let reader = ArchiveReader()
        let entries = try await reader.inspect(archivePath: out)
        XCTAssertGreaterThanOrEqual(entries.count, 2)

        let extractDir = (tempDirPath as NSString).appendingPathComponent("extracted_zip_store")
        let extractor = ArchiveExtractor()
        try await extractor.extract(archivePath: out, destinationDir: extractDir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: (extractDir as NSString).appendingPathComponent("doc1.txt")))
    }

    /// 3: ZIP + (50KB/ ) + AES-256
    func testZip_SplitVolume_Encrypted() async throws {
        let out = (tempDirPath as NSString).appendingPathComponent("split_zip.zip")
        let password = "SplitZipPassword2026"
        let splitSize: Int64 = 50 * 1024 // 50KB

        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: out,
            format: .zip,
            level: .level1,
            inputPaths: sampleFiles,
            splitVolumeSizeBytes: splitSize,
            password: password
        )

        let part1 = (tempDirPath as NSString).appendingPathComponent("split_zip.zip.001")
        XCTAssertTrue(FileManager.default.fileExists(atPath: part1) || FileManager.default.fileExists(atPath: out))

        let targetArchive = FileManager.default.fileExists(atPath: part1) ? part1 : out
        let reader = ArchiveReader()
        let entries = try await reader.inspect(archivePath: targetArchive, password: password)
        XCTAssertFalse(entries.isEmpty)

        let extractDir = (tempDirPath as NSString).appendingPathComponent("extracted_zip_split")
        let extractor = ArchiveExtractor()
        try await extractor.extract(archivePath: targetArchive, destinationDir: extractDir, password: password)
        XCTAssertTrue(FileManager.default.fileExists(atPath: (extractDir as NSString).appendingPathComponent("doc1.txt")))
    }

    // MARK: - 2. 7Z

    /// 4: 7Z + LZMA2 + 64MB + + (mhe=on)
    func testSevenZip_LZMA2_Solid_HeaderEncryption() async throws {
        let out = (tempDirPath as NSString).appendingPathComponent("7z_header_enc.7z")
        let password = "HeaderEncPassword2026"
        let advOpts = ArchiveAdvancedOptions(
            sevenZipOptions: SevenZipFormatOptions(
                algorithm: "LZMA2",
                dictionarySizeMB: 64,
                enableSolidArchive: true,
                encryptFileNames: true
            )
        )

        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: out,
            format: .sevenZip,
            level: .level9,
            inputPaths: sampleFiles,
            password: password,
            advancedOptions: advOpts
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: out))

        let reader = ArchiveReader()
        let entries = try await reader.inspect(archivePath: out, password: password)
        XCTAssertFalse(entries.isEmpty)

        let extractDir = (tempDirPath as NSString).appendingPathComponent("extracted_7z_solid")
        let extractor = ArchiveExtractor()
        try await extractor.extract(archivePath: out, destinationDir: extractDir, password: password)
        XCTAssertTrue(FileManager.default.fileExists(atPath: (extractDir as NSString).appendingPathComponent("doc1.txt")))
    }

    /// 5: 7Z + (50KB/ ) +
    func testSevenZip_SplitVolume_Password() async throws {
        let out = (tempDirPath as NSString).appendingPathComponent("split_7z.7z")
        let password = "7zSplitPassword2026"
        let splitSize: Int64 = 50 * 1024

        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: out,
            format: .sevenZip,
            level: .level1,
            inputPaths: sampleFiles,
            splitVolumeSizeBytes: splitSize,
            password: password
        )

        let part1 = (tempDirPath as NSString).appendingPathComponent("split_7z.7z.001")
        XCTAssertTrue(FileManager.default.fileExists(atPath: part1) || FileManager.default.fileExists(atPath: out))

        let targetArchive = FileManager.default.fileExists(atPath: part1) ? part1 : out
        let reader = ArchiveReader()
        let entries = try await reader.inspect(archivePath: targetArchive, password: password)
        XCTAssertFalse(entries.isEmpty)

        let extractDir = (tempDirPath as NSString).appendingPathComponent("extracted_7z_split")
        let extractor = ArchiveExtractor()
        try await extractor.extract(archivePath: targetArchive, destinationDir: extractDir, password: password)
        XCTAssertTrue(FileManager.default.fileExists(atPath: (extractDir as NSString).appendingPathComponent("doc1.txt")))
    }

    // MARK: - 3. ZSTD

    /// 6: ZSTD + Long Distance Matching (LDM) + WindowLog 27 + Level 19
    func testZstd_LDM_UltraLevel19() async throws {
        let out = (tempDirPath as NSString).appendingPathComponent("test_ldm.tar.zst")
        let advOpts = ArchiveAdvancedOptions(
            zstdOptions: ZstdFormatOptions(
                zstdLevel: 19,
                zstdEnableLDM: true,
                zstdJobSizeMB: 128,
                zstdWindowLog: 27,
                zstdChecksum: true
            )
        )

        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: out,
            format: .tarZst,
            level: .level19,
            inputPaths: sampleFiles,
            advancedOptions: advOpts
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: out))

        let reader = ArchiveReader()
        let entries = try await reader.inspect(archivePath: out)
        XCTAssertFalse(entries.isEmpty)

        let extractDir = (tempDirPath as NSString).appendingPathComponent("extracted_zstd_ldm")
        let extractor = ArchiveExtractor()
        try await extractor.extract(archivePath: out, destinationDir: extractDir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: (extractDir as NSString).appendingPathComponent("doc1.txt")))
    }

    /// 7: ZSTD (Level -3)
    func testZstd_FastNegativeLevel() async throws {
        let out = (tempDirPath as NSString).appendingPathComponent("test_fast.tar.zst")
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: out,
            format: .tarZst,
            level: .fast3,
            inputPaths: sampleFiles
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: out))

        let reader = ArchiveReader()
        let entries = try await reader.inspect(archivePath: out)
        XCTAssertFalse(entries.isEmpty)
    }

    // MARK: - 4. 16 、

    /// : Apple Archive (AAR)
    func testFormat_AAR() async throws {
        throw XCTSkip("AAR format creation requires AppleArchive framework, skipping creation")
    }

    /// : DMG
    func testFormat_DMG() async throws {
        let out = (tempDirPath as NSString).appendingPathComponent("image.dmg")
        let writer = ArchiveWriter()
        try await writer.createArchive(outputPath: out, format: .dmg, inputPaths: sampleFiles)
        XCTAssertTrue(FileManager.default.fileExists(atPath: out))

        let reader = ArchiveReader()
        let entries = try await reader.inspect(archivePath: out)
        XCTAssertFalse(entries.isEmpty)

        let extractDir = (tempDirPath as NSString).appendingPathComponent("extracted_dmg")
        let extractor = ArchiveExtractor()
        try await extractor.extract(archivePath: out, destinationDir: extractDir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: (extractDir as NSString).appendingPathComponent("doc1.txt")))
    }

    /// : ISO
    func testFormat_ISO() async throws {
        let out = (tempDirPath as NSString).appendingPathComponent("image.iso")
        let writer = ArchiveWriter()
        try await writer.createArchive(outputPath: out, format: .iso, inputPaths: sampleFiles)
        XCTAssertTrue(FileManager.default.fileExists(atPath: out))

        let reader = ArchiveReader()
        let entries = try await reader.inspect(archivePath: out)
        XCTAssertFalse(entries.isEmpty)

        let extractDir = (tempDirPath as NSString).appendingPathComponent("extracted_iso")
        let extractor = ArchiveExtractor()
        try await extractor.extract(archivePath: out, destinationDir: extractDir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: (extractDir as NSString).appendingPathComponent("doc1.txt")))
    }

    /// : WIM
    func testFormat_WIM() async throws {
        let out = (tempDirPath as NSString).appendingPathComponent("archive.wim")
        let writer = ArchiveWriter()
        try await writer.createArchive(outputPath: out, format: .wim, inputPaths: sampleFiles)
        XCTAssertTrue(FileManager.default.fileExists(atPath: out))

        let reader = ArchiveReader()
        let entries = try await reader.inspect(archivePath: out)
        XCTAssertFalse(entries.isEmpty)

        let extractDir = (tempDirPath as NSString).appendingPathComponent("extracted_wim")
        let extractor = ArchiveExtractor()
        try await extractor.extract(archivePath: out, destinationDir: extractDir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: (extractDir as NSString).appendingPathComponent("doc1.txt")))
    }

    /// : TAR ( POSIX )
    func testFormat_TAR() async throws {
        let out = (tempDirPath as NSString).appendingPathComponent("archive.tar")
        let writer = ArchiveWriter()
        try await writer.createArchive(outputPath: out, format: .tar, level: .store, inputPaths: sampleFiles)
        XCTAssertTrue(FileManager.default.fileExists(atPath: out))

        let reader = ArchiveReader()
        let entries = try await reader.inspect(archivePath: out)
        XCTAssertFalse(entries.isEmpty)

        let extractDir = (tempDirPath as NSString).appendingPathComponent("extracted_tar")
        let extractor = ArchiveExtractor()
        try await extractor.extract(archivePath: out, destinationDir: extractDir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: (extractDir as NSString).appendingPathComponent("doc1.txt")))
    }

    /// : GZIP (tar.gz)
    func testFormat_GZIP() async throws {
        let out = (tempDirPath as NSString).appendingPathComponent("archive.tar.gz")
        let writer = ArchiveWriter()
        try await writer.createArchive(outputPath: out, format: .tarGz, level: .level6, inputPaths: sampleFiles)
        XCTAssertTrue(FileManager.default.fileExists(atPath: out))

        let reader = ArchiveReader()
        let entries = try await reader.inspect(archivePath: out)
        XCTAssertFalse(entries.isEmpty)

        let extractDir = (tempDirPath as NSString).appendingPathComponent("extracted_targz")
        let extractor = ArchiveExtractor()
        try await extractor.extract(archivePath: out, destinationDir: extractDir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: (extractDir as NSString).appendingPathComponent("doc1.txt")))
    }

    /// : BZIP2 (tar.bz2)
    func testFormat_BZIP2() async throws {
        let out = (tempDirPath as NSString).appendingPathComponent("archive.tar.bz2")
        let writer = ArchiveWriter()
        try await writer.createArchive(outputPath: out, format: .tarBz2, level: .level6, inputPaths: sampleFiles)
        XCTAssertTrue(FileManager.default.fileExists(atPath: out))

        let reader = ArchiveReader()
        let entries = try await reader.inspect(archivePath: out)
        XCTAssertFalse(entries.isEmpty)

        let extractDir = (tempDirPath as NSString).appendingPathComponent("extracted_tarbz2")
        let extractor = ArchiveExtractor()
        try await extractor.extract(archivePath: out, destinationDir: extractDir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: (extractDir as NSString).appendingPathComponent("doc1.txt")))
    }

    /// : XZ (tar.xz)
    func testFormat_XZ() async throws {
        let out = (tempDirPath as NSString).appendingPathComponent("archive.tar.xz")
        let writer = ArchiveWriter()
        try await writer.createArchive(outputPath: out, format: .tarXz, level: .level6, inputPaths: sampleFiles)
        XCTAssertTrue(FileManager.default.fileExists(atPath: out))

        let reader = ArchiveReader()
        let entries = try await reader.inspect(archivePath: out)
        XCTAssertFalse(entries.isEmpty)

        let extractDir = (tempDirPath as NSString).appendingPathComponent("extracted_tarxz")
        let extractor = ArchiveExtractor()
        try await extractor.extract(archivePath: out, destinationDir: extractDir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: (extractDir as NSString).appendingPathComponent("doc1.txt")))
    }

    /// : LZIP (tar.lz)
    func testFormat_LZIP() async throws {
        let out = (tempDirPath as NSString).appendingPathComponent("archive.tar.lz")
        let writer = ArchiveWriter()
        try await writer.createArchive(outputPath: out, format: .lzip, level: .level6, inputPaths: sampleFiles)
        XCTAssertTrue(FileManager.default.fileExists(atPath: out))

        let reader = ArchiveReader()
        let entries = try await reader.inspect(archivePath: out)
        XCTAssertFalse(entries.isEmpty)

        let extractDir = (tempDirPath as NSString).appendingPathComponent("extracted_lzip")
        let extractor = ArchiveExtractor()
        try await extractor.extract(archivePath: out, destinationDir: extractDir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: (extractDir as NSString).appendingPathComponent("doc1.txt")))
    }

    /// : LZ4 (tar.lz4)
    func testFormat_LZ4() async throws {
        let out = (tempDirPath as NSString).appendingPathComponent("archive.tar.lz4")
        let writer = ArchiveWriter()
        try await writer.createArchive(outputPath: out, format: .lz4, level: .level1, inputPaths: sampleFiles)
        XCTAssertTrue(FileManager.default.fileExists(atPath: out))

        let reader = ArchiveReader()
        let entries = try await reader.inspect(archivePath: out)
        XCTAssertFalse(entries.isEmpty)

        let extractDir = (tempDirPath as NSString).appendingPathComponent("extracted_lz4")
        let extractor = ArchiveExtractor()
        try await extractor.extract(archivePath: out, destinationDir: extractDir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: (extractDir as NSString).appendingPathComponent("doc1.txt")))
    }

    /// : BROTLI
    func testFormat_BROTLI() async throws {
        throw XCTSkip("BROTLI format decompression is fully supported, native creation requires external filter, libbrotli 写过滤器，skipping creation")
    }

    /// : LRZIP
    func testFormat_LRZIP() async throws {
        let out = (tempDirPath as NSString).appendingPathComponent("archive.tar.lrz")
        let writer = ArchiveWriter()
        try await writer.createArchive(outputPath: out, format: .lrzip, level: .level1, inputPaths: sampleFiles)
        XCTAssertTrue(FileManager.default.fileExists(atPath: out))

        let reader = ArchiveReader()
        let entries = try await reader.inspect(archivePath: out)
        XCTAssertFalse(entries.isEmpty)

        let extractDir = (tempDirPath as NSString).appendingPathComponent("extracted_lrz")
        let extractor = ArchiveExtractor()
        try await extractor.extract(archivePath: out, destinationDir: extractDir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: (extractDir as NSString).appendingPathComponent("doc1.txt")))
    }

    /// : SNAPPY (In-Process Native Google Snappy Engine)
    func testFormat_SNAPPY() async throws {
        let out = (tempDirPath as NSString).appendingPathComponent("archive.tar.sz")
        let writer = ArchiveWriter()
        try await writer.createArchive(outputPath: out, format: .snappy, level: .level1, inputPaths: sampleFiles)
        XCTAssertTrue(FileManager.default.fileExists(atPath: out))

        let reader = ArchiveReader()
        let entries = try await reader.inspect(archivePath: out)
        XCTAssertFalse(entries.isEmpty)

        let extractDir = (tempDirPath as NSString).appendingPathComponent("extracted_snappy")
        let extractor = ArchiveExtractor()
        try await extractor.extract(archivePath: out, destinationDir: extractDir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: (extractDir as NSString).appendingPathComponent("doc1.txt")))
        XCTAssertTrue(FileManager.default.fileExists(atPath: (extractDir as NSString).appendingPathComponent("doc2.json")))
    }
}
