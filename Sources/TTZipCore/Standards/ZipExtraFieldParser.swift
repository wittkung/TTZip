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
    public static func parse(
        extraData: UnsafeRawBufferPointer,
        standardFilename: String? = nil
    ) -> ParsedZipExtraFields {
        guard let base = extraData.baseAddress, !extraData.isEmpty else {
            return ParsedZipExtraFields()
        }

        var cFields = ttzip_zip_extra_fields_t()
        let bytePtr = base.assumingMemoryBound(to: UInt8.self)

        let res: Int32
        if let stdName = standardFilename {
            res = stdName.withCString { cName in
                ttzip_zip_parse_extra_fields(bytePtr, extraData.count, cName, &cFields)
            }
        } else {
            res = ttzip_zip_parse_extra_fields(bytePtr, extraData.count, nil, &cFields)
        }

        guard res == 0 else { return ParsedZipExtraFields() }

        var result = ParsedZipExtraFields()

        if cFields.has_extended_timestamp {
            let modDate = (cFields.timestamp_flags & 0x01 != 0) ? Date(timeIntervalSince1970: TimeInterval(cFields.mod_time)) : nil
            let accDate = (cFields.timestamp_flags & 0x02 != 0) ? Date(timeIntervalSince1970: TimeInterval(cFields.acc_time)) : nil
            let createDate = (cFields.timestamp_flags & 0x04 != 0) ? Date(timeIntervalSince1970: TimeInterval(cFields.create_time)) : nil
            result.extendedTimestamp = ExtendedTimestamp(
                modificationTime: modDate,
                accessTime: accDate,
                creationTime: createDate
            )
        }

        if let uPathPtr = cFields.unicode_path, cFields.unicode_path_crc_valid {
            let buf = UnsafeRawBufferPointer(start: uPathPtr, count: cFields.unicode_path_len)
            result.unicodePath = String(decoding: buf, as: UTF8.self)
        }

        if cFields.has_posix_permissions {
            result.posixPermissions = (uid: cFields.uid, gid: cFields.gid)
        }

        if cFields.has_zip64 {
            let mask = cFields.zip64_presence_mask
            let uncomp = (mask & 1 != 0) ? cFields.uncompressed_size : nil
            let comp = (mask & 2 != 0) ? cFields.compressed_size : nil
            let offset = (mask & 4 != 0) ? cFields.relative_offset : nil
            let disk = (mask & 8 != 0) ? cFields.disk_number : nil
            result.zip64Info = Zip64ExtraField(
                uncompressedSize: uncomp,
                compressedSize: comp,
                relativeOffset: offset,
                diskNumber: disk
            )
        }

        if cFields.has_winzip_aes {
            let strengthEnum: WinZipAESExtraField.Strength? = {
                switch cFields.aes_strength {
                case 128: return .aes128
                case 192: return .aes192
                case 256: return .aes256
                default: return nil
                }
            }()
            if let str = strengthEnum {
                result.winZipAES = WinZipAESExtraField(
                    version: cFields.aes_version,
                    vendorID: cFields.aes_vendor_id,
                    strength: str,
                    actualMethod: cFields.aes_actual_method
                )
            }
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
}
