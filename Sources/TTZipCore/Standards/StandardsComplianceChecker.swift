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
