// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore
import CTTZipBridge

final class SevenZipBridgeTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("7zBridgeTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir = tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        try super.tearDownWithError()
    }

    func testSevenZipNativeExtractionAndCompression() throws {
        let payloadDir = tempDir.appendingPathComponent("payload")
        try FileManager.default.createDirectory(at: payloadDir, withIntermediateDirectories: true)

        let testFile1 = payloadDir.appendingPathComponent("file1.txt")
        let testFile2 = payloadDir.appendingPathComponent("file2.txt")
        let content1 = "TTZip 7z Native Engine Core Verification Payload #1\n".data(using: .utf8)!
        let content2 = String(repeating: "TTZip High Throughput 7z Data Stream ", count: 1000).data(using: .utf8)!
        try content1.write(to: testFile1)
        try content2.write(to: testFile2)

        let archivePath = tempDir.appendingPathComponent("test_archive.7z").path
        let inputPaths = [payloadDir.path]

        let writer = SevenZipParallelWriter.shared
        let success = try writer.createArchive(
            outputPath: archivePath,
            inputPaths: inputPaths,
            level: .store,
            password: nil
        )

        XCTAssertTrue(success, "7z archive creation should succeed")
        XCTAssertTrue(FileManager.default.fileExists(atPath: archivePath), "Archive file should exist on disk")

        let extractDir = tempDir.appendingPathComponent("extracted")
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)

        let extractor = ArchiveExtractor()
        try extractor.extractSync(
            archivePath: archivePath,
            destinationDir: extractDir.path,
            password: nil
        )

        let extractedPayloadDir = extractDir.appendingPathComponent("payload")
        let extractedFile1 = extractedPayloadDir.appendingPathComponent("file1.txt")
        let extractedFile2 = extractedPayloadDir.appendingPathComponent("file2.txt")

        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedFile1.path), "Extracted file1 should exist")
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedFile2.path), "Extracted file2 should exist")

        let extContent1 = try Data(contentsOf: extractedFile1)
        let extContent2 = try Data(contentsOf: extractedFile2)
        XCTAssertEqual(extContent1, content1, "Extracted content 1 must match original payload 1 byte-for-byte")
        XCTAssertEqual(extContent2, content2, "Extracted content 2 must match original payload 2 byte-for-byte")
    }

    func testSevenZipEncryptedExtractionAndCompression() throws {
        let payloadDir = tempDir.appendingPathComponent("enc_payload")
        try FileManager.default.createDirectory(at: payloadDir, withIntermediateDirectories: true)

        let testFile = payloadDir.appendingPathComponent("secret.txt")
        let content = "Encrypted TTZip 7z AES-256 Payload Content".data(using: .utf8)!
        try content.write(to: testFile)

        let archivePath = tempDir.appendingPathComponent("encrypted_archive.7z").path
        let inputPaths = [payloadDir.path]
        let secretPass = "TTZipPass123"

        let writer = SevenZipParallelWriter.shared
        let success = try writer.createArchive(
            outputPath: archivePath,
            inputPaths: inputPaths,
            level: .normal,
            password: secretPass
        )

        XCTAssertTrue(success, "Encrypted 7z archive creation should succeed")
        XCTAssertTrue(FileManager.default.fileExists(atPath: archivePath), "Encrypted archive file should exist")

        let extractDir = tempDir.appendingPathComponent("enc_extracted")
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)

        let extractor = ArchiveExtractor()
        try extractor.extractSync(
            archivePath: archivePath,
            destinationDir: extractDir.path,
            password: secretPass
        )

        let extractedSecret = extractDir.appendingPathComponent("enc_payload").appendingPathComponent("secret.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedSecret.path), "Extracted encrypted secret file should exist")

        let extContent = try Data(contentsOf: extractedSecret)
        XCTAssertEqual(extContent, content, "Extracted encrypted content must match original payload byte-for-byte")
    }

    func testSevenZipMultiLevelCompressAndExtract() throws {
        let levels: [ArchiveCompressionLevel] = [.store, .fast, .normal, .ultra]
        for (idx, level) in levels.enumerated() {
            let isEncrypted = (idx % 2 == 1)
            let password = isEncrypted ? "PassLvl\(level.rawValue)" : nil
            let payloadDir = tempDir.appendingPathComponent("payload_lvl_\(level.rawValue)")
            try FileManager.default.createDirectory(at: payloadDir, withIntermediateDirectories: true)

            let testFile = payloadDir.appendingPathComponent("data_\(level.rawValue).bin")
            let contentData = Data((0..<100_000).map { UInt8(($0 + idx) % 256) })
            try contentData.write(to: testFile)

            let archivePath = tempDir.appendingPathComponent("arc_lvl_\(level.rawValue).7z").path

            let writer = ArchiveWriter()
            do {
                try writer.createArchiveSync(
                    outputPath: archivePath,
                    format: .sevenZip,
                    level: level,
                    inputPaths: [payloadDir.path],
                    password: password
                )
            } catch {
                XCTFail("Compression failed for level \(level.rawValue): \(error)")
                return
            }

            XCTAssertTrue(FileManager.default.fileExists(atPath: archivePath), "7z Level \(level.rawValue) archive should be created")

            let extractDir = tempDir.appendingPathComponent("out_lvl_\(level.rawValue)")
            try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)

            let extractor = ArchiveExtractor()
            do {
                try extractor.extractSync(
                    archivePath: archivePath,
                    destinationDir: extractDir.path,
                    password: password
                )
            } catch {
                XCTFail("Extraction failed for level \(level.rawValue) (enc=\(isEncrypted)): \(error)")
                return
            }

            let extractedFile = extractDir.appendingPathComponent("payload_lvl_\(level.rawValue)").appendingPathComponent("data_\(level.rawValue).bin")
            XCTAssertTrue(FileManager.default.fileExists(atPath: extractedFile.path), "Extracted Level \(level.rawValue) file should exist")

            let extractedData = try Data(contentsOf: extractedFile)
            XCTAssertEqual(extractedData, contentData, "Extracted data for Level \(level.rawValue) must match original byte-for-byte")
        }
    }

    func testSevenZipMultiStreamLZMA2ParallelDecompression() throws {
        let payloadDir = tempDir.appendingPathComponent("multi_stream_payload")
        try FileManager.default.createDirectory(at: payloadDir, withIntermediateDirectories: true)

        let bigFile = payloadDir.appendingPathComponent("big_data.bin")
        var bigData = Data(count: 2 * 1024 * 1024)
        bigData.withUnsafeMutableBytes { ptr in
            guard let base = ptr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            for i in 0..<(2 * 1024 * 1024) {
                base[i] = UInt8((i ^ (i >> 8)) & 0xFF)
            }
        }
        try bigData.write(to: bigFile)

        let archivePath = tempDir.appendingPathComponent("multi_stream.7z").path
        let writer = SevenZipEngine.shared
        let success = try writer.createArchive(
            outputPath: archivePath,
            inputPaths: [payloadDir.path],
            level: .normal,
            password: nil
        )
        XCTAssertTrue(success, "Multi-stream 7z archive creation must succeed")
        XCTAssertTrue(FileManager.default.fileExists(atPath: archivePath), "Archive file should exist")

        let extractDir = tempDir.appendingPathComponent("multi_stream_out")
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)

        let extractor = ArchiveExtractor()
        try extractor.extractSync(
            archivePath: archivePath,
            destinationDir: extractDir.path,
            password: nil
        )

        let extractedBigFile = extractDir.appendingPathComponent("multi_stream_payload").appendingPathComponent("big_data.bin")
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedBigFile.path), "Extracted big_data.bin should exist")

        let readData = try Data(contentsOf: extractedBigFile)
        XCTAssertEqual(readData, bigData, "Extracted multi-stream LZMA2 data must match original byte-for-byte")
    }

    func testARM64NeonBCJFilterRoundtrip() throws {
        // Construct simulated ARM64 instructions with B/BL jumps
        let rawInstructions: [UInt32] = [
            0xD503201F, // NOP
            0x14000008, // B +32
            0x94000010, // BL +64
            0xD503201F, // NOP
            0x52800000, // MOV W0, #0
            0xD65F03C0  // RET
        ]
        
        let originalBytes = rawInstructions.withUnsafeBufferPointer { Data(buffer: $0) }
        var buffer = originalBytes
        
        buffer.withUnsafeMutableBytes { ptr in
            guard let base = ptr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            _ = ttzip_arm64_bcj_encode_neon(base, ptr.count, 0x1000)
            _ = ttzip_arm64_bcj_decode_neon(base, ptr.count, 0x1000)
        }
        
        XCTAssertEqual(buffer, originalBytes, "ARM64 BCJ encode followed by decode must perfectly recover original instructions")
    }

    func testSevenZipSeekTableSingleFileExtraction() throws {
        let fileA = tempDir.appendingPathComponent("docA.txt")
        let fileB = tempDir.appendingPathComponent("docB.txt")
        let dataA = "Content of document A in 7z".data(using: .utf8)!
        let dataB = "Content of document B in 7z with extra payload".data(using: .utf8)!
        try dataA.write(to: fileA)
        try dataB.write(to: fileB)

        let archivePath = tempDir.appendingPathComponent("seek_test.7z").path
        let writer = SevenZipParallelWriter.shared
        let success = try writer.createArchive(
            outputPath: archivePath,
            inputPaths: [fileA.path, fileB.path],
            level: .store,
            password: nil
        )
        XCTAssertTrue(success, "7z archive creation must succeed")

        let entries = [
            SevenZipSeekTable.SeekEntry(
                path: "docA.txt",
                uncompressedSize: Int64(dataA.count),
                uncompressedOffset: 0,
                folderIndex: 0,
                crc32: 0,
                isDirectory: false,
                isEmptyStream: false
            ),
            SevenZipSeekTable.SeekEntry(
                path: "docB.txt",
                uncompressedSize: Int64(dataB.count),
                uncompressedOffset: Int64(dataA.count),
                folderIndex: 0,
                crc32: 0,
                isDirectory: false,
                isEmptyStream: false
            )
        ]

        let seekTable = SevenZipSeekTable(archivePath: archivePath, entries: entries)
        XCTAssertNotNil(seekTable.entry(forPath: "docA.txt"))
        XCTAssertNotNil(seekTable.entry(forPath: "docB.txt"))
        XCTAssertNil(seekTable.entry(forPath: "nonexistent.txt"))

        let singleExtractedA = seekTable.extractData(forPath: "docA.txt")
        XCTAssertEqual(singleExtractedA, dataA, "Single file extracted via SevenZipSeekTable must match original data")

        let singleExtractedB = seekTable.extractData(forPath: "docB.txt")
        XCTAssertEqual(singleExtractedB, dataB, "Single file B extracted via SevenZipSeekTable must match original data")
    }

    func testSevenZipNeonCryptoKdfAndAesDecrypt() throws {
        var key = [UInt8](repeating: 0, count: 32)
        let pass = "TTZipTestPassword2026"
        let salt: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]
        
        let kdfRes = ttzip_7z_kdf_sha256_neon(pass, salt, salt.count, 6, &key)
        XCTAssertEqual(kdfRes, 0, "7z NEON KDF SHA-256 derivation should succeed")
        XCTAssertFalse(key.allSatisfy { $0 == 0 }, "Derived key should not be all zero")

        let plainText = [UInt8]("Hello 7-Zip ARM64 NEON Hardware Crypto Acceleration!".utf8)
        // Pad to 16 bytes multiple for AES-CBC
        var padded = plainText
        while padded.count % 16 != 0 { padded.append(0) }

        var decrypted = [UInt8](repeating: 0, count: padded.count)
        let iv: [UInt8] = [UInt8](repeating: 0x42, count: 16)

        // Test decrypt function directly
        let decRes = ttzip_7z_aes256_cbc_decrypt_neon(key, iv, padded, padded.count, &decrypted)
        XCTAssertEqual(decRes, 0, "7z NEON AES-256-CBC decrypt should return success code")
    }

    func testSevenZipBranchlessRangeCoder() throws {
        var dummyData = [UInt8](repeating: 0x55, count: 64)
        dummyData[0] = 0x00 // Range coder header
        dummyData[1] = 0x12
        dummyData[2] = 0x34
        dummyData[3] = 0x56
        dummyData[4] = 0x78

        var rc = ttzip_lzma_rc_state_t()
        ttzip_lzma_rc_init(&rc, dummyData, dummyData.count)
        XCTAssertEqual(rc.corrupt, 0, "RC state should be clean upon initialization")
        XCTAssertEqual(rc.range, 0xFFFFFFFF, "Initial range should be 0xFFFFFFFF")

        var prob: UInt16 = 1024 // 50% probability
        let bit = ttzip_lzma_rc_decode_bit_branchless(&rc, &prob)
        XCTAssertTrue(bit == 0 || bit == 1, "Decoded bit must be binary")

        let direct = ttzip_lzma_rc_decode_direct_bits(&rc, 4)
        XCTAssertLessThanOrEqual(direct, 15, "4 direct bits must be <= 15")
    }

    func testSevenZipRadixMatchFinder() throws {
        var mf = ttzip_radix_mf_t()
        let initRes = ttzip_radix_mf_init(&mf, 1024 * 64)
        XCTAssertEqual(initRes, 0, "Radix MF initialization must succeed")
        defer { ttzip_radix_mf_free(&mf) }

        let testPattern = [UInt8]("The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog.".utf8)
        
        // Scan first half into radix table
        for i in 0..<44 {
            _ = ttzip_radix_mf_find_fast(&mf, testPattern, i, testPattern.count)
        }

        // Test second half match detection (should match the first "The quick brown...")
        let match = ttzip_radix_mf_find_fast(&mf, testPattern, 45, testPattern.count)
        XCTAssertGreaterThan(match.len, 10, "Radix MF should detect long repeated pattern >= 10 bytes")
        XCTAssertEqual(match.dist, 45, "Match distance should point exactly to the first sentence")
    }
}



