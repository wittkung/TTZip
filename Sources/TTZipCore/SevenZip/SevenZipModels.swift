// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// 7z Signature Header (32-byte fixed structure).
public struct SevenZipSignatureHeader: Sendable {
    public static let signature: [UInt8] = [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C]
    public let majorVersion: UInt8
    public let minorVersion: UInt8
    public let startHeaderCRC: UInt32
    public let nextHeaderOffset: UInt64
    public let nextHeaderSize: UInt64
    public let nextHeaderCRC: UInt32
}

/// 7z Property ID constants.
public enum SevenZipPropertyID: UInt8 {
    case kEnd = 0x00
    case kHeader = 0x01
    case kArchiveProperties = 0x02
    case kAdditionalStreamsInfo = 0x03
    case kMainStreamsInfo = 0x04
    case kFilesInfo = 0x05
    case kPackInfo = 0x06
    case kUnpackInfo = 0x07
    case kSubStreamsInfo = 0x08
    case kSize = 0x09
    case kCRC = 0x0A
    case kFolder = 0x0B
    case kCodersUnpackSize = 0x0C
    case kNumUnpackStream = 0x0D
    case kEmptyStream = 0x0E
    case kEmptyFile = 0x0F
    case kAnti = 0x10
    case kName = 0x11
    case kCTime = 0x12
    case kATime = 0x13
    case kMTime = 0x14
    case kWinAttrib = 0x15
    case kComment = 0x16
    case kEncodedHeader = 0x17
    case kStartPos = 0x18
    case kDummy = 0x19
}

/// 7z Coder algorithm identifier.
public enum SevenZipCoderMethod: Sendable {
    case copy
    case lzma
    case lzma2
    case zstd
    case ppmd
    case bcj
    case bcj2
    case aes256
    case unknown([UInt8])
}

/// 7z entry physical descriptor.
public struct SevenZipEntryDescriptor: Sendable {
    public let path: String
    public let isDirectory: Bool
    public let compressedSize: Int64
    public let uncompressedSize: Int64
    public let packOffset: Int64
    public let crc32: UInt32
    public let isEncrypted: Bool
    public let folderIndex: Int
}
