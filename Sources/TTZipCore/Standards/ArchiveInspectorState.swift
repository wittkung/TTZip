// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Weitao Kung (Witt Kung) <kevintungs@163.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// 归档标准检查与属性检视展示状态
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

/// 归档诊断快照缓存条目键
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
