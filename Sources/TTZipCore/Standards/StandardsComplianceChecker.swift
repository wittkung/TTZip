// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// State representation for archive inspection and standards compliance auditing.
public struct ArchiveInspectorState: Sendable, Equatable {
    public let filePath: String
    public let fileName: String
    public let fileByteSize: Int64
    public let detectedFormat: ArchiveCompressionFormat?
    public let standardSpec: ArchiveFormatStandardSpec?
    public let signatureMatches: [ArchiveMagicSignature]
    public let parsedExtraFields: ParsedZipExtraFields?
    public let complianceReport: StandardsComplianceReport?
    public let isScanning: Bool
    public let scanDurationMs: Double
    public let errorMessage: String?
    
    public init(
        filePath: String,
        fileName: String,
        fileByteSize: Int64,
        detectedFormat: ArchiveCompressionFormat?,
        standardSpec: ArchiveFormatStandardSpec?,
        signatureMatches: [ArchiveMagicSignature],
        parsedExtraFields: ParsedZipExtraFields?,
        complianceReport: StandardsComplianceReport?,
        isScanning: Bool,
        scanDurationMs: Double,
        errorMessage: String?
    ) {
        self.filePath = filePath
        self.fileName = fileName
        self.fileByteSize = fileByteSize
        self.detectedFormat = detectedFormat
        self.standardSpec = standardSpec
        self.signatureMatches = signatureMatches
        self.parsedExtraFields = parsedExtraFields
        self.complianceReport = complianceReport
        self.isScanning = isScanning
        self.scanDurationMs = scanDurationMs
        self.errorMessage = errorMessage
    }
}

/// Cache key for archive diagnostics snapshots.
public struct ArchiveDiagnosticsCacheKey: Hashable, Sendable {
    public let filePath: String
    public let fileByteSize: Int64
    public let modificationTimestamp: Double
    
    public init(filePath: String, fileByteSize: Int64, modificationTimestamp: Double) {
        self.filePath = filePath
        self.fileByteSize = fileByteSize
        self.modificationTimestamp = modificationTimestamp
    }
}

// MARK: - Zip Extra Field Parser

//
//



/// Extended timestamp metadata parsed from Info-ZIP Extra Field tag `0x5455` ("UT").
public struct ExtendedTimestamp: Sendable, Equatable, Codable {
    public let modificationTime: Date?
    public let accessTime: Date?
    public let creationTime: Date?

    public var modTime: Date? { modificationTime }
    public var accTime: Date? { accessTime }
    public var createTime: Date? { creationTime }

    public init(
        modificationTime: Date? = nil,
        accessTime: Date? = nil,
        creationTime: Date? = nil
    ) {
        self.modificationTime = modificationTime
        self.accessTime = accessTime
        self.creationTime = creationTime
    }

    public init(
        modTime: Date? = nil,
        accTime: Date? = nil,
        createTime: Date? = nil
    ) {
        self.modificationTime = modTime
        self.accessTime = accTime
        self.creationTime = createTime
    }
}

/// Zip64 extended information parsed from PKWARE Extra Field tag `0x0001`.
public struct Zip64ExtraField: Sendable, Equatable, Codable {
    public let uncompressedSize: UInt64?
    public let compressedSize: UInt64?
    public let relativeOffset: UInt64?
    public let diskNumber: UInt32?

    public init(
        uncompressedSize: UInt64? = nil,
        compressedSize: UInt64? = nil,
        relativeOffset: UInt64? = nil,
        diskNumber: UInt32? = nil
    ) {
        self.uncompressedSize = uncompressedSize
        self.compressedSize = compressedSize
        self.relativeOffset = relativeOffset
        self.diskNumber = diskNumber
    }
}

/// WinZip AES encryption parameters parsed from Extra Field tag `0x9901` ("AE").
public struct WinZipAESExtraField: Sendable, Equatable, Codable {
    public enum Strength: Int, Sendable, Equatable, Codable {
        case aes128 = 128
        case aes192 = 192
        case aes256 = 256
    }

    public let version: UInt16
    public let vendorID: UInt16
    public let strength: Strength
    public let actualMethod: UInt16

    public init(
        version: UInt16 = 2,
        vendorID: UInt16 = 0x4541,
        strength: Strength,
        actualMethod: UInt16
    ) {
        self.version = version
        self.vendorID = vendorID
        self.strength = strength
        self.actualMethod = actualMethod
    }
}

/// Aggregated strongly-typed representation of all parsed standard ZIP Extra Fields.
public struct ParsedZipExtraFields: Sendable, Equatable {
    public var extendedTimestamp: ExtendedTimestamp?
    public var unicodePath: String?
    public var posixPermissions: (uid: UInt32, gid: UInt32)?
    public var zip64Info: Zip64ExtraField?
    public var winZipAES: WinZipAESExtraField?

    public init(
        extendedTimestamp: ExtendedTimestamp? = nil,
        unicodePath: String? = nil,
        posixPermissions: (uid: UInt32, gid: UInt32)? = nil,
        zip64Info: Zip64ExtraField? = nil,
        winZipAES: WinZipAESExtraField? = nil
    ) {
        self.extendedTimestamp = extendedTimestamp
        self.unicodePath = unicodePath
        self.posixPermissions = posixPermissions
        self.zip64Info = zip64Info
        self.winZipAES = winZipAES
    }

    public static func == (lhs: ParsedZipExtraFields, rhs: ParsedZipExtraFields) -> Bool {
        guard lhs.extendedTimestamp == rhs.extendedTimestamp,
              lhs.unicodePath == rhs.unicodePath,
              lhs.zip64Info == rhs.zip64Info,
              lhs.winZipAES == rhs.winZipAES else {
            return false
        }
        switch (lhs.posixPermissions, rhs.posixPermissions) {
        case (nil, nil):
            return true
        case let (l?, r?):
            return l.uid == r.uid && l.gid == r.gid
        default:
            return false
        }
    }
}

/// High-performance zero-allocation Tag-Length-Value (TLV) parser for ZIP Extra Fields.
public enum ZipExtraFieldParser {
    /// Tag identifier constants
    public static let tagZip64: UInt16 = 0x0001
    public static let tagExtendedTimestamp: UInt16 = 0x5455 // "UT"
    public static let tagUnicodePath: UInt16 = 0x7075       // "up"
    public static let tagInfoZipUnix: UInt16 = 0x7875       // "ux"
    public static let tagWinZipAES: UInt16 = 0x9901         // "AE"

    /// Parses all recognized Extra Field TLV blocks from raw byte buffer.
    public static func parse(
        extraData: UnsafeRawBufferPointer,
        standardFilename: String? = nil
    ) -> ParsedZipExtraFields {
        guard extraData.count >= 4 else {
            return ParsedZipExtraFields()
        }

        var result = ParsedZipExtraFields()
        var offset = 0
        let total = extraData.count

        while offset + 4 <= total {
            let headerId = extraData.loadUnaligned(fromByteOffset: offset, as: UInt16.self).littleEndian
            let dataSize = Int(extraData.loadUnaligned(fromByteOffset: offset + 2, as: UInt16.self).littleEndian)
            offset += 4

            guard offset + dataSize <= total else { break }
            let payload = extraData.baseAddress!.advanced(by: offset)

            switch headerId {
            case 0x5455: // Extended Timestamp
                if dataSize >= 1 {
                    let flags = payload.load(as: UInt8.self)
                    var pOffset = 1
                    var modTime: Date? = nil
                    var accTime: Date? = nil
                    var crTime: Date? = nil
                    if (flags & 1 != 0) && pOffset + 4 <= dataSize {
                        let t = payload.loadUnaligned(fromByteOffset: pOffset, as: UInt32.self).littleEndian
                        modTime = Date(timeIntervalSince1970: TimeInterval(t))
                        pOffset += 4
                    }
                    if (flags & 2 != 0) && pOffset + 4 <= dataSize {
                        let t = payload.loadUnaligned(fromByteOffset: pOffset, as: UInt32.self).littleEndian
                        accTime = Date(timeIntervalSince1970: TimeInterval(t))
                        pOffset += 4
                    }
                    if (flags & 4 != 0) && pOffset + 4 <= dataSize {
                        let t = payload.loadUnaligned(fromByteOffset: pOffset, as: UInt32.self).littleEndian
                        crTime = Date(timeIntervalSince1970: TimeInterval(t))
                        pOffset += 4
                    }
                    result.extendedTimestamp = ExtendedTimestamp(modificationTime: modTime, accessTime: accTime, creationTime: crTime)
                }
            case 0x7075: // Info-ZIP Unicode Path
                if dataSize >= 5 {
                    let origCRC = payload.loadUnaligned(fromByteOffset: 1, as: UInt32.self).littleEndian
                    if let stdName = standardFilename {
                        let utf8Arr = Array(stdName.utf8)
                        let calcCRC = utf8Arr.withUnsafeBytes { raw in
                            NativeCoreArchitecture.shared.computeFastCRC32(buffer: raw.baseAddress!, length: raw.count)
                        }
                        if calcCRC != origCRC {
                            break
                        }
                    }
                    let pathBytes = UnsafeRawBufferPointer(start: payload.advanced(by: 5), count: dataSize - 5)
                    result.unicodePath = String(decoding: pathBytes, as: UTF8.self)
                }
            case 0x7875: // Info-ZIP New Unix
                if dataSize >= 4 {
                    let uidSize = Int(payload.advanced(by: 1).load(as: UInt8.self))
                    var pOff = 2
                    var uid: UInt32 = 0
                    if pOff + uidSize <= dataSize {
                        if uidSize == 2 {
                            uid = UInt32(payload.loadUnaligned(fromByteOffset: pOff, as: UInt16.self).littleEndian)
                        } else if uidSize == 4 {
                            uid = payload.loadUnaligned(fromByteOffset: pOff, as: UInt32.self).littleEndian
                        }
                        pOff += uidSize
                    }
                    var gid: UInt32 = 0
                    if pOff < dataSize {
                        let gidSize = Int(payload.advanced(by: pOff).load(as: UInt8.self))
                        pOff += 1
                        if pOff + gidSize <= dataSize {
                            if gidSize == 2 {
                                gid = UInt32(payload.loadUnaligned(fromByteOffset: pOff, as: UInt16.self).littleEndian)
                            } else if gidSize == 4 {
                                gid = payload.loadUnaligned(fromByteOffset: pOff, as: UInt32.self).littleEndian
                            }
                        }
                    }
                    result.posixPermissions = (uid: uid, gid: gid)
                }
            case 0x0001: // Zip64
                var uncomp: UInt64? = nil
                var comp: UInt64? = nil
                var off: UInt64? = nil
                var disk: UInt32? = nil
                var pOff = 0
                if pOff + 8 <= dataSize { uncomp = payload.loadUnaligned(fromByteOffset: pOff, as: UInt64.self).littleEndian; pOff += 8 }
                if pOff + 8 <= dataSize { comp = payload.loadUnaligned(fromByteOffset: pOff, as: UInt64.self).littleEndian; pOff += 8 }
                if pOff + 8 <= dataSize { off = payload.loadUnaligned(fromByteOffset: pOff, as: UInt64.self).littleEndian; pOff += 8 }
                if pOff + 4 <= dataSize { disk = payload.loadUnaligned(fromByteOffset: pOff, as: UInt32.self).littleEndian; pOff += 4 }
                result.zip64Info = Zip64ExtraField(uncompressedSize: uncomp, compressedSize: comp, relativeOffset: off, diskNumber: disk)
            case 0x9901: // WinZip AES
                if dataSize >= 7 {
                    let ver = payload.loadUnaligned(fromByteOffset: 0, as: UInt16.self).littleEndian
                    let vendor = payload.loadUnaligned(fromByteOffset: 2, as: UInt16.self).littleEndian
                    let strength = payload.advanced(by: 4).load(as: UInt8.self)
                    let method = payload.loadUnaligned(fromByteOffset: 5, as: UInt16.self).littleEndian
                    let str: WinZipAESExtraField.Strength? = strength == 1 ? .aes128 : (strength == 2 ? .aes192 : (strength == 3 ? .aes256 : nil))
                    if let s = str {
                        result.winZipAES = WinZipAESExtraField(version: ver, vendorID: vendor, strength: s, actualMethod: method)
                    }
                }
            default:
                break
            }
            offset += dataSize
        }
        return result
    }

    /// Convenience parser accepting `Data`.
    public static func parse(
        extraData: Data,
        standardFilename: String? = nil
    ) -> ParsedZipExtraFields {
        extraData.withUnsafeBytes { rawBuffer in
            parse(extraData: rawBuffer, standardFilename: standardFilename)
        }
    }

    /// Convenience parser accepting `[UInt8]`.
    public static func parse(
        extraData: [UInt8],
        standardFilename: String? = nil
    ) -> ParsedZipExtraFields {
        extraData.withUnsafeBytes { rawBuffer in
            parse(extraData: rawBuffer, standardFilename: standardFilename)
        }
    }
}

// MARK: - Compliance Checker

//
//


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

/// Standards Compliance Checker delegating directly to high-performance Rust validation kernels.
public enum StandardsComplianceChecker {

    // MARK: - Public Validation APIs

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

    /// Validates compliance of an `UnsafeRawBufferPointer` by delegating directly to Rust C-ABI.
    public static func checkCompliance(
        buffer: UnsafeRawBufferPointer,
        fileSize: Int64,
        expectedFormat: ArchiveCompressionFormat? = nil,
        fileURL: URL? = nil
    ) throws -> StandardsComplianceReport {
        // Detect target format if not explicitly provided
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
        guard let base = buffer.baseAddress, !buffer.isEmpty else {
            return StandardsComplianceReport(
                format: targetFormat,
                isCompliant: false,
                standardCitation: citation,
                validatedHeaders: [],
                warnings: [],
                violations: ["Buffer is empty (0 bytes)"]
            )
        }

        var reportPtr: UnsafeMutablePointer<CChar>? = nil
        var isCompliant: Bool = false
        let formatCode = mapFormatToRustCode(targetFormat)

        let status = ttzip_rust_check_compliance_buffer(
            base.assumingMemoryBound(to: UInt8.self),
            buffer.count,
            formatCode,
            &reportPtr,
            &isCompliant
        )

        guard status == TTZIP_STATUS_OK, let ptr = reportPtr else {
            return StandardsComplianceReport(
                format: targetFormat,
                isCompliant: false,
                standardCitation: citation,
                validatedHeaders: [],
                warnings: [],
                violations: ["Rust compliance evaluation failed with status \(status)"]
            )
        }
        defer { ttzip_rust_free_compliance_report(ptr) }

        let jsonString = String(cString: ptr)
        guard let jsonData = jsonString.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(RustComplianceJsonPayload.self, from: jsonData) else {
            return StandardsComplianceReport(
                format: targetFormat,
                isCompliant: isCompliant,
                standardCitation: citation,
                validatedHeaders: [],
                warnings: [],
                violations: ["Failed to decode compliance JSON report from Rust"]
            )
        }

        let warnings = decoded.issues?
            .filter { $0.severity == "WARNING" }
            .map { $0.message } ?? []

        let violations = decoded.issues?
            .filter { $0.severity == "ERROR" }
            .map { $0.message } ?? []

        return StandardsComplianceReport(
            format: targetFormat,
            isCompliant: decoded.is_compliant,
            standardCitation: citation,
            validatedHeaders: decoded.validated_headers ?? [],
            warnings: warnings,
            violations: violations
        )
    }

    // MARK: - Native Direct String APIs

    /// Performs direct standards compliance verification via Rust C-ABI returning raw JSON.
    public static func checkComplianceNative(
        buffer: UnsafeRawBufferPointer,
        expectedFormat: ArchiveCompressionFormat? = nil
    ) -> (isCompliant: Bool, reportJson: String?) {
        guard let base = buffer.baseAddress, !buffer.isEmpty else { return (false, nil) }
        var reportPtr: UnsafeMutablePointer<CChar>? = nil
        var isCompliant: Bool = false
        let formatHint = mapFormatToRustCode(expectedFormat)

        let status = ttzip_rust_check_compliance_buffer(
            base.assumingMemoryBound(to: UInt8.self),
            buffer.count,
            formatHint,
            &reportPtr,
            &isCompliant
        )

        guard status == TTZIP_STATUS_OK, let ptr = reportPtr else {
            return (false, nil)
        }
        defer { ttzip_rust_free_compliance_report(ptr) }
        return (isCompliant, String(cString: ptr))
    }

    /// Performs direct standards compliance verification on disk via Rust C-ABI returning raw JSON.
    public static func checkComplianceNative(
        fileURL: URL
    ) -> (isCompliant: Bool, reportJson: String?) {
        let path = fileURL.path
        guard FileManager.default.fileExists(atPath: path) else { return (false, nil) }

        var reportPtr: UnsafeMutablePointer<CChar>? = nil
        var isCompliant: Bool = false

        let status = path.withCString { cPath in
            ttzip_rust_check_compliance_file(cPath, &reportPtr, &isCompliant)
        }

        guard status == TTZIP_STATUS_OK, let ptr = reportPtr else {
            return (false, nil)
        }
        defer { ttzip_rust_free_compliance_report(ptr) }
        return (isCompliant, String(cString: ptr))
    }

    // MARK: - Format Mapping Helper

    private static func mapFormatToRustCode(_ format: ArchiveCompressionFormat?) -> Int32 {
        guard let format = format else { return 0 }
        switch format {
        case .zip: return 1
        case .sevenZip: return 2
        case .tar: return 3
        case .gz, .tarGz: return 4
        case .bz2, .tarBz2: return 5
        case .xz, .tarXz: return 6
        case .zst, .tarZst: return 7
        case .iso: return 10
        case .dmg: return 11
        case .snappy: return 16
        case .lz4: return 17
        case .lzip: return 18
        case .lrzip: return 19
        case .brotli: return 20
        case .aar: return 21
        case .wim: return 22
        }
    }
}

// MARK: - Internal JSON Decoder Model

private struct RustComplianceJsonPayload: Decodable {
    let format: String?
    let is_compliant: Bool
    let validated_headers: [String]?
    let metadata: [String: String]?
    let issues: [RustComplianceIssuePayload]?
}

private struct RustComplianceIssuePayload: Decodable {
    let severity: String
    let standard: String?
    let section: String?
    let message: String
    let offset: Int64?
}
