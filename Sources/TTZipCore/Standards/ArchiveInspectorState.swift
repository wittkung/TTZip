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
