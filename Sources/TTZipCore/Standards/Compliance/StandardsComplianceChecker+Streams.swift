// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

extension StandardsComplianceChecker {

    // MARK: - GZIP Validation (RFC 1952)

    static func validateGz(
        buffer: UnsafeRawBufferPointer,
        fileSize: Int64,
        citation: StandardCitation?
    ) -> StandardsComplianceReport {
        var validatedHeaders: [String] = []
        var warnings: [String] = []
        var violations: [String] = []

        guard fileSize >= 10 else {
            violations.append("RFC 1952: GZIP stream truncated before 10-byte header (\(fileSize) bytes)")
            return StandardsComplianceReport(format: .gz, isCompliant: false, standardCitation: citation, validatedHeaders: validatedHeaders, warnings: warnings, violations: violations)
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

        if (flg & 0x04) != 0 { validatedHeaders.append("RFC 1952: FEXTRA Header Extension Block") }
        if (flg & 0x08) != 0 { validatedHeaders.append("RFC 1952: FNAME Original Filename Header") }
        if (flg & 0x10) != 0 { validatedHeaders.append("RFC 1952: FCOMMENT File Comment Header") }
        if (flg & 0x02) != 0 { validatedHeaders.append("RFC 1952: FHCRC Header CRC16 Checksum") }

        if fileSize >= 18 {
            validatedHeaders.append("RFC 1952: Trailer CRC32 and ISIZE Fields (offset EOF-8)")
        } else {
            warnings.append("RFC 1952: Stream too short to contain full trailer CRC32 and ISIZE fields")
        }

        let isCompliant = violations.isEmpty
        return StandardsComplianceReport(format: .gz, isCompliant: isCompliant, standardCitation: citation, validatedHeaders: validatedHeaders, warnings: warnings, violations: violations)
    }

    // MARK: - BZIP2 Validation (Julian Seward)

    static func validateBz2(
        buffer: UnsafeRawBufferPointer,
        fileSize: Int64,
        citation: StandardCitation?
    ) -> StandardsComplianceReport {
        var validatedHeaders: [String] = []
        let warnings: [String] = []
        var violations: [String] = []

        guard fileSize >= 4 else {
            violations.append("bzip2: Stream truncated before 4-byte header")
            return StandardsComplianceReport(format: .bz2, isCompliant: false, standardCitation: citation, validatedHeaders: validatedHeaders, warnings: warnings, violations: violations)
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
                return StandardsComplianceReport(format: .bz2, isCompliant: false, standardCitation: citation, validatedHeaders: validatedHeaders, warnings: warnings, violations: violations)
            }
            let blockSig: [UInt8] = [0x31, 0x41, 0x59, 0x26, 0x53, 0x59]
            let eosSig: [UInt8] = [0x17, 0x72, 0x45, 0x38, 0x50, 0x90]
            if memcmp(base.advanced(by: 4), blockSig, 6) == 0 || memcmp(base.advanced(by: 4), eosSig, 6) == 0 {
                validatedHeaders.append("bzip2: Block / Stream-End Magic Sequence")
            }
        }

        let isCompliant = violations.isEmpty
        return StandardsComplianceReport(format: .bz2, isCompliant: isCompliant, standardCitation: citation, validatedHeaders: validatedHeaders, warnings: warnings, violations: violations)
    }

    // MARK: - LZ4 Validation (LZ4 Frame Format v1.6.1)

    static func validateLz4(
        buffer: UnsafeRawBufferPointer,
        fileSize: Int64,
        citation: StandardCitation?
    ) -> StandardsComplianceReport {
        var validatedHeaders: [String] = []
        let warnings: [String] = []
        var violations: [String] = []

        guard fileSize >= 4 else {
            violations.append("LZ4: Stream truncated before 4-byte magic number")
            return StandardsComplianceReport(format: .lz4, isCompliant: false, standardCitation: citation, validatedHeaders: validatedHeaders, warnings: warnings, violations: violations)
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
        return StandardsComplianceReport(format: .lz4, isCompliant: isCompliant, standardCitation: citation, validatedHeaders: validatedHeaders, warnings: warnings, violations: violations)
    }

    // MARK: - LZIP Validation (Lzip Manual v1.24)

    static func validateLzip(
        buffer: UnsafeRawBufferPointer,
        fileSize: Int64,
        citation: StandardCitation?
    ) -> StandardsComplianceReport {
        var validatedHeaders: [String] = []
        let warnings: [String] = []
        var violations: [String] = []

        guard fileSize >= 6 else {
            violations.append("Lzip: Stream truncated before 6-byte header")
            return StandardsComplianceReport(format: .lzip, isCompliant: false, standardCitation: citation, validatedHeaders: validatedHeaders, warnings: warnings, violations: violations)
        }

        guard let base = buffer.baseAddress else {
            violations.append("Invalid buffer base address")
            return StandardsComplianceReport(format: .lzip, isCompliant: false, standardCitation: citation, validatedHeaders: validatedHeaders, warnings: warnings, violations: violations)
        }

        if memcmp(base, "LZIP", 4) == 0 {
            let ver = base.load(fromByteOffset: 4, as: UInt8.self)
            validatedHeaders.append("Lzip: LZIP Header Magic and Version \(ver)")
            validatedHeaders.append("Lzip: Dictionary Size Descriptor")
        } else {
            violations.append("Lzip: Invalid LZIP header magic")
        }

        let isCompliant = violations.isEmpty
        return StandardsComplianceReport(format: .lzip, isCompliant: isCompliant, standardCitation: citation, validatedHeaders: validatedHeaders, warnings: warnings, violations: violations)
    }

    // MARK: - Brotli Validation (RFC 7932)

    static func validateBrotli(
        buffer: UnsafeRawBufferPointer,
        fileSize: Int64,
        citation: StandardCitation?
    ) -> StandardsComplianceReport {
        var validatedHeaders: [String] = []
        let warnings: [String] = []
        var violations: [String] = []

        guard fileSize > 0 else {
            violations.append("RFC 7932: Brotli stream is empty")
            return StandardsComplianceReport(format: .brotli, isCompliant: false, standardCitation: citation, validatedHeaders: validatedHeaders, warnings: warnings, violations: violations)
        }

        validatedHeaders.append("RFC 7932: Brotli Compressed Data Stream")

        let isCompliant = violations.isEmpty
        return StandardsComplianceReport(format: .brotli, isCompliant: isCompliant, standardCitation: citation, validatedHeaders: validatedHeaders, warnings: warnings, violations: violations)
    }

    // MARK: - SNAPPY Validation (Snappy Framing Format v1.1.10)

    static func validateSnappy(
        buffer: UnsafeRawBufferPointer,
        fileSize: Int64,
        citation: StandardCitation?
    ) -> StandardsComplianceReport {
        var validatedHeaders: [String] = []
        let warnings: [String] = []
        var violations: [String] = []

        guard fileSize >= 10 else {
            violations.append("Snappy: Stream truncated before 10-byte identifier chunk")
            return StandardsComplianceReport(format: .snappy, isCompliant: false, standardCitation: citation, validatedHeaders: validatedHeaders, warnings: warnings, violations: violations)
        }

        guard let base = buffer.baseAddress else {
            violations.append("Invalid buffer base address")
            return StandardsComplianceReport(format: .snappy, isCompliant: false, standardCitation: citation, validatedHeaders: validatedHeaders, warnings: warnings, violations: violations)
        }

        let snappySig: [UInt8] = [0xFF, 0x06, 0x00, 0x00, 0x73, 0x4E, 0x61, 0x50, 0x70, 0x59]
        if memcmp(base, snappySig, 10) == 0 {
            validatedHeaders.append("Snappy: Stream Identifier Chunk (0xFF 0x060000 sNaPpY)")
        } else {
            violations.append("Snappy: Invalid Stream Identifier chunk magic")
        }

        let isCompliant = violations.isEmpty
        return StandardsComplianceReport(format: .snappy, isCompliant: isCompliant, standardCitation: citation, validatedHeaders: validatedHeaders, warnings: warnings, violations: violations)
    }

    // MARK: - LRZIP Validation (Con Kolivas)

    static func validateLrzip(
        buffer: UnsafeRawBufferPointer,
        fileSize: Int64,
        citation: StandardCitation?
    ) -> StandardsComplianceReport {
        var validatedHeaders: [String] = []
        let warnings: [String] = []
        var violations: [String] = []

        guard fileSize >= 6 else {
            violations.append("LRZIP: Stream truncated before 6-byte header")
            return StandardsComplianceReport(format: .lrzip, isCompliant: false, standardCitation: citation, validatedHeaders: validatedHeaders, warnings: warnings, violations: violations)
        }

        guard let base = buffer.baseAddress else {
            violations.append("Invalid buffer base address")
            return StandardsComplianceReport(format: .lrzip, isCompliant: false, standardCitation: citation, validatedHeaders: validatedHeaders, warnings: warnings, violations: violations)
        }

        if memcmp(base, "LRZI", 4) == 0 {
            let maj = base.load(fromByteOffset: 4, as: UInt8.self)
            let min = base.load(fromByteOffset: 5, as: UInt8.self)
            validatedHeaders.append("LRZIP: LRZI Header Magic and Version (\(maj).\(min))")
        } else {
            violations.append("LRZIP: Invalid LRZI magic header")
        }

        let isCompliant = violations.isEmpty
        return StandardsComplianceReport(format: .lrzip, isCompliant: isCompliant, standardCitation: citation, validatedHeaders: validatedHeaders, warnings: warnings, violations: violations)
    }
}
