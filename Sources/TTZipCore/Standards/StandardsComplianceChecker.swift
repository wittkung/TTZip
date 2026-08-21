// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

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
            return Self.validateZip(buffer: buffer, fileSize: fileSize, citation: citation)
        case .tar:
            return Self.validateTar(buffer: buffer, fileSize: fileSize, citation: citation)
        case .gz:
            return Self.validateGz(buffer: buffer, fileSize: fileSize, citation: citation)
        case .zst:
            return Self.validateZstd(buffer: buffer, fileSize: fileSize, citation: citation)
        case .sevenZip:
            return Self.validate7z(buffer: buffer, fileSize: fileSize, citation: citation)
        case .bz2:
            return Self.validateBz2(buffer: buffer, fileSize: fileSize, citation: citation)
        case .xz:
            return Self.validateXz(buffer: buffer, fileSize: fileSize, citation: citation)
        case .lz4:
            return Self.validateLz4(buffer: buffer, fileSize: fileSize, citation: citation)
        case .lzip:
            return Self.validateLzip(buffer: buffer, fileSize: fileSize, citation: citation)
        case .brotli:
            return Self.validateBrotli(buffer: buffer, fileSize: fileSize, citation: citation)
        case .lrzip:
            return Self.validateLrzip(buffer: buffer, fileSize: fileSize, citation: citation)
        case .aar:
            return Self.validateAar(buffer: buffer, fileSize: fileSize, citation: citation)
        case .snappy:
            return Self.validateSnappy(buffer: buffer, fileSize: fileSize, citation: citation)
        case .wim:
            return Self.validateWim(buffer: buffer, fileSize: fileSize, citation: citation)
        case .dmg:
            return Self.validateDmg(buffer: buffer, fileSize: fileSize, citation: citation)
        case .iso:
            return Self.validateIso(buffer: buffer, fileSize: fileSize, citation: citation)
        case .tarGz:
            return Self.validateTarGz(buffer: buffer, fileSize: fileSize, citation: citation)
        case .tarBz2:
            return Self.validateTarBz2(buffer: buffer, fileSize: fileSize, citation: citation)
        case .tarXz:
            return Self.validateTarXz(buffer: buffer, fileSize: fileSize, citation: citation)
        case .tarZst:
            return Self.validateTarZst(buffer: buffer, fileSize: fileSize, citation: citation)
        }
    }

    // MARK: - Compound Format Validation Proxies

    static func validateTarGz(
        buffer: UnsafeRawBufferPointer,
        fileSize: Int64,
        citation: StandardCitation?
    ) -> StandardsComplianceReport {
        let report = Self.validateGz(buffer: buffer, fileSize: fileSize, citation: citation)
        return StandardsComplianceReport(
            format: .tarGz,
            isCompliant: report.isCompliant,
            standardCitation: citation,
            validatedHeaders: report.validatedHeaders,
            warnings: report.warnings,
            violations: report.violations
        )
    }

    static func validateTarBz2(
        buffer: UnsafeRawBufferPointer,
        fileSize: Int64,
        citation: StandardCitation?
    ) -> StandardsComplianceReport {
        let report = Self.validateBz2(buffer: buffer, fileSize: fileSize, citation: citation)
        return StandardsComplianceReport(
            format: .tarBz2,
            isCompliant: report.isCompliant,
            standardCitation: citation,
            validatedHeaders: report.validatedHeaders,
            warnings: report.warnings,
            violations: report.violations
        )
    }

    static func validateTarXz(
        buffer: UnsafeRawBufferPointer,
        fileSize: Int64,
        citation: StandardCitation?
    ) -> StandardsComplianceReport {
        let report = Self.validateXz(buffer: buffer, fileSize: fileSize, citation: citation)
        return StandardsComplianceReport(
            format: .tarXz,
            isCompliant: report.isCompliant,
            standardCitation: citation,
            validatedHeaders: report.validatedHeaders,
            warnings: report.warnings,
            violations: report.violations
        )
    }

    static func validateTarZst(
        buffer: UnsafeRawBufferPointer,
        fileSize: Int64,
        citation: StandardCitation?
    ) -> StandardsComplianceReport {
        let report = Self.validateZstd(buffer: buffer, fileSize: fileSize, citation: citation)
        return StandardsComplianceReport(
            format: .tarZst,
            isCompliant: report.isCompliant,
            standardCitation: citation,
            validatedHeaders: report.validatedHeaders,
            warnings: report.warnings,
            violations: report.violations
        )
    }

    // MARK: - Native Rust C-ABI Compliance Verification

    /// Performs fast direct standards compliance verification via Rust C-ABI.
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

    /// Performs fast direct standards compliance verification on disk via Rust C-ABI.
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
        default: return 0
        }
    }
}
