// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.


import Foundation

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
    ///
    /// - Parameters:
    ///   - extraData: Raw memory buffer of the extra fields region.
    ///   - standardFilename: Optional standard filename used to validate `0x7075` Unicode Path CRC-32.
    /// - Returns: Strongly-typed `ParsedZipExtraFields` record.
    public static func parse(
        extraData: UnsafeRawBufferPointer,
        standardFilename: String? = nil
    ) -> ParsedZipExtraFields {
        var result = ParsedZipExtraFields()
        guard !extraData.isEmpty else { return result }

        var offset = 0
        let totalLength = extraData.count

        while offset + 4 <= totalLength {
            let headerID = extraData.loadUnaligned(fromByteOffset: offset, as: UInt16.self).littleEndian
            let dataSize = Int(extraData.loadUnaligned(fromByteOffset: offset + 2, as: UInt16.self).littleEndian)

            let payloadOffset = offset + 4
            guard payloadOffset + dataSize <= totalLength else {
                // Truncated Extra Field block — stop parsing safely
                break
            }

            let payloadBuffer = UnsafeRawBufferPointer(
                rebasing: extraData[payloadOffset ..< (payloadOffset + dataSize)]
            )

            switch headerID {
            case tagExtendedTimestamp: // 0x5455 ("UT")
                parseExtendedTimestamp(payloadBuffer: payloadBuffer, into: &result)

            case tagUnicodePath: // 0x7075 ("up")
                parseUnicodePath(
                    payloadBuffer: payloadBuffer,
                    standardFilename: standardFilename,
                    into: &result
                )

            case tagInfoZipUnix: // 0x7875 ("ux")
                parseInfoZipUnix(payloadBuffer: payloadBuffer, into: &result)

            case tagZip64: // 0x0001
                parseZip64(payloadBuffer: payloadBuffer, into: &result)

            case tagWinZipAES: // 0x9901
                parseWinZipAES(payloadBuffer: payloadBuffer, into: &result)

            default:
                break
            }

            offset = payloadOffset + dataSize
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

    // MARK: - Private Parser Handlers

    private static func parseExtendedTimestamp(
        payloadBuffer: UnsafeRawBufferPointer,
        into result: inout ParsedZipExtraFields
    ) {
        guard payloadBuffer.count >= 1 else { return }
        let flags = payloadBuffer[0]
        var cursor = 1
        let dataSize = payloadBuffer.count

        var modDate: Date?
        var accDate: Date?
        var createDate: Date?

        if (flags & 0x01) != 0, cursor + 4 <= dataSize {
            let mtime = payloadBuffer.loadUnaligned(fromByteOffset: cursor, as: UInt32.self).littleEndian
            modDate = Date(timeIntervalSince1970: TimeInterval(mtime))
            cursor += 4
        }
        if (flags & 0x02) != 0, cursor + 4 <= dataSize {
            let atime = payloadBuffer.loadUnaligned(fromByteOffset: cursor, as: UInt32.self).littleEndian
            accDate = Date(timeIntervalSince1970: TimeInterval(atime))
            cursor += 4
        }
        if (flags & 0x04) != 0, cursor + 4 <= dataSize {
            let ctime = payloadBuffer.loadUnaligned(fromByteOffset: cursor, as: UInt32.self).littleEndian
            createDate = Date(timeIntervalSince1970: TimeInterval(ctime))
            cursor += 4
        }

        result.extendedTimestamp = ExtendedTimestamp(
            modificationTime: modDate,
            accessTime: accDate,
            creationTime: createDate
        )
    }

    private static func parseUnicodePath(
        payloadBuffer: UnsafeRawBufferPointer,
        standardFilename: String?,
        into result: inout ParsedZipExtraFields
    ) {
        guard payloadBuffer.count >= 5 else { return }
        let version = payloadBuffer[0]
        guard version == 1 else { return }

        let nameCRC32 = payloadBuffer.loadUnaligned(fromByteOffset: 1, as: UInt32.self).littleEndian
        let stringLength = payloadBuffer.count - 5

        let isMatch: Bool
        if let standardFilename = standardFilename {
            let computedCRC = computeCRC32(for: standardFilename)
            isMatch = (computedCRC == nameCRC32)
        } else {
            isMatch = true
        }

        guard isMatch else { return }

        if stringLength == 0 {
            result.unicodePath = ""
        } else if let base = payloadBuffer.baseAddress {
            let utf8Ptr = base.advanced(by: 5).assumingMemoryBound(to: UInt8.self)
            let buffer = UnsafeBufferPointer(start: utf8Ptr, count: stringLength)
            if let string = String(bytes: buffer, encoding: .utf8) {
                result.unicodePath = string
            }
        }
    }

    private static func parseInfoZipUnix(
        payloadBuffer: UnsafeRawBufferPointer,
        into result: inout ParsedZipExtraFields
    ) {
        guard payloadBuffer.count >= 3 else { return }
        let version = payloadBuffer[0]
        guard version == 1 else { return }

        let uidSize = Int(payloadBuffer[1])
        guard 2 + uidSize < payloadBuffer.count else { return }

        let gidSize = Int(payloadBuffer[2 + uidSize])
        guard 2 + uidSize + 1 + gidSize <= payloadBuffer.count else { return }

        guard let uid = parseVariableInt(from: payloadBuffer, offset: 2, size: uidSize),
              let gid = parseVariableInt(from: payloadBuffer, offset: 3 + uidSize, size: gidSize) else {
            return
        }

        result.posixPermissions = (uid: uid, gid: gid)
    }

    private static func parseZip64(
        payloadBuffer: UnsafeRawBufferPointer,
        into result: inout ParsedZipExtraFields
    ) {
        guard payloadBuffer.count >= 8 else { return }
        let dataSize = payloadBuffer.count
        var cursor = 0

        var uncompSize: UInt64?
        var compSize: UInt64?
        var relOffset: UInt64?
        var diskNum: UInt32?

        if cursor + 8 <= dataSize {
            uncompSize = payloadBuffer.loadUnaligned(fromByteOffset: cursor, as: UInt64.self).littleEndian
            cursor += 8
        }
        if cursor + 8 <= dataSize {
            compSize = payloadBuffer.loadUnaligned(fromByteOffset: cursor, as: UInt64.self).littleEndian
            cursor += 8
        }
        if cursor + 8 <= dataSize {
            relOffset = payloadBuffer.loadUnaligned(fromByteOffset: cursor, as: UInt64.self).littleEndian
            cursor += 8
        }
        if cursor + 4 <= dataSize {
            diskNum = payloadBuffer.loadUnaligned(fromByteOffset: cursor, as: UInt32.self).littleEndian
            cursor += 4
        }

        result.zip64Info = Zip64ExtraField(
            uncompressedSize: uncompSize,
            compressedSize: compSize,
            relativeOffset: relOffset,
            diskNumber: diskNum
        )
    }

    private static func parseWinZipAES(
        payloadBuffer: UnsafeRawBufferPointer,
        into result: inout ParsedZipExtraFields
    ) {
        guard payloadBuffer.count >= 7 else { return }
        let version = payloadBuffer.loadUnaligned(fromByteOffset: 0, as: UInt16.self).littleEndian
        let vendorID = payloadBuffer.loadUnaligned(fromByteOffset: 2, as: UInt16.self).littleEndian
        let strengthRaw = payloadBuffer[4]
        let actualMethod = payloadBuffer.loadUnaligned(fromByteOffset: 5, as: UInt16.self).littleEndian

        // Vendor ID must be 0x4541 (ASCII "AE")
        guard vendorID == 0x4541 else { return }

        let strength: WinZipAESExtraField.Strength?
        switch strengthRaw {
        case 1:
            strength = .aes128
        case 2:
            strength = .aes192
        case 3:
            strength = .aes256
        default:
            strength = nil
        }

        guard let validStrength = strength else { return }

        result.winZipAES = WinZipAESExtraField(
            version: version,
            vendorID: vendorID,
            strength: validStrength,
            actualMethod: actualMethod
        )
    }

    // MARK: - Helpers

    private static func parseVariableInt(
        from buffer: UnsafeRawBufferPointer,
        offset: Int,
        size: Int
    ) -> UInt32? {
        guard offset + size <= buffer.count else { return nil }
        switch size {
        case 1:
            return UInt32(buffer[offset])
        case 2:
            return UInt32(buffer.loadUnaligned(fromByteOffset: offset, as: UInt16.self).littleEndian)
        case 4:
            return buffer.loadUnaligned(fromByteOffset: offset, as: UInt32.self).littleEndian
        case 8:
            let val64 = buffer.loadUnaligned(fromByteOffset: offset, as: UInt64.self).littleEndian
            return UInt32(truncatingIfNeeded: val64)
        default:
            if size > 0 && size <= 4 {
                var val: UInt32 = 0
                for i in 0..<size {
                    val |= UInt32(buffer[offset + i]) << (i * 8)
                }
                return val
            }
            return nil
        }
    }

    private static func computeCRC32(for string: String) -> UInt32 {
        if string.isEmpty { return 0 }
        if let crc = string.utf8.withContiguousStorageIfAvailable({ buffer -> UInt32 in
            guard let base = buffer.baseAddress else { return 0 }
            return NativeCoreArchitecture.shared.computeFastCRC32(buffer: base, length: buffer.count)
        }) {
            return crc
        }
        let utf8Array = Array(string.utf8)
        return utf8Array.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return 0 }
            return NativeCoreArchitecture.shared.computeFastCRC32(buffer: base, length: raw.count)
        }
    }
}
