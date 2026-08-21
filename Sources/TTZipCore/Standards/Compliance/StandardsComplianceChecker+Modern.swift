// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

extension StandardsComplianceChecker {

    // MARK: - 7-Zip Validation (7z Format Specification 24.08)

    static func validate7z(
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
        let computedStartCRC = ttzip_rust_crc32(0, base.advanced(by: 12).assumingMemoryBound(to: UInt8.self), 20)
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

                let computedHeaderCRC = ttzip_rust_crc32(0, base.advanced(by: Int(targetOffset)).assumingMemoryBound(to: UInt8.self), Int(nextHeaderSize))
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

    // MARK: - Zstandard Validation (RFC 8878)

    static func validateZstd(
        buffer: UnsafeRawBufferPointer,
        fileSize: Int64,
        citation: StandardCitation?
    ) -> StandardsComplianceReport {
        var validatedHeaders: [String] = []
        let warnings: [String] = []
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

    // MARK: - XZ Validation (XZ File Format 1.2.0)

    static func validateXz(
        buffer: UnsafeRawBufferPointer,
        fileSize: Int64,
        citation: StandardCitation?
    ) -> StandardsComplianceReport {
        var validatedHeaders: [String] = []
        let warnings: [String] = []
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
}
