// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Represents the authoritative standards definition for an archive or compression format.
public struct ArchiveFormatStandardSpec: Sendable, Equatable, Identifiable, Codable {
    public let id: String
    public let format: ArchiveCompressionFormat
    public let officialName: String
    public let standardCitations: [StandardCitation]
    public let mimeType: String
    public let appleUTI: String
    public let magicSignatures: [ArchiveMagicSignature]
    public let supportedEncryption: [EncryptionStandardSpec]
    public let supportsMultiVolume: Bool
    public let supportedExtraFields: [ZipExtraFieldStandardSpec]

    public init(
        id: String,
        format: ArchiveCompressionFormat,
        officialName: String,
        standardCitations: [StandardCitation],
        mimeType: String,
        appleUTI: String,
        magicSignatures: [ArchiveMagicSignature],
        supportedEncryption: [EncryptionStandardSpec] = [],
        supportsMultiVolume: Bool = false,
        supportedExtraFields: [ZipExtraFieldStandardSpec] = []
    ) {
        self.id = id
        self.format = format
        self.officialName = officialName
        self.standardCitations = standardCitations
        self.mimeType = mimeType
        self.appleUTI = appleUTI
        self.magicSignatures = magicSignatures
        self.supportedEncryption = supportedEncryption
        self.supportsMultiVolume = supportsMultiVolume
        self.supportedExtraFields = supportedExtraFields
    }
}

/// Official citation of an RFC, ISO, IEEE, POSIX, or vendor specification.
public struct StandardCitation: Sendable, Equatable, Codable {
    public let organization: String
    public let standardNumber: String
    public let title: String
    public let canonicalURL: String

    public init(
        organization: String,
        standardNumber: String,
        title: String,
        canonicalURL: String
    ) {
        self.organization = organization
        self.standardNumber = standardNumber
        self.title = title
        self.canonicalURL = canonicalURL
    }
}

/// Magic signature definition with position anchoring.
public struct ArchiveMagicSignature: Sendable, Equatable, Codable {
    public enum Anchor: Sendable, Equatable, Codable {
        case head(offset: Int)
        case tail(offsetFromEOF: Int)
        case sector(sectorIndex: Int, byteOffset: Int)
        case tarOffset(byteOffset: Int)

        private enum CodingKeys: String, CodingKey {
            case type
            case offset
            case sectorIndex
            case byteOffset
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            switch type {
            case "head":
                let offset = try container.decode(Int.self, forKey: .offset)
                self = .head(offset: offset)
            case "tail":
                let offset = try container.decode(Int.self, forKey: .offset)
                self = .tail(offsetFromEOF: offset)
            case "sector":
                let sector = try container.decode(Int.self, forKey: .sectorIndex)
                let byteOffset = try container.decode(Int.self, forKey: .byteOffset)
                self = .sector(sectorIndex: sector, byteOffset: byteOffset)
            case "tarOffset":
                let byteOffset = try container.decode(Int.self, forKey: .byteOffset)
                self = .tarOffset(byteOffset: byteOffset)
            default:
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown anchor type: \(type)")
                )
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .head(let offset):
                try container.encode("head", forKey: .type)
                try container.encode(offset, forKey: .offset)
            case .tail(let offsetFromEOF):
                try container.encode("tail", forKey: .type)
                try container.encode(offsetFromEOF, forKey: .offset)
            case .sector(let sectorIndex, let byteOffset):
                try container.encode("sector", forKey: .type)
                try container.encode(sectorIndex, forKey: .sectorIndex)
                try container.encode(byteOffset, forKey: .byteOffset)
            case .tarOffset(let byteOffset):
                try container.encode("tarOffset", forKey: .type)
                try container.encode(byteOffset, forKey: .byteOffset)
            }
        }
    }

    public let anchor: Anchor
    public let bytes: [UInt8]
    public let description: String

    public var bytesHex: String {
        bytes.map { String(format: "%02X", $0) }.joined()
    }

    public init(
        anchor: Anchor,
        bytes: [UInt8],
        description: String
    ) {
        self.anchor = anchor
        self.bytes = bytes
        self.description = description
    }

    private enum CodingKeys: String, CodingKey {
        case anchorType
        case offset
        case bytesHex
        case description
        case anchor
        case bytes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.anchor) && container.contains(.bytes) {
            self.anchor = try container.decode(Anchor.self, forKey: .anchor)
            self.bytes = try container.decode([UInt8].self, forKey: .bytes)
            self.description = try container.decode(String.self, forKey: .description)
        } else {
            let anchorType = try container.decode(String.self, forKey: .anchorType)
            let offset = try container.decodeIfPresent(Int.self, forKey: .offset) ?? 0
            switch anchorType {
            case "head":
                self.anchor = .head(offset: offset)
            case "tail":
                self.anchor = .tail(offsetFromEOF: offset)
            case "sector":
                self.anchor = .sector(sectorIndex: offset / 2048, byteOffset: offset % 2048)
            case "tarOffset":
                self.anchor = .tarOffset(byteOffset: offset)
            default:
                self.anchor = .head(offset: offset)
            }
            let hex = try container.decode(String.self, forKey: .bytesHex)
            var byteArray: [UInt8] = []
            var index = hex.startIndex
            while index < hex.endIndex {
                let nextIndex = hex.index(index, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
                if let byte = UInt8(hex[index..<nextIndex], radix: 16) {
                    byteArray.append(byte)
                }
                index = nextIndex
            }
            self.bytes = byteArray
            self.description = try container.decode(String.self, forKey: .description)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch anchor {
        case .head(let offset):
            try container.encode("head", forKey: .anchorType)
            try container.encode(offset, forKey: .offset)
        case .tail(let offsetFromEOF):
            try container.encode("tail", forKey: .anchorType)
            try container.encode(offsetFromEOF, forKey: .offset)
        case .sector(let sectorIndex, let byteOffset):
            try container.encode("sector", forKey: .anchorType)
            try container.encode(sectorIndex * 2048 + byteOffset, forKey: .offset)
        case .tarOffset(let byteOffset):
            try container.encode("tarOffset", forKey: .anchorType)
            try container.encode(byteOffset, forKey: .offset)
        }
        try container.encode(bytesHex, forKey: .bytesHex)
        try container.encode(description, forKey: .description)
    }
}

/// Specification of an archive encryption standard.
public struct EncryptionStandardSpec: Sendable, Equatable, Codable {
    public let standardName: String
    public let keyDerivationFunction: String
    public let cipher: String
    public let authenticationTag: String?

    public init(
        standardName: String,
        keyDerivationFunction: String,
        cipher: String,
        authenticationTag: String? = nil
    ) {
        self.standardName = standardName
        self.keyDerivationFunction = keyDerivationFunction
        self.cipher = cipher
        self.authenticationTag = authenticationTag
    }
}

/// Standard definition of a ZIP Extra Field header tag.
public struct ZipExtraFieldStandardSpec: Sendable, Equatable, Codable {
    public let headerID: UInt16
    public let name: String
    public let sourceSpecification: String

    public init(
        headerID: UInt16,
        name: String,
        sourceSpecification: String
    ) {
        self.headerID = headerID
        self.name = name
        self.sourceSpecification = sourceSpecification
    }
}
