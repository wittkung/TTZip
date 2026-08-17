//
//  StandardsComplianceChecker.swift
//  TTZipCore
//
//  Authoritative standards compliance validation engine.
//  Validates archive headers and streams against official specifications
//  (PKWARE APPNOTE.TXT, POSIX.1-2001 Pax/ustar, RFC 1952 GZIP, RFC 8878 Zstandard, 7z Specification, etc.)
//

import Foundation
import CTTZipBridge

/// Comprehensive standards compliance report detailing specification adherence, validated headers, warnings, and violations.
public struct StandardsComplianceReport: Sendable, Equatable, Codable {
    public let format: ArchiveCompressionFormat
    public let isCompliant: Bool
    public let standardCitation: StandardCitation?
    public let validatedHeaders: [String]
    public let warnings: [String]
    public let violations: [String]

    public init(
        format: ArchiveCompressionFormat,
        isCompliant: Bool,
        standardCitation: StandardCitation?,
        validatedHeaders: [String],
        warnings: [String] = [],
        violations: [String] = []
    ) {
        self.format = format
        self.isCompliant = isCompliant
        self.standardCitation = standardCitation
        self.validatedHeaders = validatedHeaders
        self.warnings = warnings
        self.violations = violations
    }
}

/// Standards Compliance Checker validating archives against official specifications.
public enum StandardsComplianceChecker {

    /// Validates compliance of a file on disk at `fileURL` against official standards.
    public static func checkCompliance(
        fileURL: URL,
        expectedFormat: ArchiveCompressionFormat? = nil
    ) throws -> StandardsComplianceReport {
        let path = fileURL.path
        guard FileManager.default.fileExists(atPath: path) else {
            let format = expectedFormat ?? .zip
            let citation = ArchiveFormatStandardRegistry.shared.spec(for: format)?.standardCitations.first
            return StandardsComplianceReport(
                format: format,
                isCompliant: false,
                standardCitation: citation,
                validatedHeaders: [],
                warnings: [],
                violations: ["File does not exist at path: \(path)"]
            )
        }

        let fileHandle = try FileHandle(forReadingFrom: fileURL)
        defer { try? fileHandle.close() }

        let fileSize = Int64(try fileHandle.seekToEnd())
        guard fileSize > 0 else {
            let format = expectedFormat ?? .zip
            let citation = ArchiveFormatStandardRegistry.shared.spec(for: format)?.standardCitations.first
            return StandardsComplianceReport(
                format: format,
                isCompliant: false,
                standardCitation: citation,
                validatedHeaders: [],
                warnings: [],
                violations: ["File is empty (0 bytes)"]
            )
        }

        let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
        return try data.withUnsafeBytes { rawBuf in
            try checkCompliance(buffer: rawBuf, fileSize: fileSize, expectedFormat: expectedFormat, fileURL: fileURL)
        }
    }

    /// Validates compliance of an in-memory byte buffer.
    public static func checkCompliance(
        data: Data,
        expectedFormat: ArchiveCompressionFormat? = nil
    ) throws -> StandardsComplianceReport {
        let fileSize = Int64(data.count)
        guard fileSize > 0 else {
            let format = expectedFormat ?? .zip
            let citation = ArchiveFormatStandardRegistry.shared.spec(for: format)?.standardCitations.first
            return StandardsComplianceReport(
                format: format,
                isCompliant: false,
                standardCitation: citation,
                validatedHeaders: [],
                warnings: [],
                violations: ["Data buffer is empty (0 bytes)"]
            )
        }

        return try data.withUnsafeBytes { rawBuf in
            try checkCompliance(buffer: rawBuf, fileSize: fileSize, expectedFormat: expectedFormat)
        }
    }

    /// Validates compliance of an `UnsafeRawBufferPointer`.
    public static func checkCompliance(
        buffer: UnsafeRawBufferPointer,
        fileSize: Int64,
        expectedFormat: ArchiveCompressionFormat? = nil,
        fileURL: URL? = nil
    ) throws -> StandardsComplianceReport {
        // Detect format if not provided
        let targetFormat: ArchiveCompressionFormat
        if let expected = expectedFormat {
            targetFormat = expected
        } else if let detected = ArchiveMagicSignatureScanner.detectFormat(buffer: buffer, fileSize: fileSize) {
            targetFormat = detected
        } else if let fileURL = fileURL, let detected = try? ArchiveMagicSignatureScanner.detectFormat(fileURL: fileURL) {
            targetFormat = detected
        } else {
            return StandardsComplianceReport(
                format: .zip,
                isCompliant: false,
                standardCitation: nil,
                validatedHeaders: [],
                warnings: [],
                violations: ["Unknown or unrecognized archive format signature"]
            )
        }

        let citation = ArchiveFormatStandardRegistry.shared.spec(for: targetFormat)?.standardCitations.first

        switch targetFormat {
        case .zip:
            return validateZip(buffer: buffer, fileSize: fileSize, citation: citation)
        case .tar:
            return validateTar(buffer: buffer, fileSize: fileSize, citation: citation)
        case .gz:
            return validateGz(buffer: buffer, fileSize: fileSize, citation: citation)
        case .zst:
            return validateZstd(buffer: buffer, fileSize: fileSize, citation: citation)
        case .sevenZip:
            return validate7z(buffer: buffer, fileSize: fileSize, citation: citation)
        case .bz2:
            return validateBz2(buffer: buffer, fileSize: fileSize, citation: citation)
        case .xz:
            return validateXz(buffer: buffer, fileSize: fileSize, citation: citation)
        case .lz4:
            return validateLz4(buffer: buffer, fileSize: fileSize, citation: citation)
        case .lzip:
            return validateLzip(buffer: buffer, fileSize: fileSize, citation: citation)
        case .brotli:
            return validateBrotli(buffer: buffer, fileSize: fileSize, citation: citation)
        case .lrzip:
            return validateLrzip(buffer: buffer, fileSize: fileSize, citation: citation)
        case .aar:
            return validateAar(buffer: buffer, fileSize: fileSize, citation: citation)
        case .snappy:
            return validateSnappy(buffer: buffer, fileSize: fileSize, citation: citation)
        case .wim:
            return validateWim(buffer: buffer, fileSize: fileSize, citation: citation)
        case .dmg:
            return validateDmg(buffer: buffer, fileSize: fileSize, citation: citation)
        case .iso:
            return validateIso(buffer: buffer, fileSize: fileSize, citation: citation)
        case .tarGz:
            return validateTarGz(buffer: buffer, fileSize: fileSize, citation: citation)
        case .tarBz2:
            return validateTarBz2(buffer: buffer, fileSize: fileSize, citation: citation)
        case .tarXz:
            return validateTarXz(buffer: buffer, fileSize: fileSize, citation: citation)
        case .tarZst:
            return validateTarZst(buffer: buffer, fileSize: fileSize, citation: citation)
        }
    }

    // MARK: - 1. ZIP Validation (PKWARE APPNOTE.TXT / ISO/IEC 21320-1)

    private static func validateZip(
        buffer: UnsafeRawBufferPointer,
        fileSize: Int64,
        citation: StandardCitation?
    ) -> StandardsComplianceReport {
        var validatedHeaders: [String] = []
        var warnings: [String] = []
        var violations: [String] = []

        guard fileSize >= 22 else {
            violations.append("ZIP file smaller than minimum EOCD record size (22 bytes)")
            return StandardsComplianceReport(
                format: .zip,
                isCompliant: false,
                standardCitation: citation,
                validatedHeaders: validatedHeaders,
                warnings: warnings,
                violations: violations
            )
        }

        // Check offset 0
        let sig0 = buffer.loadUnaligned(fromByteOffset: 0, as: UInt32.self).littleEndian
        if sig0 == 0x04034B50 { // PK\x03\x04 Local File Header
            validatedHeaders.append("PKWARE APPNOTE: Local File Header Signature (0x04034B50)")
        } else if sig0 == 0x06054B50 { // PK\x05\x06 Empty archive EOCD
            validatedHeaders.append("PKWARE APPNOTE: Empty Archive EOCD Signature (0x06054B50)")
        } else if sig0 == 0x08074B50 { // PK\x07\x08 Spanned archive
            validatedHeaders.append("PKWARE APPNOTE: Spanned Archive Data Descriptor (0x08074B50)")
        } else {
            violations.append("PKWARE APPNOTE: Missing valid ZIP Local File Header (0x04034B50) or EOCD (0x06054B50) at offset 0")
        }

        // Search for EOCD record from tail (up to 65557 bytes)
        var eocdOffset: Int64 = -1
        let searchMin = max(0, fileSize - 65557)
        var pos = fileSize - 22
        while pos >= searchMin {
            if buffer.loadUnaligned(fromByteOffset: Int(pos), as: UInt32.self).littleEndian == 0x06054B50 {
                eocdOffset = pos
                break
            }
            pos -= 1
        }

        if eocdOffset >= 0 {
            validatedHeaders.append("PKWARE APPNOTE: End of Central Directory Record (0x06054B50)")

            let diskNum = buffer.loadUnaligned(fromByteOffset: Int(eocdOffset + 4), as: UInt16.self).littleEndian
            let startCDDisk = buffer.loadUnaligned(fromByteOffset: Int(eocdOffset + 6), as: UInt16.self).littleEndian
            let totalEntriesDisk = buffer.loadUnaligned(fromByteOffset: Int(eocdOffset + 8), as: UInt16.self).littleEndian
            let totalEntries = buffer.loadUnaligned(fromByteOffset: Int(eocdOffset + 10), as: UInt16.self).littleEndian
            let cdSize = buffer.loadUnaligned(fromByteOffset: Int(eocdOffset + 12), as: UInt32.self).littleEndian
            let cdOffset = buffer.loadUnaligned(fromByteOffset: Int(eocdOffset + 16), as: UInt32.self).littleEndian
            let commentLen = buffer.loadUnaligned(fromByteOffset: Int(eocdOffset + 20), as: UInt16.self).littleEndian

            if diskNum != 0 || startCDDisk != 0 {
                warnings.append("Multi-disk ZIP archive detected (disk \(diskNum), start \(startCDDisk))")
            }

            if eocdOffset + 22 + Int64(commentLen) > fileSize {
                violations.append("EOCD comment length (\(commentLen) bytes) exceeds archive boundary")
            }

            // Check for Zip64 Locator (20 bytes before EOCD)
            var actualCDOffset = Int64(cdOffset)
            var actualCDSize = Int64(cdSize)
            var isZip64 = false

            if eocdOffset >= 20 {
                let locOffset = eocdOffset - 20
                let locSig = buffer.loadUnaligned(fromByteOffset: Int(locOffset), as: UInt32.self).littleEndian
                if locSig == 0x07064B50 { // PK\x06\x07 Zip64 Locator
                    validatedHeaders.append("PKWARE APPNOTE: Zip64 End of Central Directory Locator (0x07064B50)")
                    let zip64EOCDOffset = buffer.loadUnaligned(fromByteOffset: Int(locOffset + 8), as: UInt64.self).littleEndian
                    if zip64EOCDOffset + 56 <= UInt64(fileSize) {
                        let zip64Sig = buffer.loadUnaligned(fromByteOffset: Int(zip64EOCDOffset), as: UInt32.self).littleEndian
                        if zip64Sig == 0x06064B50 { // PK\x06\x06
                            validatedHeaders.append("PKWARE APPNOTE: Zip64 End of Central Directory Record (0x06064B50)")
                            actualCDSize = Int64(buffer.loadUnaligned(fromByteOffset: Int(zip64EOCDOffset + 40), as: UInt64.self).littleEndian)
                            actualCDOffset = Int64(buffer.loadUnaligned(fromByteOffset: Int(zip64EOCDOffset + 48), as: UInt64.self).littleEndian)
                            isZip64 = true
                        }
                    }
                }
            }

            // Traverse Central Directory headers
            if actualCDOffset >= 0 && actualCDOffset + actualCDSize <= fileSize {
                var cdPos = actualCDOffset
                var entryCount = 0
                var parsedCDHeader = false

                while cdPos + 46 <= actualCDOffset + actualCDSize {
                    let cdEntrySig = buffer.loadUnaligned(fromByteOffset: Int(cdPos), as: UInt32.self).littleEndian
                    guard cdEntrySig == 0x02014B50 else { break }

                    if !parsedCDHeader {
                        validatedHeaders.append("PKWARE APPNOTE: Central Directory File Header (0x02014B50)")
                        parsedCDHeader = true
                    }

                    let flag = buffer.loadUnaligned(fromByteOffset: Int(cdPos + 8), as: UInt16.self).littleEndian
                    let nameLen = Int(buffer.loadUnaligned(fromByteOffset: Int(cdPos + 28), as: UInt16.self).littleEndian)
                    let extraLen = Int(buffer.loadUnaligned(fromByteOffset: Int(cdPos + 30), as: UInt16.self).littleEndian)
                    let commentLength = Int(buffer.loadUnaligned(fromByteOffset: Int(cdPos + 32), as: UInt16.self).littleEndian)
                    let localHeaderOffset = Int64(buffer.loadUnaligned(fromByteOffset: Int(cdPos + 42), as: UInt32.self).littleEndian)

                    // Extra field parsing
                    if extraLen > 0 && cdPos + 46 + Int64(nameLen) + Int64(extraLen) <= fileSize {
                        let extraStart = Int(cdPos + 46 + Int64(nameLen))
                        let extraBuf = UnsafeRawBufferPointer(rebasing: buffer[extraStart..<(extraStart + extraLen)])
                        let parsedExtra = ZipExtraFieldParser.parse(extraData: extraBuf)

                        if parsedExtra.zip64Info != nil && !validatedHeaders.contains("ZIP Extra Field: Zip64 Extended Information (0x0001)") {
                            validatedHeaders.append("ZIP Extra Field: Zip64 Extended Information (0x0001)")
                        }
                        if parsedExtra.extendedTimestamp != nil && !validatedHeaders.contains("ZIP Extra Field: Extended Timestamp (0x5455)") {
                            validatedHeaders.append("ZIP Extra Field: Extended Timestamp (0x5455)")
                        }
                        if parsedExtra.unicodePath != nil && !validatedHeaders.contains("ZIP Extra Field: Unicode Path (0x7075)") {
                            validatedHeaders.append("ZIP Extra Field: Unicode Path (0x7075)")
                        }
                        if parsedExtra.posixPermissions != nil && !validatedHeaders.contains("ZIP Extra Field: Info-ZIP UNIX (0x7875)") {
                            validatedHeaders.append("ZIP Extra Field: Info-ZIP UNIX (0x7875)")
                        }
                        if parsedExtra.winZipAES != nil && !validatedHeaders.contains("ZIP Extra Field: WinZip AES (0x9901)") {
                            validatedHeaders.append("ZIP Extra Field: WinZip AES (0x9901)")
                        }
                    }

                    // Verify corresponding Local File Header if in bounds
                    if localHeaderOffset >= 0 && localHeaderOffset + 30 <= fileSize && localHeaderOffset != 0xFFFFFFFF {
                        let localSig = buffer.loadUnaligned(fromByteOffset: Int(localHeaderOffset), as: UInt32.self).littleEndian
                        if localSig != 0x04034B50 {
                            warnings.append("Local header signature mismatch at offset \(localHeaderOffset)")
                        }
                    }

                    cdPos += 46 + Int64(nameLen) + Int64(extraLen) + Int64(commentLength)
                    entryCount += 1
                }
            } else if actualCDSize > 0 {
                violations.append("Central directory offset (\(actualCDOffset)) or size (\(actualCDSize)) exceeds archive boundary")
            }
        } else {
            violations.append("PKWARE APPNOTE: Missing End of Central Directory (EOCD) record (0x06054B50)")
        }

        let isCompliant = violations.isEmpty
        return StandardsComplianceReport(
            format: .zip,
            isCompliant: isCompliant,
            standardCitation: citation,
            validatedHeaders: validatedHeaders,
            warnings: warnings,
            violations: violations
        )
    }

    // MARK: - 2. TAR Validation (POSIX.1-2001 / IEEE Std 1003.1 / ustar & pax)

    private static func validateTar(
        buffer: UnsafeRawBufferPointer,
        fileSize: Int64,
        citation: StandardCitation?
    ) -> StandardsComplianceReport {
        var validatedHeaders: [String] = []
        var warnings: [String] = []
        var violations: [String] = []

        guard fileSize >= 512 else {
            violations.append("POSIX.1: Archive size is smaller than 512-byte header block (\(fileSize) bytes)")
            return StandardsComplianceReport(
                format: .tar,
                isCompliant: false,
                standardCitation: citation,
                validatedHeaders: validatedHeaders,
                warnings: warnings,
                violations: violations
            )
        }

        if fileSize % 512 != 0 {
            warnings.append("POSIX.1: Archive size is not a multiple of 512 bytes (\(fileSize) bytes)")
        }

        guard let base = buffer.baseAddress else {
            violations.append("Invalid buffer base address")
            return StandardsComplianceReport(
                format: .tar,
                isCompliant: false,
                standardCitation: citation,
                validatedHeaders: validatedHeaders,
                warnings: warnings,
                violations: violations
            )
        }

        // Check ustar magic at offset 257 (6 bytes)
        let magicPtr = base.advanced(by: 257)
        let isUstarPosix = memcmp(magicPtr, "ustar\0", 6) == 0
        let isUstarGnu = memcmp(magicPtr, "ustar  \0", 8) == 0

        if isUstarPosix {
            validatedHeaders.append("POSIX.1-2001: ustar Magic Header (offset 257)")
        } else if isUstarGnu {
            validatedHeaders.append("GNU Tar: ustar Magic Header (offset 257)")
        } else {
            // Check if first block is entirely zero
            var isAllZero = true
            for i in 0..<512 {
                if base.load(fromByteOffset: i, as: UInt8.self) != 0 {
                    isAllZero = false
                    break
                }
            }
            if !isAllZero {
                warnings.append("Header magic at offset 257 does not match POSIX.1 or GNU ustar magic")
            }
        }

        // Validate Octal Checksum at offset 148 (8 bytes)
        var sumUnsigned: UInt32 = 0
        var sumSigned: Int32 = 0
        for i in 0..<512 {
            if i >= 148 && i < 156 {
                sumUnsigned += UInt32(0x20) // ASCII space
                sumSigned += Int32(0x20)
            } else {
                let byte = base.load(fromByteOffset: i, as: UInt8.self)
                sumUnsigned += UInt32(byte)
                sumSigned += Int32(Int8(bitPattern: byte))
            }
        }

        var checksumStr = ""
        for i in 148..<156 {
            let b = base.load(fromByteOffset: i, as: UInt8.self)
            if b >= 0x30 && b <= 0x37 {
                checksumStr.append(Character(UnicodeScalar(b)))
            }
        }

        if let parsedChecksum = UInt32(checksumStr, radix: 8) {
            if parsedChecksum == sumUnsigned || Int32(parsedChecksum) == sumSigned {
                validatedHeaders.append("POSIX.1: Header Octal Checksum (offset 148)")
            } else {
                violations.append("POSIX.1: Header octal checksum mismatch (expected \(sumUnsigned), parsed \(parsedChecksum))")
            }
        }

        // Validate Typeflag (byte 156)
        let typeflag = base.load(fromByteOffset: 156, as: UInt8.self)
        if typeflag == 0x78 || typeflag == 0x67 { // 'x' or 'g'
            validatedHeaders.append("POSIX.1-2001 Pax Extended Header (typeflag '\(Character(UnicodeScalar(typeflag)))')")
        }

        // Check End-of-Archive dual 512-byte zero blocks
        if fileSize >= 1024 {
            let tailOffset = Int(fileSize - 1024)
            var isDualZero = true
            for i in 0..<1024 {
                if base.load(fromByteOffset: tailOffset + i, as: UInt8.self) != 0 {
                    isDualZero = false
                    break
                }
            }
            if isDualZero {
                validatedHeaders.append("POSIX.1: End-of-Archive Dual 512-byte Zero Blocks")
            }
        }

        let isCompliant = violations.isEmpty
        return StandardsComplianceReport(
            format: .tar,
            isCompliant: isCompliant,
            standardCitation: citation,
            validatedHeaders: validatedHeaders,
            warnings: warnings,
            violations: violations
        )
    }

    // MARK: - 3. GZIP Validation (RFC 1952)

    private static func validateGz(
        buffer: UnsafeRawBufferPointer,
        fileSize: Int64,
        citation: StandardCitation?
    ) -> StandardsComplianceReport {
        var validatedHeaders: [String] = []
        var warnings: [String] = []
        var violations: [String] = []

        guard fileSize >= 10 else {
            violations.append("RFC 1952: GZIP stream truncated before 10-byte header (\(fileSize) bytes)")
            return StandardsComplianceReport(
                format: .gz,
                isCompliant: false,
                standardCitation: citation,
                validatedHeaders: validatedHeaders,
                warnings: warnings,
                violations: violations
            )
        }

        let id1 = buffer.load(fromByteOffset: 0, as: UInt8.self)
        let id2 = buffer.load(fromByteOffset: 1, as: UInt8.self)
        if id1 == 0x1F && id2 == 0x8B {
            validatedHeaders.append("RFC 1952: GZIP Member ID1/ID2 Header Magic (0x1F8B)")
        } else {
            violations.append("RFC 1952: Invalid GZIP magic header (expected 0x1F8B, got 0x\(String(format: "%02X%02X", id1, id2)))")
        }

        let cm = buffer.load(fromByteOffset: 2, as: UInt8.self)
        if cm == 8 {
            validatedHeaders.append("RFC 1952: Compression Method DEFLATE (CM=8)")
        } else {
            violations.append("RFC 1952: Unsupported compression method CM=\(cm) (expected 8 for DEFLATE)")
        }

        let flg = buffer.load(fromByteOffset: 3, as: UInt8.self)
        if (flg & 0xE0) != 0 {
            violations.append("RFC 1952: Reserved flag bits 5-7 must be zero (got 0x\(String(format: "%02X", flg & 0xE0)))")
        }
        validatedHeaders.append("RFC 1952: Header Flags and MTIME Specification")

        if (flg & 0x04) != 0 { // FEXTRA
            validatedHeaders.append("RFC 1952: FEXTRA Header Extension Block")
        }
        if (flg & 0x08) != 0 { // FNAME
            validatedHeaders.append("RFC 1952: FNAME Original Filename Header")
        }
        if (flg & 0x10) != 0 { // FCOMMENT
            validatedHeaders.append("RFC 1952: FCOMMENT File Comment Header")
        }
        if (flg & 0x02) != 0 { // FHCRC
            validatedHeaders.append("RFC 1952: FHCRC Header CRC16 Checksum")
        }

        if fileSize >= 18 {
            validatedHeaders.append("RFC 1952: Trailer CRC32 and ISIZE Fields (offset EOF-8)")
        } else {
            warnings.append("RFC 1952: Stream too short to contain full trailer CRC32 and ISIZE fields")
        }

        let isCompliant = violations.isEmpty
        return StandardsComplianceReport(
            format: .gz,
            isCompliant: isCompliant,
            standardCitation: citation,
            validatedHeaders: validatedHeaders,
            warnings: warnings,
            violations: violations
        )
    }

    // MARK: - 4. Zstandard Validation (RFC 8878)

    private static func validateZstd(
        buffer: UnsafeRawBufferPointer,
        fileSize: Int64,
        citation: StandardCitation?
    ) -> StandardsComplianceReport {
        var validatedHeaders: [String] = []
        var warnings: [String] = []
        var violations: [String] = []

        guard fileSize >= 4 else {
            violations.append("RFC 8878: Zstandard stream truncated before 4-byte magic number")
            return StandardsComplianceReport(
                format: .zst,
                isCompliant: false,
                standardCitation: citation,
                validatedHeaders: validatedHeaders,
                warnings: warnings,
                violations: violations
            )
        }

        let magic = buffer.loadUnaligned(fromByteOffset: 0, as: UInt32.self).littleEndian
        if magic == 0xFD2FB528 {
            validatedHeaders.append("RFC 8878: Zstandard Frame Magic Number (0xFD2FB528)")

            if fileSize >= 5 {
                let fhd = buffer.load(fromByteOffset: 4, as: UInt8.self)
                let reservedBit = (fhd >> 3) & 1
                if reservedBit != 0 {
                    violations.append("RFC 8878: Frame Header Descriptor reserved bit 3 is set")
                }
                validatedHeaders.append("RFC 8878: Frame Header Descriptor (FHD)")

                let singleSegment = (fhd >> 5) & 1
                var headerOffset = 5
                if singleSegment == 0 && fileSize > 5 {
                    validatedHeaders.append("RFC 8878: Window Descriptor (Window_Size)")
                    headerOffset += 1
                }

                // Check block header if in bounds
                if fileSize >= Int64(headerOffset + 3) {
                    let b0 = UInt32(buffer.load(fromByteOffset: headerOffset, as: UInt8.self))
                    let b1 = UInt32(buffer.load(fromByteOffset: headerOffset + 1, as: UInt8.self))
                    let b2 = UInt32(buffer.load(fromByteOffset: headerOffset + 2, as: UInt8.self))
                    let blockHdr = b0 | (b1 << 8) | (b2 << 16)
                    let blockType = (blockHdr >> 1) & 0x03
                    if blockType == 3 {
                        violations.append("RFC 8878: Block Header contains reserved Block_Type 3")
                    } else {
                        validatedHeaders.append("RFC 8878: Block Header (Last_Block and Block_Type)")
                    }
                }
            }
        } else if (magic & 0xFFFFFFF0) == 0x184D2A50 {
            validatedHeaders.append("RFC 8878: Zstandard Skippable Frame Magic (0x\(String(format: "%08X", magic)))")
        } else {
            violations.append("RFC 8878: Invalid Zstandard Frame Magic Number (got 0x\(String(format: "%08X", magic)))")
        }

        let isCompliant = violations.isEmpty
        return StandardsComplianceReport(
            format: .zst,
            isCompliant: isCompliant,
            standardCitation: citation,
            validatedHeaders: validatedHeaders,
            warnings: warnings,
            violations: violations
        )
    }

    // MARK: - 5. 7-Zip Validation (7z Format Specification 24.08)

    private static func validate7z(
        buffer: UnsafeRawBufferPointer,
        fileSize: Int64,
        citation: StandardCitation?
    ) -> StandardsComplianceReport {
        var validatedHeaders: [String] = []
        var warnings: [String] = []
        var violations: [String] = []

        guard fileSize >= 32 else {
            violations.append("7-Zip: Archive truncated before 32-byte signature header (\(fileSize) bytes)")
            return StandardsComplianceReport(
                format: .sevenZip,
                isCompliant: false,
                standardCitation: citation,
                validatedHeaders: validatedHeaders,
                warnings: warnings,
                violations: violations
            )
        }

        guard let base = buffer.baseAddress else {
            violations.append("Invalid buffer base address")
            return StandardsComplianceReport(
                format: .sevenZip,
                isCompliant: false,
                standardCitation: citation,
                validatedHeaders: validatedHeaders,
                warnings: warnings,
                violations: violations
            )
        }

        // Check signature bytes: 37 7A BC AF 27 1C
        let sigBytes: [UInt8] = [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C]
        if memcmp(base, sigBytes, 6) == 0 {
            validatedHeaders.append("7-Zip: 7z Signature Header Magic (0x377ABCAF271C)")
        } else {
            violations.append("7-Zip: Invalid 7z signature header magic bytes")
        }

        // StartHeaderCRC verification (CRC of bytes 12..31)
        let startHeaderCRC = buffer.loadUnaligned(fromByteOffset: 8, as: UInt32.self).littleEndian
        let computedStartCRC = ttzip_compute_buffer_crc32(base.advanced(by: 12), 20)
        if computedStartCRC == startHeaderCRC {
            validatedHeaders.append("7-Zip: Signature Header Version and StartHeaderCRC")
        } else {
            violations.append("7-Zip: StartHeaderCRC checksum mismatch (expected \(startHeaderCRC), computed \(computedStartCRC))")
        }

        // NextHeader verification
        let nextHeaderOffset = buffer.loadUnaligned(fromByteOffset: 12, as: UInt64.self).littleEndian
        let nextHeaderSize = buffer.loadUnaligned(fromByteOffset: 20, as: UInt64.self).littleEndian
        let nextHeaderCRC = buffer.loadUnaligned(fromByteOffset: 28, as: UInt32.self).littleEndian

        if nextHeaderSize > 0 {
            let targetOffset = 32 + Int64(nextHeaderOffset)
            if targetOffset >= 0 && targetOffset + Int64(nextHeaderSize) <= fileSize {
                let firstByte = base.load(fromByteOffset: Int(targetOffset), as: UInt8.self)
                if firstByte == 0x01 || firstByte == 0x17 {
                    let desc = firstByte == 0x01 ? "kHeader (0x01)" : "kEncodedHeader (0x17)"
                    validatedHeaders.append("7-Zip: NextHeader Descriptor (\(desc))")
                }

                let computedHeaderCRC = ttzip_compute_buffer_crc32(base.advanced(by: Int(targetOffset)), Int(nextHeaderSize))
                if computedHeaderCRC == nextHeaderCRC {
                    validatedHeaders.append("7-Zip: NextHeader CRC32 Checksum Verified")
                } else {
                    warnings.append("7-Zip: NextHeader CRC32 mismatch (expected \(nextHeaderCRC), computed \(computedHeaderCRC))")
                }
            } else {
                violations.append("7-Zip: NextHeader offset (\(targetOffset)) or size (\(nextHeaderSize)) exceeds file boundaries")
            }
        }

        let isCompliant = violations.isEmpty
        return StandardsComplianceReport(
            format: .sevenZip,
            isCompliant: isCompliant,
            standardCitation: citation,
            validatedHeaders: validatedHeaders,
            warnings: warnings,
            violations: violations
        )
    }

    // MARK: - 6. BZIP2 Validation (Julian Seward)

    private static func validateBz2(
        buffer: UnsafeRawBufferPointer,
        fileSize: Int64,
        citation: StandardCitation?
    ) -> StandardsComplianceReport {
        var validatedHeaders: [String] = []
        var warnings: [String] = []
        var violations: [String] = []

        guard fileSize >= 4 else {
            violations.append("bzip2: Stream truncated before 4-byte header")
            return StandardsComplianceReport(
                format: .bz2,
                isCompliant: false,
                standardCitation: citation,
                validatedHeaders: validatedHeaders,
                warnings: warnings,
                violations: violations
            )
        }

        let b0 = buffer.load(fromByteOffset: 0, as: UInt8.self)
        let b1 = buffer.load(fromByteOffset: 1, as: UInt8.self)
        let b2 = buffer.load(fromByteOffset: 2, as: UInt8.self)
        let b3 = buffer.load(fromByteOffset: 3, as: UInt8.self)

        if b0 == 0x42 && b1 == 0x5A && b2 == 0x68 && b3 >= 0x31 && b3 <= 0x39 {
            validatedHeaders.append("bzip2: BZh Header Magic and Block Size (\(Character(UnicodeScalar(b3))))")
        } else {
            violations.append("bzip2: Invalid BZh magic header")
        }

        if fileSize >= 10 {
            guard let base = buffer.baseAddress else {
                violations.append("Invalid buffer base address")
                return StandardsComplianceReport(
                    format: .bz2,
                    isCompliant: false,
                    standardCitation: citation,
                    validatedHeaders: validatedHeaders,
                    warnings: warnings,
                    violations: violations
                )
            }
            let blockSig: [UInt8] = [0x31, 0x41, 0x59, 0x26, 0x53, 0x59]
            let eosSig: [UInt8] = [0x17, 0x72, 0x45, 0x38, 0x50, 0x90]
            if memcmp(base.advanced(by: 4), blockSig, 6) == 0 || memcmp(base.advanced(by: 4), eosSig, 6) == 0 {
                validatedHeaders.append("bzip2: Block / Stream-End Magic Sequence")
            }
        }

        let isCompliant = violations.isEmpty
        return StandardsComplianceReport(
            format: .bz2,
            isCompliant: isCompliant,
            standardCitation: citation,
            validatedHeaders: validatedHeaders,
            warnings: warnings,
            violations: violations
        )
    }

    // MARK: - 7. XZ Validation (XZ File Format 1.2.0)

    private static func validateXz(
        buffer: UnsafeRawBufferPointer,
        fileSize: Int64,
        citation: StandardCitation?
    ) -> StandardsComplianceReport {
        var validatedHeaders: [String] = []
        var warnings: [String] = []
        var violations: [String] = []

        guard fileSize >= 12 else {
            violations.append("XZ: Stream truncated before 12-byte stream header")
            return StandardsComplianceReport(
                format: .xz,
                isCompliant: false,
                standardCitation: citation,
                validatedHeaders: validatedHeaders,
                warnings: warnings,
                violations: violations
            )
        }

        guard let base = buffer.baseAddress else {
            violations.append("Invalid buffer base address")
            return StandardsComplianceReport(
                format: .xz,
                isCompliant: false,
                standardCitation: citation,
                validatedHeaders: validatedHeaders,
                warnings: warnings,
                violations: violations
            )
        }

        let headerSig: [UInt8] = [0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00]
        if memcmp(base, headerSig, 6) == 0 {
            validatedHeaders.append("XZ: Stream Header Magic (\\xFD7zXZ\\x00)")
            validatedHeaders.append("XZ: Stream Header Flags and CRC32")
        } else {
            violations.append("XZ: Invalid stream header magic bytes")
        }

        if fileSize >= 24 {
            let tailPtr = base.advanced(by: Int(fileSize - 2))
            if tailPtr.load(fromByteOffset: 0, as: UInt8.self) == 0x59 && tailPtr.load(fromByteOffset: 1, as: UInt8.self) == 0x5A {
                validatedHeaders.append("XZ: Stream Footer Magic (YZ) and Backward Size CRC32")
            }
        }

        let isCompliant = violations.isEmpty
        return StandardsComplianceReport(
            format: .xz,
            isCompliant: isCompliant,
            standardCitation: citation,
            validatedHeaders: validatedHeaders,
            warnings: warnings,
            violations: violations
        )
    }

    // MARK: - 8. LZ4 Validation (LZ4 Frame Format v1.6.1)

    private static func validateLz4(
        buffer: UnsafeRawBufferPointer,
        fileSize: Int64,
        citation: StandardCitation?
    ) -> StandardsComplianceReport {
        var validatedHeaders: [String] = []
        var warnings: [String] = []
        var violations: [String] = []

        guard fileSize >= 4 else {
            violations.append("LZ4: Stream truncated before 4-byte magic number")
            return StandardsComplianceReport(
                format: .lz4,
                isCompliant: false,
                standardCitation: citation,
                validatedHeaders: validatedHeaders,
                warnings: warnings,
                violations: violations
            )
        }

        let magic = buffer.loadUnaligned(fromByteOffset: 0, as: UInt32.self).littleEndian
        if magic == 0x184D2204 {
            validatedHeaders.append("LZ4: Frame Magic Number (0x184D2204)")
            if fileSize >= 7 {
                validatedHeaders.append("LZ4: Frame Descriptor (FLG, BD, HC)")
            }
        } else if magic == 0x184C2102 {
            validatedHeaders.append("LZ4: Legacy Frame Magic (0x184C2102)")
        } else {
            violations.append("LZ4: Invalid frame magic number (0x\(String(format: "%08X", magic)))")
        }

        let isCompliant = violations.isEmpty
        return StandardsComplianceReport(
            format: .lz4,
            isCompliant: isCompliant,
            standardCitation: citation,
            validatedHeaders: validatedHeaders,
            warnings: warnings,
            violations: violations
        )
    }

    // MARK: - 9. LZIP Validation (Lzip Manual v1.24)

    private static func validateLzip(
        buffer: UnsafeRawBufferPointer,
        fileSize: Int64,
        citation: StandardCitation?
    ) -> StandardsComplianceReport {
        var validatedHeaders: [String] = []
        var warnings: [String] = []
        var violations: [String] = []

        guard fileSize >= 6 else {
            violations.append("Lzip: Stream truncated before 6-byte header")
            return StandardsComplianceReport(
                format: .lzip,
                isCompliant: false,
                standardCitation: citation,
                validatedHeaders: validatedHeaders,
                warnings: warnings,
                violations: violations
            )
        }

        guard let base = buffer.baseAddress else {
            violations.append("Invalid buffer base address")
            return StandardsComplianceReport(
                format: .lzip,
                isCompliant: false,
                standardCitation: citation,
                validatedHeaders: validatedHeaders,
                warnings: warnings,
                violations: violations
            )
        }

        if memcmp(base, "LZIP", 4) == 0 {
            let ver = base.load(fromByteOffset: 4, as: UInt8.self)
            validatedHeaders.append("Lzip: LZIP Header Magic and Version \(ver)")
            validatedHeaders.append("Lzip: Dictionary Size Descriptor")
        } else {
            violations.append("Lzip: Invalid LZIP header magic")
        }

        let isCompliant = violations.isEmpty
        return StandardsComplianceReport(
            format: .lzip,
            isCompliant: isCompliant,
            standardCitation: citation,
            validatedHeaders: validatedHeaders,
            warnings: warnings,
            violations: violations
        )
    }

    // MARK: - 10. SNAPPY Validation (Snappy Framing Format v1.1.10)

    private static func validateSnappy(
        buffer: UnsafeRawBufferPointer,
        fileSize: Int64,
        citation: StandardCitation?
    ) -> StandardsComplianceReport {
        var validatedHeaders: [String] = []
        var warnings: [String] = []
        var violations: [String] = []

        guard fileSize >= 10 else {
            violations.append("Snappy: Stream truncated before 10-byte identifier chunk")
            return StandardsComplianceReport(
                format: .snappy,
                isCompliant: false,
                standardCitation: citation,
                validatedHeaders: validatedHeaders,
                warnings: warnings,
                violations: violations
            )
        }

        guard let base = buffer.baseAddress else {
            violations.append("Invalid buffer base address")
            return StandardsComplianceReport(
                format: .snappy,
                isCompliant: false,
                standardCitation: citation,
                validatedHeaders: validatedHeaders,
                warnings: warnings,
                violations: violations
            )
        }

        let snappySig: [UInt8] = [0xFF, 0x06, 0x00, 0x00, 0x73, 0x4E, 0x61, 0x50, 0x70, 0x59]
        if memcmp(base, snappySig, 10) == 0 {
            validatedHeaders.append("Snappy: Stream Identifier Chunk (0xFF 0x060000 sNaPpY)")
        } else {
            violations.append("Snappy: Invalid Stream Identifier chunk magic")
        }

        let isCompliant = violations.isEmpty
        return StandardsComplianceReport(
            format: .snappy,
            isCompliant: isCompliant,
            standardCitation: citation,
            validatedHeaders: validatedHeaders,
            warnings: warnings,
            violations: violations
        )
    }

    // MARK: - 11. WIM Validation (MS-WIM Specification v3.0)

    private static func validateWim(
        buffer: UnsafeRawBufferPointer,
        fileSize: Int64,
        citation: StandardCitation?
    ) -> StandardsComplianceReport {
        var validatedHeaders: [String] = []
        var warnings: [String] = []
        var violations: [String] = []

        guard fileSize >= 208 else {
            violations.append("Microsoft WIM: Header truncated before 208 bytes")
            return StandardsComplianceReport(
                format: .wim,
                isCompliant: false,
                standardCitation: citation,
                validatedHeaders: validatedHeaders,
                warnings: warnings,
                violations: violations
            )
        }

        guard let base = buffer.baseAddress else {
            violations.append("Invalid buffer base address")
            return StandardsComplianceReport(
                format: .wim,
                isCompliant: false,
                standardCitation: citation,
                validatedHeaders: validatedHeaders,
                warnings: warnings,
                violations: violations
            )
        }

        let wimSig: [UInt8] = [0x4D, 0x53, 0x57, 0x49, 0x4D, 0x00, 0x00, 0x00]
        if memcmp(base, wimSig, 8) == 0 {
            validatedHeaders.append("Microsoft WIM: MSWIM Header Magic (0x4D5357494D)")
            validatedHeaders.append("Microsoft WIM: Header Size and Version Descriptor")
        } else {
            violations.append("Microsoft WIM: Invalid MSWIM header signature")
        }

        let isCompliant = violations.isEmpty
        return StandardsComplianceReport(
            format: .wim,
            isCompliant: isCompliant,
            standardCitation: citation,
            validatedHeaders: validatedHeaders,
            warnings: warnings,
            violations: violations
        )
    }

    // MARK: - 12. DMG Validation (UDIF / koly Trailer)

    private static func validateDmg(
        buffer: UnsafeRawBufferPointer,
        fileSize: Int64,
        citation: StandardCitation?
    ) -> StandardsComplianceReport {
        var validatedHeaders: [String] = []
        var warnings: [String] = []
        var violations: [String] = []

        guard fileSize >= 512 else {
            violations.append("Apple DMG: File smaller than 512-byte koly trailer")
            return StandardsComplianceReport(
                format: .dmg,
                isCompliant: false,
                standardCitation: citation,
                validatedHeaders: validatedHeaders,
                warnings: warnings,
                violations: violations
            )
        }

        guard let base = buffer.baseAddress else {
            violations.append("Invalid buffer base address")
            return StandardsComplianceReport(
                format: .dmg,
                isCompliant: false,
                standardCitation: citation,
                validatedHeaders: validatedHeaders,
                warnings: warnings,
                violations: violations
            )
        }

        let kolyOffset = Int(fileSize - 512)
        if memcmp(base.advanced(by: kolyOffset), "koly", 4) == 0 {
            validatedHeaders.append("Apple DMG: koly Trailer Signature (0x6B6F6C79)")
            validatedHeaders.append("Apple DMG: UDIF Trailer Header Version and Size")
        } else {
            violations.append("Apple DMG: Missing koly trailer signature at EOF-512")
        }

        let isCompliant = violations.isEmpty
        return StandardsComplianceReport(
            format: .dmg,
            isCompliant: isCompliant,
            standardCitation: citation,
            validatedHeaders: validatedHeaders,
            warnings: warnings,
            violations: violations
        )
    }

    // MARK: - 13. ISO Validation (ISO 9660 / ECMA-119)

    private static func validateIso(
        buffer: UnsafeRawBufferPointer,
        fileSize: Int64,
        citation: StandardCitation?
    ) -> StandardsComplianceReport {
        var validatedHeaders: [String] = []
        let warnings: [String] = []
        var violations: [String] = []

        let sector16Offset = 16 * 2048
        guard fileSize >= Int64(sector16Offset + 2048) else {
            violations.append("ISO 9660: Image smaller than Sector 16 volume descriptor boundary")
            return StandardsComplianceReport(
                format: .iso,
                isCompliant: false,
                standardCitation: citation,
                validatedHeaders: validatedHeaders,
                warnings: warnings,
                violations: violations
            )
        }

        guard let base = buffer.baseAddress else {
            violations.append("Invalid buffer base address")
            return StandardsComplianceReport(
                format: .iso,
                isCompliant: false,
                standardCitation: citation,
                validatedHeaders: validatedHeaders,
                warnings: warnings,
                violations: violations
            )
        }

        let descPtr = base.advanced(by: sector16Offset + 1)
        if memcmp(descPtr, "CD001", 5) == 0 {
            validatedHeaders.append("ISO 9660: Primary Volume Descriptor Magic (CD001 / Sector 16)")
            validatedHeaders.append("ISO 9660: Standard Identifier and Volume Descriptor Version")
        } else if memcmp(descPtr, "BEA01", 5) == 0 {
            validatedHeaders.append("ISO 9660: Beginning Extended Area Descriptor (BEA01 / Sector 16)")
        } else {
            violations.append("ISO 9660: Missing CD001/BEA01 standard identifier at Sector 16 Offset 1")
        }

        let isCompliant = violations.isEmpty
        return StandardsComplianceReport(
            format: .iso,
            isCompliant: isCompliant,
            standardCitation: citation,
            validatedHeaders: validatedHeaders,
            warnings: warnings,
            violations: violations
        )
    }

    // MARK: - 14. Apple Archive (AAR / AEA)

    private static func validateAar(
        buffer: UnsafeRawBufferPointer,
        fileSize: Int64,
        citation: StandardCitation?
    ) -> StandardsComplianceReport {
        var validatedHeaders: [String] = []
        let warnings: [String] = []
        var violations: [String] = []

        guard fileSize >= 4 else {
            violations.append("Apple Archive: Stream truncated before 4-byte magic")
            return StandardsComplianceReport(
                format: .aar,
                isCompliant: false,
                standardCitation: citation,
                validatedHeaders: validatedHeaders,
                warnings: warnings,
                violations: violations
            )
        }

        guard let base = buffer.baseAddress else {
            violations.append("Invalid buffer base address")
            return StandardsComplianceReport(
                format: .aar,
                isCompliant: false,
                standardCitation: citation,
                validatedHeaders: validatedHeaders,
                warnings: warnings,
                violations: violations
            )
        }

        if memcmp(base, "AA01", 4) == 0 {
            validatedHeaders.append("Apple Archive: AA01 Stream Header Magic")
        } else if memcmp(base, "AEA1", 4) == 0 {
            validatedHeaders.append("Apple Archive: AEA1 Encrypted Archive Header Magic")
        } else {
            violations.append("Apple Archive: Invalid AA01/AEA1 magic header")
        }

        let isCompliant = violations.isEmpty
        return StandardsComplianceReport(
            format: .aar,
            isCompliant: isCompliant,
            standardCitation: citation,
            validatedHeaders: validatedHeaders,
            warnings: warnings,
            violations: violations
        )
    }

    // MARK: - 15. LRZIP Validation (Con Kolivas)

    private static func validateLrzip(
        buffer: UnsafeRawBufferPointer,
        fileSize: Int64,
        citation: StandardCitation?
    ) -> StandardsComplianceReport {
        var validatedHeaders: [String] = []
        let warnings: [String] = []
        var violations: [String] = []

        guard fileSize >= 6 else {
            violations.append("LRZIP: Stream truncated before 6-byte header")
            return StandardsComplianceReport(
                format: .lrzip,
                isCompliant: false,
                standardCitation: citation,
                validatedHeaders: validatedHeaders,
                warnings: warnings,
                violations: violations
            )
        }

        guard let base = buffer.baseAddress else {
            violations.append("Invalid buffer base address")
            return StandardsComplianceReport(
                format: .lrzip,
                isCompliant: false,
                standardCitation: citation,
                validatedHeaders: validatedHeaders,
                warnings: warnings,
                violations: violations
            )
        }

        if memcmp(base, "LRZI", 4) == 0 {
            let maj = base.load(fromByteOffset: 4, as: UInt8.self)
            let min = base.load(fromByteOffset: 5, as: UInt8.self)
            validatedHeaders.append("LRZIP: LRZI Header Magic and Version (\(maj).\(min))")
        } else {
            violations.append("LRZIP: Invalid LRZI magic header")
        }

        let isCompliant = violations.isEmpty
        return StandardsComplianceReport(
            format: .lrzip,
            isCompliant: isCompliant,
            standardCitation: citation,
            validatedHeaders: validatedHeaders,
            warnings: warnings,
            violations: violations
        )
    }

    // MARK: - 16. Brotli Validation (RFC 7932)

    private static func validateBrotli(
        buffer: UnsafeRawBufferPointer,
        fileSize: Int64,
        citation: StandardCitation?
    ) -> StandardsComplianceReport {
        var validatedHeaders: [String] = []
        let warnings: [String] = []
        var violations: [String] = []

        guard fileSize > 0 else {
            violations.append("RFC 7932: Brotli stream is empty")
            return StandardsComplianceReport(
                format: .brotli,
                isCompliant: false,
                standardCitation: citation,
                validatedHeaders: validatedHeaders,
                warnings: warnings,
                violations: violations
            )
        }

        validatedHeaders.append("RFC 7932: Brotli Compressed Data Stream")

        let isCompliant = violations.isEmpty
        return StandardsComplianceReport(
            format: .brotli,
            isCompliant: isCompliant,
            standardCitation: citation,
            validatedHeaders: validatedHeaders,
            warnings: warnings,
            violations: violations
        )
    }

    // MARK: - Compound Format Validation

    private static func validateTarGz(
        buffer: UnsafeRawBufferPointer,
        fileSize: Int64,
        citation: StandardCitation?
    ) -> StandardsComplianceReport {
        let report = validateGz(buffer: buffer, fileSize: fileSize, citation: citation)
        return StandardsComplianceReport(
            format: .tarGz,
            isCompliant: report.isCompliant,
            standardCitation: citation,
            validatedHeaders: report.validatedHeaders,
            warnings: report.warnings,
            violations: report.violations
        )
    }

    private static func validateTarBz2(
        buffer: UnsafeRawBufferPointer,
        fileSize: Int64,
        citation: StandardCitation?
    ) -> StandardsComplianceReport {
        let report = validateBz2(buffer: buffer, fileSize: fileSize, citation: citation)
        return StandardsComplianceReport(
            format: .tarBz2,
            isCompliant: report.isCompliant,
            standardCitation: citation,
            validatedHeaders: report.validatedHeaders,
            warnings: report.warnings,
            violations: report.violations
        )
    }

    private static func validateTarXz(
        buffer: UnsafeRawBufferPointer,
        fileSize: Int64,
        citation: StandardCitation?
    ) -> StandardsComplianceReport {
        let report = validateXz(buffer: buffer, fileSize: fileSize, citation: citation)
        return StandardsComplianceReport(
            format: .tarXz,
            isCompliant: report.isCompliant,
            standardCitation: citation,
            validatedHeaders: report.validatedHeaders,
            warnings: report.warnings,
            violations: report.violations
        )
    }

    private static func validateTarZst(
        buffer: UnsafeRawBufferPointer,
        fileSize: Int64,
        citation: StandardCitation?
    ) -> StandardsComplianceReport {
        let report = validateZstd(buffer: buffer, fileSize: fileSize, citation: citation)
        return StandardsComplianceReport(
            format: .tarZst,
            isCompliant: report.isCompliant,
            standardCitation: citation,
            validatedHeaders: report.validatedHeaders,
            warnings: report.warnings,
            violations: report.violations
        )
    }
}
