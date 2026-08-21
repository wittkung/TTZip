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
        guard extraData.count >= 4 else {
            return ParsedZipExtraFields()
        }

        var result = ParsedZipExtraFields()
        var offset = 0
        let total = extraData.count

        while offset + 4 <= total {
            let headerId = extraData.loadUnaligned(fromByteOffset: offset, as: UInt16.self).littleEndian
            let dataSize = Int(extraData.loadUnaligned(fromByteOffset: offset + 2, as: UInt16.self).littleEndian)
            offset += 4

            guard offset + dataSize <= total else { break }
            let payload = extraData.baseAddress!.advanced(by: offset)

            switch headerId {
            case 0x5455: // Extended Timestamp
                if dataSize >= 1 {
                    let flags = payload.load(as: UInt8.self)
                    var pOffset = 1
                    var modTime: Date? = nil
                    var accTime: Date? = nil
                    var crTime: Date? = nil
                    if (flags & 1 != 0) && pOffset + 4 <= dataSize {
                        let t = payload.loadUnaligned(fromByteOffset: pOffset, as: UInt32.self).littleEndian
                        modTime = Date(timeIntervalSince1970: TimeInterval(t))
                        pOffset += 4
                    }
                    if (flags & 2 != 0) && pOffset + 4 <= dataSize {
                        let t = payload.loadUnaligned(fromByteOffset: pOffset, as: UInt32.self).littleEndian
                        accTime = Date(timeIntervalSince1970: TimeInterval(t))
                        pOffset += 4
                    }
                    if (flags & 4 != 0) && pOffset + 4 <= dataSize {
                        let t = payload.loadUnaligned(fromByteOffset: pOffset, as: UInt32.self).littleEndian
                        crTime = Date(timeIntervalSince1970: TimeInterval(t))
                        pOffset += 4
                    }
                    result.extendedTimestamp = ExtendedTimestamp(modificationTime: modTime, accessTime: accTime, creationTime: crTime)
                }
            case 0x7075: // Info-ZIP Unicode Path
                if dataSize >= 5 {
                    let origCRC = payload.loadUnaligned(fromByteOffset: 1, as: UInt32.self).littleEndian
                    if let stdName = standardFilename {
                        let utf8Arr = Array(stdName.utf8)
                        let calcCRC = utf8Arr.withUnsafeBytes { raw in
                            NativeCoreArchitecture.shared.computeFastCRC32(buffer: raw.baseAddress!, length: raw.count)
                        }
                        if calcCRC != origCRC {
                            break
                        }
                    }
                    let pathBytes = UnsafeRawBufferPointer(start: payload.advanced(by: 5), count: dataSize - 5)
                    result.unicodePath = String(decoding: pathBytes, as: UTF8.self)
                }
            case 0x7875: // Info-ZIP New Unix
                if dataSize >= 4 {
                    let uidSize = Int(payload.advanced(by: 1).load(as: UInt8.self))
                    var pOff = 2
                    var uid: UInt32 = 0
                    if pOff + uidSize <= dataSize {
                        if uidSize == 2 {
                            uid = UInt32(payload.loadUnaligned(fromByteOffset: pOff, as: UInt16.self).littleEndian)
                        } else if uidSize == 4 {
                            uid = payload.loadUnaligned(fromByteOffset: pOff, as: UInt32.self).littleEndian
                        }
                        pOff += uidSize
                    }
                    var gid: UInt32 = 0
                    if pOff < dataSize {
                        let gidSize = Int(payload.advanced(by: pOff).load(as: UInt8.self))
                        pOff += 1
                        if pOff + gidSize <= dataSize {
                            if gidSize == 2 {
                                gid = UInt32(payload.loadUnaligned(fromByteOffset: pOff, as: UInt16.self).littleEndian)
                            } else if gidSize == 4 {
                                gid = payload.loadUnaligned(fromByteOffset: pOff, as: UInt32.self).littleEndian
                            }
                        }
                    }
                    result.posixPermissions = (uid: uid, gid: gid)
                }
            case 0x0001: // Zip64
                var uncomp: UInt64? = nil
                var comp: UInt64? = nil
                var off: UInt64? = nil
                var disk: UInt32? = nil
                var pOff = 0
                if pOff + 8 <= dataSize { uncomp = payload.loadUnaligned(fromByteOffset: pOff, as: UInt64.self).littleEndian; pOff += 8 }
                if pOff + 8 <= dataSize { comp = payload.loadUnaligned(fromByteOffset: pOff, as: UInt64.self).littleEndian; pOff += 8 }
                if pOff + 8 <= dataSize { off = payload.loadUnaligned(fromByteOffset: pOff, as: UInt64.self).littleEndian; pOff += 8 }
                if pOff + 4 <= dataSize { disk = payload.loadUnaligned(fromByteOffset: pOff, as: UInt32.self).littleEndian; pOff += 4 }
                result.zip64Info = Zip64ExtraField(uncompressedSize: uncomp, compressedSize: comp, relativeOffset: off, diskNumber: disk)
            case 0x9901: // WinZip AES
                if dataSize >= 7 {
                    let ver = payload.loadUnaligned(fromByteOffset: 0, as: UInt16.self).littleEndian
                    let vendor = payload.loadUnaligned(fromByteOffset: 2, as: UInt16.self).littleEndian
                    let strength = payload.advanced(by: 4).load(as: UInt8.self)
                    let method = payload.loadUnaligned(fromByteOffset: 5, as: UInt16.self).littleEndian
                    let str: WinZipAESExtraField.Strength? = strength == 1 ? .aes128 : (strength == 2 ? .aes192 : (strength == 3 ? .aes256 : nil))
                    if let s = str {
                        result.winZipAES = WinZipAESExtraField(version: ver, vendorID: vendor, strength: s, actualMethod: method)
                    }
                }
            default:
                break
            }
            offset += dataSize
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
