// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

extension StandardsComplianceChecker {

    // MARK: - WIM Validation (MS-WIM Specification v3.0)

    static func validateWim(
        buffer: UnsafeRawBufferPointer,
        fileSize: Int64,
        citation: StandardCitation?
    ) -> StandardsComplianceReport {
        var validatedHeaders: [String] = []
        let warnings: [String] = []
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

    // MARK: - DMG Validation (UDIF / koly Trailer)

    static func validateDmg(
        buffer: UnsafeRawBufferPointer,
        fileSize: Int64,
        citation: StandardCitation?
    ) -> StandardsComplianceReport {
        var validatedHeaders: [String] = []
        let warnings: [String] = []
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

    // MARK: - ISO Validation (ISO 9660 / ECMA-119)

    static func validateIso(
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

    // MARK: - Apple Archive (AAR / AEA)

    static func validateAar(
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
}
