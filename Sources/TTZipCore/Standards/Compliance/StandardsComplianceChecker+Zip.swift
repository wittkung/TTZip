// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

extension StandardsComplianceChecker {

    // MARK: - ZIP Validation (PKWARE APPNOTE.TXT / ISO/IEC 21320-1)

    static func validateZip(
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
            if isZip64 {
                validatedHeaders.append("PKWARE APPNOTE: Archive verified as Zip64 format")
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
}
