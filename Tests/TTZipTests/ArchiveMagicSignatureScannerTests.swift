//
//  ArchiveMagicSignatureScannerTests.swift
//  TTZipTests
//
//  Comprehensive test suite for multi-anchor ArchiveMagicSignatureScanner.
//

import XCTest
@testable import TTZipCore

final class ArchiveMagicSignatureScannerTests: XCTestCase {

    // MARK: - Anchor Target Offset Calculation Tests

    func testTargetOffsetCalculations() {
        let fileSize: Int64 = 100_000

        // .head(offset)
        let headAnchor = ArchiveMagicSignature.Anchor.head(offset: 128)
        XCTAssertEqual(ArchiveMagicSignatureScanner.targetOffset(for: headAnchor, fileSize: fileSize), 128)

        // .tail(offsetFromEOF)
        let tailAnchor = ArchiveMagicSignature.Anchor.tail(offsetFromEOF: 512)
        XCTAssertEqual(ArchiveMagicSignatureScanner.targetOffset(for: tailAnchor, fileSize: fileSize), 99488)

        // .sector(sectorIndex, byteOffset)
        let sectorAnchor = ArchiveMagicSignature.Anchor.sector(sectorIndex: 16, byteOffset: 1)
        XCTAssertEqual(ArchiveMagicSignatureScanner.targetOffset(for: sectorAnchor, fileSize: fileSize), 32769) // 16 * 2048 + 1

        // .tarOffset(byteOffset)
        let tarAnchor = ArchiveMagicSignature.Anchor.tarOffset(byteOffset: 257)
        XCTAssertEqual(ArchiveMagicSignatureScanner.targetOffset(for: tarAnchor, fileSize: fileSize), 257)
    }

    // MARK: - Head Anchor Signature Matching Tests

    func testHeadAnchorMatching() {
        // ZIP Local File Header Magic: PK\x03\x04
        let zipSig = ArchiveMagicSignature(
            anchor: .head(offset: 0),
            bytes: [0x50, 0x4B, 0x03, 0x04],
            description: "ZIP Local File Header"
        )

        var zipData = Data([0x50, 0x4B, 0x03, 0x04, 0x14, 0x00, 0x00, 0x00])
        XCTAssertTrue(ArchiveMagicSignatureScanner.matchesSignature(zipSig, in: zipData))

        // Corrupt first byte
        zipData[0] = 0x51
        XCTAssertFalse(ArchiveMagicSignatureScanner.matchesSignature(zipSig, in: zipData))

        // Buffer too short
        let shortData = Data([0x50, 0x4B])
        XCTAssertFalse(ArchiveMagicSignatureScanner.matchesSignature(zipSig, in: shortData))
    }

    // MARK: - Tail Anchor Signature Matching Tests (DMG koly / ZIP EOCD)

    func testTailAnchorMatching() {
        // DMG koly trailer magic at EOF - 512
        let dmgSig = ArchiveMagicSignature(
            anchor: .tail(offsetFromEOF: 512),
            bytes: [0x6B, 0x6F, 0x6C, 0x79], // 'koly'
            description: "koly trailer"
        )

        let totalSize: Int = 1024
        var dmgBytes = [UInt8](repeating: 0x00, count: totalSize)
        // Set 'koly' at totalSize - 512 = 512
        dmgBytes[512] = 0x6B
        dmgBytes[513] = 0x6F
        dmgBytes[514] = 0x6C
        dmgBytes[515] = 0x79

        let data = Data(dmgBytes)
        XCTAssertTrue(ArchiveMagicSignatureScanner.matchesSignature(dmgSig, in: data, fileSize: Int64(totalSize)))

        // Non-matching tail
        var corruptedBytes = dmgBytes
        corruptedBytes[512] = 0x00
        XCTAssertFalse(ArchiveMagicSignatureScanner.matchesSignature(dmgSig, in: Data(corruptedBytes), fileSize: Int64(totalSize)))
    }

    // MARK: - Sector Anchor Signature Matching Tests (ISO 9660 CD001)

    func testSectorAnchorMatching() {
        // ISO 9660 Primary Volume Descriptor at Sector 16 (0x8000), Offset 1 -> 32769
        let isoSig = ArchiveMagicSignature(
            anchor: .sector(sectorIndex: 16, byteOffset: 1),
            bytes: [0x43, 0x44, 0x30, 0x30, 0x31], // "CD001"
            description: "ISO 9660 CD001"
        )

        let totalSize = 32768 + 2048 // 2 sectors
        var isoBytes = [UInt8](repeating: 0x00, count: totalSize)
        isoBytes[32769] = 0x43
        isoBytes[32770] = 0x44
        isoBytes[32771] = 0x30
        isoBytes[32772] = 0x30
        isoBytes[32773] = 0x31

        let data = Data(isoBytes)
        XCTAssertTrue(ArchiveMagicSignatureScanner.matchesSignature(isoSig, in: data, fileSize: Int64(totalSize)))

        // Corrupt CD001
        var corruptIso = isoBytes
        corruptIso[32769] = 0xFF
        XCTAssertFalse(ArchiveMagicSignatureScanner.matchesSignature(isoSig, in: Data(corruptIso), fileSize: Int64(totalSize)))
    }

    // MARK: - TarOffset Anchor Matching Tests (POSIX / GNU ustar)

    func testTarOffsetAnchorMatching() {
        let tarSig = ArchiveMagicSignature(
            anchor: .tarOffset(byteOffset: 257),
            bytes: [0x75, 0x73, 0x74, 0x61, 0x72, 0x00], // "ustar\0"
            description: "ustar\\0 POSIX.1-1988"
        )

        var tarHeader = [UInt8](repeating: 0x00, count: 512)
        tarHeader[257] = 0x75
        tarHeader[258] = 0x73
        tarHeader[259] = 0x74
        tarHeader[260] = 0x61
        tarHeader[261] = 0x72
        tarHeader[262] = 0x00

        let data = Data(tarHeader)
        XCTAssertTrue(ArchiveMagicSignatureScanner.matchesSignature(tarSig, in: data, fileSize: 512))

        var corruptTar = tarHeader
        corruptTar[257] = 0x00
        XCTAssertFalse(ArchiveMagicSignatureScanner.matchesSignature(tarSig, in: Data(corruptTar), fileSize: 512))
    }

    // MARK: - Format Detection in Buffer Tests

    func testDetectFormatBuffer() {
        // 1. 7Z
        let sevenZipData = Data([0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C, 0x00, 0x04])
        XCTAssertEqual(ArchiveMagicSignatureScanner.detectFormat(data: sevenZipData), .sevenZip)

        // 2. ZIP
        let zipData = Data([0x50, 0x4B, 0x03, 0x04, 0x14, 0x00, 0x00, 0x00])
        XCTAssertEqual(ArchiveMagicSignatureScanner.detectFormat(data: zipData), .zip)

        // 3. GZIP
        let gzData = Data([0x1F, 0x8B, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00])
        XCTAssertEqual(ArchiveMagicSignatureScanner.detectFormat(data: gzData), .gz)

        // 4. BZIP2
        let bz2Data = Data([0x42, 0x5A, 0x68, 0x39, 0x31, 0x41, 0x59, 0x26])
        XCTAssertEqual(ArchiveMagicSignatureScanner.detectFormat(data: bz2Data), .bz2)

        // 5. XZ
        let xzData = Data([0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00, 0x00, 0x00])
        XCTAssertEqual(ArchiveMagicSignatureScanner.detectFormat(data: xzData), .xz)

        // 6. ZSTD
        let zstdData = Data([0x28, 0xB5, 0x2F, 0xFD, 0x00, 0x00, 0x00, 0x00])
        XCTAssertEqual(ArchiveMagicSignatureScanner.detectFormat(data: zstdData), .zst)

        // 7. WIM
        let wimData = Data([0x4D, 0x53, 0x57, 0x49, 0x4D, 0x00, 0x00, 0x00])
        XCTAssertEqual(ArchiveMagicSignatureScanner.detectFormat(data: wimData), .wim)

        // 8. SNAPPY
        let snappyData = Data([0xFF, 0x06, 0x00, 0x00, 0x73, 0x4E, 0x61, 0x50, 0x70, 0x59])
        XCTAssertEqual(ArchiveMagicSignatureScanner.detectFormat(data: snappyData), .snappy)

        // 9. Apple Archive (AAR)
        let aarData = Data([0x41, 0x41, 0x30, 0x31, 0x00, 0x00, 0x00, 0x00])
        XCTAssertEqual(ArchiveMagicSignatureScanner.detectFormat(data: aarData), .aar)

        // 10. LZIP
        let lzipData = Data([0x4C, 0x5A, 0x49, 0x50, 0x01, 0x0C, 0x00, 0x00])
        XCTAssertEqual(ArchiveMagicSignatureScanner.detectFormat(data: lzipData), .lzip)

        // 11. LRZIP
        let lrzipData = Data([0x4C, 0x52, 0x5A, 0x49, 0x00, 0x00, 0x00, 0x00])
        XCTAssertEqual(ArchiveMagicSignatureScanner.detectFormat(data: lrzipData), .lrzip)

        // 12. LZ4
        let lz4Data = Data([0x04, 0x22, 0x4D, 0x18, 0x60, 0x70, 0x73, 0x00])
        XCTAssertEqual(ArchiveMagicSignatureScanner.detectFormat(data: lz4Data), .lz4)

        // 13. Unrecognized
        let garbage = Data([0xDE, 0xAD, 0xBE, 0xEF])
        XCTAssertNil(ArchiveMagicSignatureScanner.detectFormat(data: garbage))
    }

    // MARK: - FileHandle & URL Format Detection Tests

    func testDetectFormatFileURL() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Test 1: .tar.gz file with GZIP magic
        let tarGzURL = tempDir.appendingPathComponent("archive.tar.gz")
        let gzBytes: [UInt8] = [0x1F, 0x8B, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00]
        try Data(gzBytes).write(to: tarGzURL)

        let detectedTarGz = try ArchiveMagicSignatureScanner.detectFormat(fileURL: tarGzURL)
        XCTAssertEqual(detectedTarGz, .tarGz)

        // Test 2: pure .gz file with GZIP magic
        let gzURL = tempDir.appendingPathComponent("sample.gz")
        try Data(gzBytes).write(to: gzURL)

        let detectedGz = try ArchiveMagicSignatureScanner.detectFormat(fileURL: gzURL)
        XCTAssertEqual(detectedGz, .gz)

        // Test 3: .iso file with sector 16 CD001 magic
        let isoURL = tempDir.appendingPathComponent("disk.iso")
        var isoData = [UInt8](repeating: 0x00, count: 32768 + 2048)
        isoData[32769] = 0x43
        isoData[32770] = 0x44
        isoData[32771] = 0x30
        isoData[32772] = 0x30
        isoData[32773] = 0x31
        try Data(isoData).write(to: isoURL)

        let detectedIso = try ArchiveMagicSignatureScanner.detectFormat(fileURL: isoURL)
        XCTAssertEqual(detectedIso, .iso)

        // Test 4: .dmg file with koly trailer
        let dmgURL = tempDir.appendingPathComponent("image.dmg")
        var dmgData = [UInt8](repeating: 0x00, count: 1024)
        dmgData[512] = 0x6B
        dmgData[513] = 0x6F
        dmgData[514] = 0x6C
        dmgData[515] = 0x79
        try Data(dmgData).write(to: dmgURL)

        let detectedDmg = try ArchiveMagicSignatureScanner.detectFormat(fileURL: dmgURL)
        XCTAssertEqual(detectedDmg, .dmg)
    }
}
