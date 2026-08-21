// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

extension StandardsComplianceChecker {

    // MARK: - TAR Validation (POSIX.1-2001 / IEEE Std 1003.1 / ustar & pax)

    static func validateTar(
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
}
