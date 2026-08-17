//
//  ArchiveStandardsComplianceTests.swift
//  TTZipTests
//
//  Comprehensive test suite for ArchiveFormatStandardRegistry and StandardsComplianceChecker.
//  Validates all 16 compression/archive format registrations and header compliance.
//

import XCTest
@testable import TTZipCore

final class ArchiveStandardsComplianceTests: XCTestCase {

    private var tempDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TTZipStandardsTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        if let temp = tempDirectory {
            try? FileManager.default.removeItem(at: temp)
        }
        try await super.tearDown()
    }

    // MARK: - 1. Format Standards Registry Coverage

    func testAllSixteenFormatsRegisteredInRegistry() {
        let registry = ArchiveFormatStandardRegistry.shared
        let allSixteenFormats: [ArchiveCompressionFormat] = [
            .zip,
            .sevenZip,
            .tar,
            .gz,
            .bz2,
            .xz,
            .zst,
            .lzip,
            .lz4,
            .brotli,
            .lrzip,
            .aar,
            .snappy,
            .wim,
            .dmg,
            .iso
        ]

        for format in allSixteenFormats {
            let spec = registry.spec(for: format)
            XCTAssertNotNil(spec, "Format standard spec must be registered for \(format.rawValue)")
            guard let spec = spec else { continue }

            XCTAssertEqual(spec.format, format)
            XCTAssertFalse(spec.officialName.isEmpty, "Official name must not be empty for \(format.rawValue)")
            XCTAssertFalse(spec.mimeType.isEmpty, "MIME type must not be empty for \(format.rawValue)")
            XCTAssertFalse(spec.appleUTI.isEmpty, "Apple UTI must not be empty for \(format.rawValue)")
            XCTAssertFalse(spec.standardCitations.isEmpty, "Standard citations must not be empty for \(format.rawValue)")

            for citation in spec.standardCitations {
                XCTAssertFalse(citation.organization.isEmpty, "Citation organization must not be empty for \(format.rawValue)")
                XCTAssertFalse(citation.standardNumber.isEmpty, "Citation standard number must not be empty for \(format.rawValue)")
                XCTAssertFalse(citation.title.isEmpty, "Citation title must not be empty for \(format.rawValue)")
                XCTAssertFalse(citation.canonicalURL.isEmpty, "Citation canonical URL must not be empty for \(format.rawValue)")
            }
        }

        // Test compound formats
        let compoundFormats: [ArchiveCompressionFormat] = [.tarGz, .tarBz2, .tarXz, .tarZst]
        for format in compoundFormats {
            let spec = registry.spec(for: format)
            XCTAssertNotNil(spec, "Format standard spec must be registered for compound format \(format.rawValue)")
        }

        // Test lookup by identifier ID string
        XCTAssertNotNil(registry.spec(forId: "zip"))
        XCTAssertNotNil(registry.spec(forId: "7z"))
        XCTAssertNotNil(registry.spec(forId: "tar"))
        XCTAssertNotNil(registry.spec(forId: "tar.gz"))
        XCTAssertNotNil(registry.spec(forId: "zst"))

        // Assert all registered specs count
        XCTAssertGreaterThanOrEqual(registry.allSpecs().count, 16)
    }

    // MARK: - 2. Real ZIP Compliance Testing

    func testZipStandardsComplianceWithRealArchive() async throws {
        let sampleFileURL = tempDirectory.appendingPathComponent("sample.txt")
        let sampleContent = "PKWARE APPNOTE.TXT Standards Compliance Test Data payload."
        try sampleContent.write(to: sampleFileURL, atomically: true, encoding: .utf8)

        let zipOutputURL = tempDirectory.appendingPathComponent("output.zip")
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: zipOutputURL.path,
            format: .zip,
            level: .normal,
            inputPaths: [sampleFileURL.path]
        )

        let report = try StandardsComplianceChecker.checkCompliance(fileURL: zipOutputURL, expectedFormat: .zip)

        XCTAssertTrue(report.isCompliant, "Real ZIP archive must be standards compliant. Violations: \(report.violations)")
        XCTAssertEqual(report.format, .zip)
        XCTAssertNotNil(report.standardCitation)
        XCTAssertEqual(report.standardCitation?.organization, "PKWARE")
        XCTAssertTrue(report.violations.isEmpty)

        XCTAssertTrue(report.validatedHeaders.contains { $0.contains("Local File Header Signature") })
        XCTAssertTrue(report.validatedHeaders.contains { $0.contains("End of Central Directory Record") })
    }

    // MARK: - 3. Real TAR Compliance Testing

    func testTarStandardsComplianceWithRealArchive() async throws {
        let sampleFileURL = tempDirectory.appendingPathComponent("tar_sample.txt")
        try "POSIX.1-2001 Pax/ustar standard tarball content".write(to: sampleFileURL, atomically: true, encoding: .utf8)

        let tarOutputURL = tempDirectory.appendingPathComponent("output.tar")
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: tarOutputURL.path,
            format: .tar,
            level: .normal,
            inputPaths: [sampleFileURL.path]
        )

        let report = try StandardsComplianceChecker.checkCompliance(fileURL: tarOutputURL, expectedFormat: .tar)

        XCTAssertTrue(report.isCompliant, "Real TAR archive must be standards compliant. Violations: \(report.violations)")
        XCTAssertEqual(report.format, .tar)
        XCTAssertNotNil(report.standardCitation)
        XCTAssertEqual(report.standardCitation?.organization, "IEEE / The Open Group")
        XCTAssertTrue(report.violations.isEmpty)

        XCTAssertTrue(report.validatedHeaders.contains { $0.contains("ustar Magic Header") })
        XCTAssertTrue(report.validatedHeaders.contains { $0.contains("Header Octal Checksum") })
    }

    // MARK: - 4. Real GZIP Compliance Testing

    func testGzipStandardsComplianceWithRealArchive() async throws {
        let sampleFileURL = tempDirectory.appendingPathComponent("gzip_sample.txt")
        try "RFC 1952 GZIP standard compliance payload".write(to: sampleFileURL, atomically: true, encoding: .utf8)

        let gzOutputURL = tempDirectory.appendingPathComponent("output.tar.gz")
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: gzOutputURL.path,
            format: .tarGz,
            level: .normal,
            inputPaths: [sampleFileURL.path]
        )

        let report = try StandardsComplianceChecker.checkCompliance(fileURL: gzOutputURL, expectedFormat: .tarGz)

        XCTAssertTrue(report.isCompliant, "Real GZIP archive must be standards compliant. Violations: \(report.violations)")
        XCTAssertEqual(report.format, .tarGz)
        XCTAssertNotNil(report.standardCitation)
        XCTAssertTrue(report.violations.isEmpty)

        XCTAssertTrue(report.validatedHeaders.contains { $0.contains("GZIP Member ID1/ID2 Header Magic (0x1F8B)") })
        XCTAssertTrue(report.validatedHeaders.contains { $0.contains("Compression Method DEFLATE (CM=8)") })
    }

    // MARK: - 5. Real Zstandard Compliance Testing

    func testZstandardStandardsComplianceWithRealArchive() async throws {
        let sampleFileURL = tempDirectory.appendingPathComponent("zstd_sample.txt")
        try "RFC 8878 Zstandard Frame header compliance test".write(to: sampleFileURL, atomically: true, encoding: .utf8)

        let zstOutputURL = tempDirectory.appendingPathComponent("output.tar.zst")
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: zstOutputURL.path,
            format: .tarZst,
            level: .fast,
            inputPaths: [sampleFileURL.path]
        )

        let report = try StandardsComplianceChecker.checkCompliance(fileURL: zstOutputURL, expectedFormat: .tarZst)

        XCTAssertTrue(report.isCompliant, "Real Zstandard archive must be standards compliant. Violations: \(report.violations)")
        XCTAssertEqual(report.format, .tarZst)
        XCTAssertNotNil(report.standardCitation)
        XCTAssertTrue(report.violations.isEmpty)

        XCTAssertTrue(report.validatedHeaders.contains { $0.contains("Zstandard Frame Magic Number (0xFD2FB528)") })
        XCTAssertTrue(report.validatedHeaders.contains { $0.contains("Frame Header Descriptor (FHD)") })
    }

    // MARK: - 6. Real 7-Zip Compliance Testing

    func testSevenZipStandardsComplianceWithRealArchive() async throws {
        let sampleFileURL = tempDirectory.appendingPathComponent("7z_sample.txt")
        try "7-Zip 24.08 format specification compliance test".write(to: sampleFileURL, atomically: true, encoding: .utf8)

        let sevenZipOutputURL = tempDirectory.appendingPathComponent("output.7z")
        let writer = ArchiveWriter()
        try await writer.createArchive(
            outputPath: sevenZipOutputURL.path,
            format: .sevenZip,
            level: .normal,
            inputPaths: [sampleFileURL.path]
        )

        let report = try StandardsComplianceChecker.checkCompliance(fileURL: sevenZipOutputURL, expectedFormat: .sevenZip)

        XCTAssertTrue(report.isCompliant, "Real 7Z archive must be standards compliant. Violations: \(report.violations)")
        XCTAssertEqual(report.format, .sevenZip)
        XCTAssertNotNil(report.standardCitation)
        XCTAssertEqual(report.standardCitation?.organization, "Igor Pavlov / 7-Zip")
        XCTAssertTrue(report.violations.isEmpty)

        XCTAssertTrue(report.validatedHeaders.contains { $0.contains("7z Signature Header Magic (0x377ABCAF271C)") })
        XCTAssertTrue(report.validatedHeaders.contains { $0.contains("Signature Header Version and StartHeaderCRC") })
    }

    // MARK: - 7. Synthetic Standard Headers for Additional Formats

    func testBzip2HeaderCompliance() throws {
        // BZh9 + pi block magic (0x314159265359)
        let bz2Data = Data([0x42, 0x5A, 0x68, 0x39, 0x31, 0x41, 0x59, 0x26, 0x53, 0x59, 0x00, 0x00, 0x00, 0x00])
        let report = try StandardsComplianceChecker.checkCompliance(data: bz2Data, expectedFormat: .bz2)
        XCTAssertTrue(report.isCompliant)
        XCTAssertEqual(report.format, .bz2)
        XCTAssertTrue(report.validatedHeaders.contains { $0.contains("BZh Header Magic") })
    }

    func testXzHeaderCompliance() throws {
        // \xFD7zXZ\x00 stream header + stream flags + CRC
        var xzData = Data([0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00, 0x00, 0x01, 0x69, 0x22, 0xDE, 0x36])
        // Append footer with 'YZ'
        xzData.append(contentsOf: [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x59, 0x5A])
        let report = try StandardsComplianceChecker.checkCompliance(data: xzData, expectedFormat: .xz)
        XCTAssertTrue(report.isCompliant)
        XCTAssertEqual(report.format, .xz)
        XCTAssertTrue(report.validatedHeaders.contains { $0.contains("Stream Header Magic") })
    }

    func testLz4HeaderCompliance() throws {
        let lz4Data = Data([0x04, 0x22, 0x4D, 0x18, 0x64, 0x70, 0xB9, 0x05, 0x00, 0x00, 0x00, 0x68, 0x65, 0x6C, 0x6C, 0x6F])
        let report = try StandardsComplianceChecker.checkCompliance(data: lz4Data, expectedFormat: .lz4)
        XCTAssertTrue(report.isCompliant)
        XCTAssertEqual(report.format, .lz4)
        XCTAssertTrue(report.validatedHeaders.contains { $0.contains("0x184D2204") })
    }

    func testLzipHeaderCompliance() throws {
        let lzipData = Data([0x4C, 0x5A, 0x49, 0x50, 0x01, 0x0C, 0x00, 0x00, 0x00, 0x00])
        let report = try StandardsComplianceChecker.checkCompliance(data: lzipData, expectedFormat: .lzip)
        XCTAssertTrue(report.isCompliant)
        XCTAssertEqual(report.format, .lzip)
        XCTAssertTrue(report.validatedHeaders.contains { $0.contains("LZIP Header Magic") })
    }

    func testSnappyHeaderCompliance() throws {
        let snappyData = Data([0xFF, 0x06, 0x00, 0x00, 0x73, 0x4E, 0x61, 0x50, 0x70, 0x59, 0x01, 0x00, 0x00, 0x00])
        let report = try StandardsComplianceChecker.checkCompliance(data: snappyData, expectedFormat: .snappy)
        XCTAssertTrue(report.isCompliant)
        XCTAssertEqual(report.format, .snappy)
        XCTAssertTrue(report.validatedHeaders.contains { $0.contains("Stream Identifier Chunk") })
    }

    func testWimHeaderCompliance() throws {
        var wimBytes = [UInt8](repeating: 0x00, count: 208)
        let sig = [UInt8]("MSWIM\0\0\0".utf8)
        for (i, b) in sig.enumerated() {
            wimBytes[i] = b
        }
        let wimData = Data(wimBytes)
        let report = try StandardsComplianceChecker.checkCompliance(data: wimData, expectedFormat: .wim)
        XCTAssertTrue(report.isCompliant)
        XCTAssertEqual(report.format, .wim)
        XCTAssertTrue(report.validatedHeaders.contains { $0.contains("MSWIM Header Magic") })
    }

    func testDmgHeaderCompliance() throws {
        var dmgBytes = [UInt8](repeating: 0x00, count: 1024)
        // Set 'koly' trailer at offset 512
        dmgBytes[512] = 0x6B
        dmgBytes[513] = 0x6F
        dmgBytes[514] = 0x6C
        dmgBytes[515] = 0x79
        let dmgData = Data(dmgBytes)
        let report = try StandardsComplianceChecker.checkCompliance(data: dmgData, expectedFormat: .dmg)
        XCTAssertTrue(report.isCompliant)
        XCTAssertEqual(report.format, .dmg)
        XCTAssertTrue(report.validatedHeaders.contains { $0.contains("koly Trailer Signature") })
    }

    func testIsoHeaderCompliance() throws {
        var isoBytes = [UInt8](repeating: 0x00, count: 32768 + 2048)
        // Sector 16: Primary Volume Descriptor (type 1, CD001, ver 1)
        isoBytes[32768] = 0x01
        isoBytes[32769] = 0x43 // 'C'
        isoBytes[32770] = 0x44 // 'D'
        isoBytes[32771] = 0x30 // '0'
        isoBytes[32772] = 0x30 // '0'
        isoBytes[32773] = 0x31 // '1'
        isoBytes[32774] = 0x01
        let isoData = Data(isoBytes)
        let report = try StandardsComplianceChecker.checkCompliance(data: isoData, expectedFormat: .iso)
        XCTAssertTrue(report.isCompliant)
        XCTAssertEqual(report.format, .iso)
        XCTAssertTrue(report.validatedHeaders.contains { $0.contains("Primary Volume Descriptor Magic") })
    }

    func testAppleArchiveHeaderCompliance() throws {
        let aarData = Data([0x41, 0x41, 0x30, 0x31, 0x00, 0x00, 0x00, 0x00])
        let report = try StandardsComplianceChecker.checkCompliance(data: aarData, expectedFormat: .aar)
        XCTAssertTrue(report.isCompliant)
        XCTAssertEqual(report.format, .aar)
        XCTAssertTrue(report.validatedHeaders.contains { $0.contains("AA01") })
    }

    func testLrzipHeaderCompliance() throws {
        let lrzData = Data([0x4C, 0x52, 0x5A, 0x49, 0x00, 0x06, 0x00, 0x00])
        let report = try StandardsComplianceChecker.checkCompliance(data: lrzData, expectedFormat: .lrzip)
        XCTAssertTrue(report.isCompliant)
        XCTAssertEqual(report.format, .lrzip)
        XCTAssertTrue(report.validatedHeaders.contains { $0.contains("LRZI Header Magic") })
    }

    func testBrotliCompliance() throws {
        let brData = Data([0x1B, 0x00, 0x00, 0x00, 0x00, 0x00])
        let report = try StandardsComplianceChecker.checkCompliance(data: brData, expectedFormat: .brotli)
        XCTAssertTrue(report.isCompliant)
        XCTAssertEqual(report.format, .brotli)
        XCTAssertTrue(report.validatedHeaders.contains { $0.contains("Brotli Compressed Data Stream") })
    }

    // MARK: - 8. Violation & Corruption Detection

    func testCorruptedZipHeaderDetection() throws {
        let corruptData = Data([0x00, 0x00, 0x00, 0x00, 0x14, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        let report = try StandardsComplianceChecker.checkCompliance(data: corruptData, expectedFormat: .zip)
        XCTAssertFalse(report.isCompliant)
        XCTAssertFalse(report.violations.isEmpty)
        XCTAssertTrue(report.violations.contains { $0.contains("Missing valid ZIP Local File Header") || $0.contains("Missing End of Central Directory") })
    }

    func testCorruptedTarChecksumDetection() throws {
        var tarBytes = [UInt8](repeating: 0x00, count: 512)
        // Set ustar magic at offset 257
        let magic = [UInt8]("ustar\0".utf8)
        for (i, b) in magic.enumerated() {
            tarBytes[257 + i] = b
        }
        // Write bogus checksum "000000\0"
        let badChk = [UInt8]("000000\0 ".utf8)
        for (i, b) in badChk.enumerated() {
            tarBytes[148 + i] = b
        }
        let report = try StandardsComplianceChecker.checkCompliance(data: Data(tarBytes), expectedFormat: .tar)
        XCTAssertFalse(report.isCompliant)
        XCTAssertTrue(report.violations.contains { $0.contains("checksum mismatch") })
    }

    func testCorruptedGzipMagicDetection() throws {
        let badGzData = Data([0x1F, 0x8C, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03])
        let report = try StandardsComplianceChecker.checkCompliance(data: badGzData, expectedFormat: .gz)
        XCTAssertFalse(report.isCompliant)
        XCTAssertTrue(report.violations.contains { $0.contains("Invalid GZIP magic header") })
    }

    func testCorruptedZstdMagicDetection() throws {
        let badZstData = Data([0x00, 0x00, 0x00, 0x00, 0x00])
        let report = try StandardsComplianceChecker.checkCompliance(data: badZstData, expectedFormat: .zst)
        XCTAssertFalse(report.isCompliant)
        XCTAssertTrue(report.violations.contains { $0.contains("Invalid Zstandard Frame Magic Number") })
    }

    func testCorruptedSevenZipCRCDetection() throws {
        var szBytes = [UInt8](repeating: 0x00, count: 32)
        let sig: [UInt8] = [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C]
        for (i, b) in sig.enumerated() {
            szBytes[i] = b
        }
        // Write bogus StartHeaderCRC
        szBytes[8] = 0xDE
        szBytes[9] = 0xAD
        szBytes[10] = 0xBE
        szBytes[11] = 0xEF
        let report = try StandardsComplianceChecker.checkCompliance(data: Data(szBytes), expectedFormat: .sevenZip)
        XCTAssertFalse(report.isCompliant)
        XCTAssertTrue(report.violations.contains { $0.contains("StartHeaderCRC checksum mismatch") })
    }

    // MARK: - 9. Report Codable Serialization

    func testStandardsComplianceReportCodable() throws {
        let citation = StandardCitation(
            organization: "PKWARE",
            standardNumber: "APPNOTE.TXT v6.3.10",
            title: ".ZIP File Format Specification",
            canonicalURL: "https://pkware.com/appnote"
        )
        let report = StandardsComplianceReport(
            format: .zip,
            isCompliant: true,
            standardCitation: citation,
            validatedHeaders: ["PKWARE APPNOTE: Local File Header (0x04034B50)"],
            warnings: ["Warning 1"],
            violations: []
        )

        let encoded = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(StandardsComplianceReport.self, from: encoded)

        XCTAssertEqual(report, decoded)
        XCTAssertEqual(decoded.format, .zip)
        XCTAssertTrue(decoded.isCompliant)
        XCTAssertEqual(decoded.standardCitation?.organization, "PKWARE")
        XCTAssertEqual(decoded.validatedHeaders.count, 1)
        XCTAssertEqual(decoded.warnings.count, 1)
        XCTAssertTrue(decoded.violations.isEmpty)
    }
}
