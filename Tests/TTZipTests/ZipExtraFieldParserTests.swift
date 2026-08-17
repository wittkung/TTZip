//
//  ZipExtraFieldParserTests.swift
//  TTZipTests
//
//  Comprehensive test suite for ZipExtraFieldParser covering PKWARE & Info-ZIP Extra Fields.
//

import XCTest
@testable import TTZipCore

final class ZipExtraFieldParserTests: XCTestCase {

    // MARK: - Tag 0x5455: Extended Timestamp ("UT") Tests

    func testExtendedTimestampParsingAllThreeTimes() {
        let mtime: UInt32 = 1700000000
        let atime: UInt32 = 1700000100
        let ctime: UInt32 = 1700000200

        var payload: [UInt8] = [0x07] // Flags: Mod + Acc + Create
        payload.append(contentsOf: withUnsafeBytes(of: mtime.littleEndian) { Array($0) })
        payload.append(contentsOf: withUnsafeBytes(of: atime.littleEndian) { Array($0) })
        payload.append(contentsOf: withUnsafeBytes(of: ctime.littleEndian) { Array($0) })

        var rawData: [UInt8] = [0x55, 0x54] // Header ID 0x5455
        let size = UInt16(payload.count)
        rawData.append(contentsOf: withUnsafeBytes(of: size.littleEndian) { Array($0) })
        rawData.append(contentsOf: payload)

        let parsed = ZipExtraFieldParser.parse(extraData: rawData)
        XCTAssertNotNil(parsed.extendedTimestamp)
        guard let ts = parsed.extendedTimestamp else { return }

        XCTAssertEqual(ts.modificationTime?.timeIntervalSince1970, 1700000000)
        XCTAssertEqual(ts.accessTime?.timeIntervalSince1970, 1700000100)
        XCTAssertEqual(ts.creationTime?.timeIntervalSince1970, 1700000200)
        XCTAssertEqual(ts.modTime, ts.modificationTime)
        XCTAssertEqual(ts.accTime, ts.accessTime)
        XCTAssertEqual(ts.createTime, ts.creationTime)
    }

    func testExtendedTimestampParsingModTimeOnly() {
        let mtime: UInt32 = 1700000000

        var payload: [UInt8] = [0x01] // ModTime only
        payload.append(contentsOf: withUnsafeBytes(of: mtime.littleEndian) { Array($0) })

        var rawData: [UInt8] = [0x55, 0x54]
        let size = UInt16(payload.count)
        rawData.append(contentsOf: withUnsafeBytes(of: size.littleEndian) { Array($0) })
        rawData.append(contentsOf: payload)

        let parsed = ZipExtraFieldParser.parse(extraData: rawData)
        XCTAssertNotNil(parsed.extendedTimestamp)
        guard let ts = parsed.extendedTimestamp else { return }

        XCTAssertEqual(ts.modificationTime?.timeIntervalSince1970, 1700000000)
        XCTAssertNil(ts.accessTime)
        XCTAssertNil(ts.creationTime)
    }

    // MARK: - Tag 0x7075: Info-ZIP Unicode Path ("up") Tests

    func testUnicodePathMatchingCRC32() {
        let filename = "テスト/файл.txt"
        let standardFilename = "test/file.txt"
        let utf8Bytes = Array(filename.utf8)

        // Compute standard filename CRC32
        let stdUtf8 = Array(standardFilename.utf8)
        let stdCRC: UInt32 = stdUtf8.withUnsafeBytes { raw in
            NativeCoreArchitecture.shared.computeFastCRC32(buffer: raw.baseAddress!, length: raw.count)
        }

        var payload: [UInt8] = [0x01] // Version 1
        payload.append(contentsOf: withUnsafeBytes(of: stdCRC.littleEndian) { Array($0) })
        payload.append(contentsOf: utf8Bytes)

        var rawData: [UInt8] = [0x75, 0x70] // Header ID 0x7075 (LE)
        let size = UInt16(payload.count)
        rawData.append(contentsOf: withUnsafeBytes(of: size.littleEndian) { Array($0) })
        rawData.append(contentsOf: payload)

        let parsed = ZipExtraFieldParser.parse(extraData: rawData, standardFilename: standardFilename)
        XCTAssertEqual(parsed.unicodePath, filename)
    }

    func testUnicodePathMismatchingCRC32IsIgnored() {
        let filename = "unicode_name.txt"
        let standardFilename = "standard_name.txt"
        let modifiedFilename = "tampered_name.txt"
        let utf8Bytes = Array(filename.utf8)

        let stdUtf8 = Array(standardFilename.utf8)
        let stdCRC: UInt32 = stdUtf8.withUnsafeBytes { raw in
            NativeCoreArchitecture.shared.computeFastCRC32(buffer: raw.baseAddress!, length: raw.count)
        }

        var payload: [UInt8] = [0x01] // Version 1
        payload.append(contentsOf: withUnsafeBytes(of: stdCRC.littleEndian) { Array($0) })
        payload.append(contentsOf: utf8Bytes)

        var rawData: [UInt8] = [0x75, 0x70]
        let size = UInt16(payload.count)
        rawData.append(contentsOf: withUnsafeBytes(of: size.littleEndian) { Array($0) })
        rawData.append(contentsOf: payload)

        // Pass modified standard filename — CRC mismatch should result in nil unicodePath
        let parsed = ZipExtraFieldParser.parse(extraData: rawData, standardFilename: modifiedFilename)
        XCTAssertNil(parsed.unicodePath)
    }

    // MARK: - Tag 0x7875: Info-ZIP UNIX Extra Field (UID/GID) Tests

    func testInfoZipUnixUIDGIDParsing() {
        // Version: 1, UIDSize: 4 (UID = 501), GIDSize: 4 (GID = 20)
        let uid: UInt32 = 501
        let gid: UInt32 = 20

        var payload: [UInt8] = [
            0x01,                   // Version 1
            0x04                    // UIDSize = 4
        ]
        payload.append(contentsOf: withUnsafeBytes(of: uid.littleEndian) { Array($0) })
        payload.append(0x04)        // GIDSize = 4
        payload.append(contentsOf: withUnsafeBytes(of: gid.littleEndian) { Array($0) })

        var rawData: [UInt8] = [0x75, 0x78] // Header ID 0x7875 (LE)
        let size = UInt16(payload.count)
        rawData.append(contentsOf: withUnsafeBytes(of: size.littleEndian) { Array($0) })
        rawData.append(contentsOf: payload)

        let parsed = ZipExtraFieldParser.parse(extraData: rawData)
        XCTAssertNotNil(parsed.posixPermissions)
        if let perms = parsed.posixPermissions {
            XCTAssertEqual(perms.uid, 501)
            XCTAssertEqual(perms.gid, 20)
        }
    }

    // MARK: - Tag 0x0001: Zip64 Extended Information Tests

    func testZip64ExtraFieldParsing() {
        var payload: [UInt8] = []
        let uncompSize: UInt64 = 0x1_0000_0000 // 4GB
        let compSize: UInt64 = 0x8000_0000     // 2GB
        let relOffset: UInt64 = 0x2_0000_0000    // 8GB
        let diskNum: UInt32 = 2

        payload.append(contentsOf: withUnsafeBytes(of: uncompSize.littleEndian) { Array($0) })
        payload.append(contentsOf: withUnsafeBytes(of: compSize.littleEndian) { Array($0) })
        payload.append(contentsOf: withUnsafeBytes(of: relOffset.littleEndian) { Array($0) })
        payload.append(contentsOf: withUnsafeBytes(of: diskNum.littleEndian) { Array($0) })

        var rawData: [UInt8] = [0x01, 0x00] // Header ID 0x0001
        let size = UInt16(payload.count)
        rawData.append(contentsOf: withUnsafeBytes(of: size.littleEndian) { Array($0) })
        rawData.append(contentsOf: payload)

        let parsed = ZipExtraFieldParser.parse(extraData: rawData)
        XCTAssertNotNil(parsed.zip64Info)
        if let z64 = parsed.zip64Info {
            XCTAssertEqual(z64.uncompressedSize, 0x1_0000_0000)
            XCTAssertEqual(z64.compressedSize, 0x8000_0000)
            XCTAssertEqual(z64.relativeOffset, 0x2_0000_0000)
            XCTAssertEqual(z64.diskNumber, 2)
        }
    }

    // MARK: - Tag 0x9901: WinZip AES Tests

    func testWinZipAESExtraFieldParsing() {
        // Version: 2 (0x0002), Vendor ID: "AE" (0x4541), Strength: 3 (AES-256), Method: 8 (Deflate)
        let rawData: [UInt8] = [
            0x01, 0x99,             // Header ID 0x9901 (LE)
            0x07, 0x00,             // Data Size = 7
            0x02, 0x00,             // Version = 2
            0x41, 0x45,             // Vendor ID = 'A', 'E' (0x4541 LE)
            0x03,                   // Strength = 3 (256-bit)
            0x08, 0x00              // Actual Method = 8 (Deflate)
        ]

        let parsed = ZipExtraFieldParser.parse(extraData: rawData)
        XCTAssertNotNil(parsed.winZipAES)
        if let aes = parsed.winZipAES {
            XCTAssertEqual(aes.version, 2)
            XCTAssertEqual(aes.vendorID, 0x4541)
            XCTAssertEqual(aes.strength, .aes256)
            XCTAssertEqual(aes.actualMethod, 8)
        }
    }

    // MARK: - Multi-Tag TLV Chained Parsing

    func testChainedMultiTagParsing() {
        var multiData: [UInt8] = []

        // 1. Extended Timestamp (ModTime only: 5 bytes)
        let mtime: UInt32 = 1700000000
        var tsPayload: [UInt8] = [0x01]
        tsPayload.append(contentsOf: withUnsafeBytes(of: mtime.littleEndian) { Array($0) })
        multiData.append(contentsOf: [0x55, 0x54, 0x05, 0x00])
        multiData.append(contentsOf: tsPayload)

        // 2. WinZip AES (7 bytes)
        multiData.append(contentsOf: [0x01, 0x99, 0x07, 0x00, 0x02, 0x00, 0x41, 0x45, 0x03, 0x08, 0x00])

        // 3. POSIX UID/GID (1 + 1 + 2 + 1 + 2 = 7 bytes)
        let uid16: UInt16 = 1000
        let gid16: UInt16 = 100
        var posixPayload: [UInt8] = [0x01, 0x02]
        posixPayload.append(contentsOf: withUnsafeBytes(of: uid16.littleEndian) { Array($0) })
        posixPayload.append(0x02)
        posixPayload.append(contentsOf: withUnsafeBytes(of: gid16.littleEndian) { Array($0) })
        multiData.append(contentsOf: [0x75, 0x78, UInt8(posixPayload.count), 0x00])
        multiData.append(contentsOf: posixPayload)

        let parsed = ZipExtraFieldParser.parse(extraData: multiData)
        XCTAssertNotNil(parsed.extendedTimestamp)
        XCTAssertNotNil(parsed.winZipAES)
        XCTAssertNotNil(parsed.posixPermissions)

        XCTAssertEqual(parsed.extendedTimestamp?.modificationTime?.timeIntervalSince1970, 1700000000)
        XCTAssertEqual(parsed.winZipAES?.strength, .aes256)
        XCTAssertEqual(parsed.posixPermissions?.uid, 1000)
        XCTAssertEqual(parsed.posixPermissions?.gid, 100)
    }

    // MARK: - Edge Cases & Truncation Resilience

    func testEmptyAndTruncatedBufferResilience() {
        let empty = ZipExtraFieldParser.parse(extraData: [UInt8]())
        XCTAssertNil(empty.extendedTimestamp)
        XCTAssertNil(empty.unicodePath)
        XCTAssertNil(empty.posixPermissions)
        XCTAssertNil(empty.zip64Info)
        XCTAssertNil(empty.winZipAES)

        // Truncated header (only 3 bytes)
        let truncatedHeader = ZipExtraFieldParser.parse(extraData: [0x55, 0x54, 0x05])
        XCTAssertNil(truncatedHeader.extendedTimestamp)

        // Header claims 20 bytes payload but buffer only has 5 bytes
        let truncatedPayload = ZipExtraFieldParser.parse(extraData: [0x55, 0x54, 0x14, 0x00, 0x01, 0x02, 0x03])
        XCTAssertNil(truncatedPayload.extendedTimestamp)
    }
}
