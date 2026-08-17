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

/// Authoritative registry mapping all supported formats to official standards specifications.
public final class ArchiveFormatStandardRegistry: @unchecked Sendable {
    public static let shared = ArchiveFormatStandardRegistry()

    private let lock = NSLock()
    private var specsByFormat: [ArchiveCompressionFormat: ArchiveFormatStandardSpec] = [:]
    private var specsById: [String: ArchiveFormatStandardSpec] = [:]

    public init() {
        registerBuiltinSpecs()
    }

    /// Retrieve format standard specification by typed enum format.
    public func spec(for format: ArchiveCompressionFormat) -> ArchiveFormatStandardSpec? {
        lock.lock()
        defer { lock.unlock() }
        return specsByFormat[format]
    }

    /// Retrieve format standard specification by identifier string (e.g. "zip", "7z", "tar.zst").
    public func spec(forId id: String) -> ArchiveFormatStandardSpec? {
        lock.lock()
        defer { lock.unlock() }
        return specsById[id.lowercased()]
    }

    /// Retrieve all registered format specifications.
    public func allSpecs() -> [ArchiveFormatStandardSpec] {
        lock.lock()
        defer { lock.unlock() }
        return Array(specsByFormat.values)
    }

    /// Register or overwrite a specification.
    public func register(spec: ArchiveFormatStandardSpec) {
        lock.lock()
        defer { lock.unlock() }
        specsByFormat[spec.format] = spec
        specsById[spec.id.lowercased()] = spec
    }

    // MARK: - Built-in Standards Registration

    private func registerBuiltinSpecs() {
        // 1. ZIP
        register(spec: ArchiveFormatStandardSpec(
            id: "zip",
            format: .zip,
            officialName: "PKWARE ZIP File Format Specification",
            standardCitations: [
                StandardCitation(
                    organization: "PKWARE",
                    standardNumber: "APPNOTE.TXT v6.3.10",
                    title: ".ZIP File Format Specification",
                    canonicalURL: "https://pkwaredownloads.blob.core.windows.net/pkware-general/appnote_6.3.10.txt"
                ),
                StandardCitation(
                    organization: "ISO/IEC",
                    standardNumber: "ISO/IEC 21320-1:2015",
                    title: "Information technology — Document Container File — Part 1: Core",
                    canonicalURL: "https://www.iso.org/standard/60101.html"
                ),
                StandardCitation(
                    organization: "IETF",
                    standardNumber: "RFC 1951",
                    title: "DEFLATE Compressed Data Format Specification version 1.3",
                    canonicalURL: "https://www.ietf.org/rfc/rfc1951.txt"
                )
            ],
            mimeType: "application/zip",
            appleUTI: "public.zip-archive",
            magicSignatures: [
                ArchiveMagicSignature(
                    anchor: .head(offset: 0),
                    bytes: [0x50, 0x4B, 0x03, 0x04],
                    description: "PK\\x03\\x04 Local File Header Signature"
                ),
                ArchiveMagicSignature(
                    anchor: .head(offset: 0),
                    bytes: [0x50, 0x4B, 0x05, 0x06],
                    description: "PK\\x05\\x06 Empty Archive EOCD Signature"
                ),
                ArchiveMagicSignature(
                    anchor: .head(offset: 0),
                    bytes: [0x50, 0x4B, 0x07, 0x08],
                    description: "PK\\x07\\x08 Spanned Archive Data Descriptor Signature"
                ),
                ArchiveMagicSignature(
                    anchor: .tail(offsetFromEOF: 22),
                    bytes: [0x50, 0x4B, 0x05, 0x06],
                    description: "PK\\x05\\x06 End of Central Directory Record"
                )
            ],
            supportedEncryption: [
                EncryptionStandardSpec(
                    standardName: "WinZip AES-256 (AE-2)",
                    keyDerivationFunction: "PBKDF2-HMAC-SHA1 (1000 iterations)",
                    cipher: "AES-256-CTR",
                    authenticationTag: "HMAC-SHA1 (10-byte truncation)"
                ),
                EncryptionStandardSpec(
                    standardName: "PKWARE Traditional ZipCrypto",
                    keyDerivationFunction: "CRC32-Linear-Feedback",
                    cipher: "ZipCrypto Stream Cipher",
                    authenticationTag: nil
                )
            ],
            supportsMultiVolume: true,
            supportedExtraFields: [
                ZipExtraFieldStandardSpec(headerID: 0x0001, name: "Zip64 Extended Information", sourceSpecification: "PKWARE Zip64"),
                ZipExtraFieldStandardSpec(headerID: 0x5455, name: "Extended Timestamp", sourceSpecification: "Info-ZIP"),
                ZipExtraFieldStandardSpec(headerID: 0x7075, name: "Unicode Path Extra Field", sourceSpecification: "Info-ZIP"),
                ZipExtraFieldStandardSpec(headerID: 0x7875, name: "Info-ZIP UNIX Extra Field (UID/GID)", sourceSpecification: "Info-ZIP"),
                ZipExtraFieldStandardSpec(headerID: 0x9901, name: "WinZip AES Extra Field", sourceSpecification: "WinZip")
            ]
        ))

        // 2. 7Z
        register(spec: ArchiveFormatStandardSpec(
            id: "7z",
            format: .sevenZip,
            officialName: "7-Zip 7z Archive Format Specification",
            standardCitations: [
                StandardCitation(
                    organization: "Igor Pavlov / 7-Zip",
                    standardNumber: "7z Format Specification 24.08",
                    title: "7z Archive Format Architecture and Structure",
                    canonicalURL: "https://www.7-zip.org/7z.html"
                ),
                StandardCitation(
                    organization: "LZMA SDK",
                    standardNumber: "LZMA SDK 24.08",
                    title: "Lempel-Ziv-Markov chain Algorithm SDK",
                    canonicalURL: "https://www.7-zip.org/sdk.html"
                )
            ],
            mimeType: "application/x-7z-compressed",
            appleUTI: "org.7-zip.7-zip-archive",
            magicSignatures: [
                ArchiveMagicSignature(
                    anchor: .head(offset: 0),
                    bytes: [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C],
                    description: "7z Header Signature (0x377ABCAF271C)"
                )
            ],
            supportedEncryption: [
                EncryptionStandardSpec(
                    standardName: "7z AES-256-CBC with SHA-256 Key Derivation",
                    keyDerivationFunction: "SHA-256 (2^19 cycles)",
                    cipher: "AES-256-CBC",
                    authenticationTag: "CRC32 / SHA-256"
                )
            ],
            supportsMultiVolume: true
        ))

        // 3. TAR
        register(spec: ArchiveFormatStandardSpec(
            id: "tar",
            format: .tar,
            officialName: "POSIX.1-2001 / IEEE Std 1003.1 ustar/pax Format",
            standardCitations: [
                StandardCitation(
                    organization: "IEEE / The Open Group",
                    standardNumber: "POSIX.1-2017 / IEEE Std 1003.1-2017",
                    title: "Standard for Information Technology—Portable Operating System Interface (POSIX(R)) Base Specifications, Issue 7 (pax/ustar)",
                    canonicalURL: "https://pubs.opengroup.org/onlinepubs/9699919799/utilities/pax.html"
                ),
                StandardCitation(
                    organization: "GNU",
                    standardNumber: "GNU tar 1.35 Format",
                    title: "GNU Tar Archive Header Format Specification",
                    canonicalURL: "https://www.gnu.org/software/tar/manual/html_node/Standard.html"
                )
            ],
            mimeType: "application/x-tar",
            appleUTI: "public.tar-archive",
            magicSignatures: [
                ArchiveMagicSignature(
                    anchor: .tarOffset(byteOffset: 257),
                    bytes: [0x75, 0x73, 0x74, 0x61, 0x72, 0x00],
                    description: "ustar\\0 POSIX.1-1988 Magic"
                ),
                ArchiveMagicSignature(
                    anchor: .tarOffset(byteOffset: 257),
                    bytes: [0x75, 0x73, 0x74, 0x61, 0x72, 0x20, 0x20, 0x00],
                    description: "ustar  \\0 GNU Tar Magic"
                )
            ],
            supportsMultiVolume: false
        ))

        // 4. TAR.GZ
        register(spec: ArchiveFormatStandardSpec(
            id: "tar.gz",
            format: .tarGz,
            officialName: "Gzip-compressed POSIX Tarball (.tar.gz / .tgz)",
            standardCitations: [
                StandardCitation(
                    organization: "IETF",
                    standardNumber: "RFC 1952",
                    title: "GZIP file format specification version 4.3",
                    canonicalURL: "https://www.ietf.org/rfc/rfc1952.txt"
                ),
                StandardCitation(
                    organization: "IEEE / The Open Group",
                    standardNumber: "POSIX.1-2017",
                    title: "Standard for Information Technology—POSIX Base Specifications, Issue 7 (pax/ustar)",
                    canonicalURL: "https://pubs.opengroup.org/onlinepubs/9699919799/utilities/pax.html"
                )
            ],
            mimeType: "application/gzip",
            appleUTI: "org.gnu.gnu-zip-tar-archive",
            magicSignatures: [
                ArchiveMagicSignature(
                    anchor: .head(offset: 0),
                    bytes: [0x1F, 0x8B],
                    description: "Gzip ID1/ID2 Header Magic (0x1F8B)"
                )
            ]
        ))

        // 5. TAR.BZ2
        register(spec: ArchiveFormatStandardSpec(
            id: "tar.bz2",
            format: .tarBz2,
            officialName: "Bzip2-compressed POSIX Tarball (.tar.bz2 / .tbz2)",
            standardCitations: [
                StandardCitation(
                    organization: "Julian Seward",
                    standardNumber: "bzip2 1.0.8",
                    title: "bzip2 and libbzip2 format specification",
                    canonicalURL: "https://sourceware.org/bzip2/"
                ),
                StandardCitation(
                    organization: "IEEE / The Open Group",
                    standardNumber: "POSIX.1-2017",
                    title: "Standard for Information Technology—POSIX Base Specifications, Issue 7 (pax/ustar)",
                    canonicalURL: "https://pubs.opengroup.org/onlinepubs/9699919799/utilities/pax.html"
                )
            ],
            mimeType: "application/x-bzip2",
            appleUTI: "org.bzip.bzip2-tar-archive",
            magicSignatures: [
                ArchiveMagicSignature(
                    anchor: .head(offset: 0),
                    bytes: [0x42, 0x5A, 0x68],
                    description: "BZh bzip2 Header Magic"
                )
            ]
        ))

        // 6. TAR.XZ
        register(spec: ArchiveFormatStandardSpec(
            id: "tar.xz",
            format: .tarXz,
            officialName: "XZ-compressed POSIX Tarball (.tar.xz / .txz)",
            standardCitations: [
                StandardCitation(
                    organization: "Tukaani Project",
                    standardNumber: "XZ File Format Specification 1.2.0",
                    title: "The .xz File Format",
                    canonicalURL: "https://tukaani.org/xz/xz-file-format.txt"
                ),
                StandardCitation(
                    organization: "IEEE / The Open Group",
                    standardNumber: "POSIX.1-2017",
                    title: "Standard for Information Technology—POSIX Base Specifications, Issue 7 (pax/ustar)",
                    canonicalURL: "https://pubs.opengroup.org/onlinepubs/9699919799/utilities/pax.html"
                )
            ],
            mimeType: "application/x-xz",
            appleUTI: "org.tukaani.tar-xz-archive",
            magicSignatures: [
                ArchiveMagicSignature(
                    anchor: .head(offset: 0),
                    bytes: [0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00],
                    description: "\\xFD7zXZ\\x00 Stream Header Magic"
                ),
                ArchiveMagicSignature(
                    anchor: .tail(offsetFromEOF: 2),
                    bytes: [0x59, 0x5A],
                    description: "YZ Stream Footer Magic"
                )
            ]
        ))

        // 7. TAR.ZST
        register(spec: ArchiveFormatStandardSpec(
            id: "tar.zst",
            format: .tarZst,
            officialName: "Zstandard-compressed POSIX Tarball (.tar.zst / .tzst)",
            standardCitations: [
                StandardCitation(
                    organization: "IETF",
                    standardNumber: "RFC 8878",
                    title: "Zstandard Compression and The 'application/zstd' Media Type",
                    canonicalURL: "https://www.ietf.org/rfc/rfc8878.txt"
                ),
                StandardCitation(
                    organization: "IEEE / The Open Group",
                    standardNumber: "POSIX.1-2017",
                    title: "Standard for Information Technology—POSIX Base Specifications, Issue 7 (pax/ustar)",
                    canonicalURL: "https://pubs.opengroup.org/onlinepubs/9699919799/utilities/pax.html"
                )
            ],
            mimeType: "application/zstd",
            appleUTI: "org.zstd.tar-zstandard-archive",
            magicSignatures: [
                ArchiveMagicSignature(
                    anchor: .head(offset: 0),
                    bytes: [0x28, 0xB5, 0x2F, 0xFD],
                    description: "Zstandard Frame Magic Number (0xFD2FB528 LE)"
                )
            ]
        ))

        // 8. GZ
        register(spec: ArchiveFormatStandardSpec(
            id: "gz",
            format: .gz,
            officialName: "GZIP Stream Compression Format",
            standardCitations: [
                StandardCitation(
                    organization: "IETF",
                    standardNumber: "RFC 1952",
                    title: "GZIP file format specification version 4.3",
                    canonicalURL: "https://www.ietf.org/rfc/rfc1952.txt"
                )
            ],
            mimeType: "application/gzip",
            appleUTI: "org.gnu.gnu-zip-archive",
            magicSignatures: [
                ArchiveMagicSignature(
                    anchor: .head(offset: 0),
                    bytes: [0x1F, 0x8B],
                    description: "Gzip ID1/ID2 Header Magic (0x1F8B)"
                )
            ]
        ))

        // 9. BZ2
        register(spec: ArchiveFormatStandardSpec(
            id: "bz2",
            format: .bz2,
            officialName: "Bzip2 Stream Compression Format",
            standardCitations: [
                StandardCitation(
                    organization: "Julian Seward",
                    standardNumber: "bzip2 1.0.8",
                    title: "bzip2 and libbzip2 format specification",
                    canonicalURL: "https://sourceware.org/bzip2/"
                )
            ],
            mimeType: "application/x-bzip2",
            appleUTI: "public.bzip2-archive",
            magicSignatures: [
                ArchiveMagicSignature(
                    anchor: .head(offset: 0),
                    bytes: [0x42, 0x5A, 0x68],
                    description: "BZh bzip2 Header Magic"
                )
            ]
        ))

        // 10. XZ
        register(spec: ArchiveFormatStandardSpec(
            id: "xz",
            format: .xz,
            officialName: "XZ Stream Compression Format",
            standardCitations: [
                StandardCitation(
                    organization: "Tukaani Project",
                    standardNumber: "XZ File Format Specification 1.2.0",
                    title: "The .xz File Format",
                    canonicalURL: "https://tukaani.org/xz/xz-file-format.txt"
                )
            ],
            mimeType: "application/x-xz",
            appleUTI: "org.tukaani.xz-archive",
            magicSignatures: [
                ArchiveMagicSignature(
                    anchor: .head(offset: 0),
                    bytes: [0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00],
                    description: "\\xFD7zXZ\\x00 Stream Header Magic"
                ),
                ArchiveMagicSignature(
                    anchor: .tail(offsetFromEOF: 2),
                    bytes: [0x59, 0x5A],
                    description: "YZ Stream Footer Magic"
                )
            ]
        ))

        // 11. ZST
        register(spec: ArchiveFormatStandardSpec(
            id: "zst",
            format: .zst,
            officialName: "Zstandard Stream Compression Format",
            standardCitations: [
                StandardCitation(
                    organization: "IETF",
                    standardNumber: "RFC 8878",
                    title: "Zstandard Compression and The 'application/zstd' Media Type",
                    canonicalURL: "https://www.ietf.org/rfc/rfc8878.txt"
                )
            ],
            mimeType: "application/zstd",
            appleUTI: "public.zstd-archive",
            magicSignatures: [
                ArchiveMagicSignature(
                    anchor: .head(offset: 0),
                    bytes: [0x28, 0xB5, 0x2F, 0xFD],
                    description: "Zstandard Frame Magic Number (0xFD2FB528 LE)"
                )
            ]
        ))

        // 12. LZIP
        register(spec: ArchiveFormatStandardSpec(
            id: "lzip",
            format: .lzip,
            officialName: "Lzip Stream Compression Format",
            standardCitations: [
                StandardCitation(
                    organization: "Antonio Diaz Diaz / GNU",
                    standardNumber: "Lzip Manual v1.24",
                    title: "Lzip Compression Format Specification",
                    canonicalURL: "https://www.nongnu.org/lzip/manual/lzip_manual.html"
                )
            ],
            mimeType: "application/x-lzip",
            appleUTI: "org.nongnu.lzip-archive",
            magicSignatures: [
                ArchiveMagicSignature(
                    anchor: .head(offset: 0),
                    bytes: [0x4C, 0x5A, 0x49, 0x50],
                    description: "LZIP Header Magic (LZIP)"
                )
            ]
        ))

        // 13. LZ4
        register(spec: ArchiveFormatStandardSpec(
            id: "lz4",
            format: .lz4,
            officialName: "LZ4 Frame Compression Format",
            standardCitations: [
                StandardCitation(
                    organization: "Yann Collet / LZ4",
                    standardNumber: "LZ4 Frame Format v1.6.1",
                    title: "LZ4 Framing Format Specification",
                    canonicalURL: "https://github.com/lz4/lz4/blob/dev/doc/lz4_Frame_format.md"
                )
            ],
            mimeType: "application/x-lz4",
            appleUTI: "org.lz4.lz4-archive",
            magicSignatures: [
                ArchiveMagicSignature(
                    anchor: .head(offset: 0),
                    bytes: [0x04, 0x22, 0x4D, 0x18],
                    description: "LZ4 Frame Magic Number (0x184D2204 LE)"
                ),
                ArchiveMagicSignature(
                    anchor: .head(offset: 0),
                    bytes: [0x02, 0x21, 0x4C, 0x18],
                    description: "LZ4 Legacy Frame Magic (0x184C2102 LE)"
                )
            ]
        ))

        // 14. BROTLI
        register(spec: ArchiveFormatStandardSpec(
            id: "brotli",
            format: .brotli,
            officialName: "Brotli Compressed Data Format",
            standardCitations: [
                StandardCitation(
                    organization: "IETF",
                    standardNumber: "RFC 7932",
                    title: "Brotli Compressed Data Format",
                    canonicalURL: "https://www.ietf.org/rfc/rfc7932.txt"
                )
            ],
            mimeType: "application/x-brotli",
            appleUTI: "org.brotli.brotli-archive",
            magicSignatures: []
        ))

        // 15. LRZIP
        register(spec: ArchiveFormatStandardSpec(
            id: "lrzip",
            format: .lrzip,
            officialName: "Long Range ZIP / LZMA Compression Format",
            standardCitations: [
                StandardCitation(
                    organization: "Con Kolivas",
                    standardNumber: "lrzip 0.651",
                    title: "Long Range ZIP (lrzip) Archive Format Specification",
                    canonicalURL: "https://github.com/ckolivas/lrzip"
                )
            ],
            mimeType: "application/x-lrzip",
            appleUTI: "org.lrzip.lrzip-archive",
            magicSignatures: [
                ArchiveMagicSignature(
                    anchor: .head(offset: 0),
                    bytes: [0x4C, 0x52, 0x5A, 0x49],
                    description: "LRZI Header Magic (LRZI)"
                )
            ],
            supportedEncryption: [
                EncryptionStandardSpec(
                    standardName: "LRZIP AES-128/256 CBC",
                    keyDerivationFunction: "SHA-512 Hash Stretching",
                    cipher: "AES-128/256-CBC",
                    authenticationTag: "MD5 / SHA-512"
                )
            ]
        ))

        // 16. AAR (Apple Archive)
        register(spec: ArchiveFormatStandardSpec(
            id: "aar",
            format: .aar,
            officialName: "Apple Archive Format (AEA / AAF)",
            standardCitations: [
                StandardCitation(
                    organization: "Apple Inc.",
                    standardNumber: "Apple Archive Specification (macOS 11+)",
                    title: "Apple Archive and Encrypted Archive (AEA) Reference",
                    canonicalURL: "https://developer.apple.com/documentation/applearchive"
                )
            ],
            mimeType: "application/x-apple-archive",
            appleUTI: "com.apple.archive",
            magicSignatures: [
                ArchiveMagicSignature(
                    anchor: .head(offset: 0),
                    bytes: [0x41, 0x41, 0x30, 0x31],
                    description: "AA01 Apple Archive Field Header"
                ),
                ArchiveMagicSignature(
                    anchor: .head(offset: 0),
                    bytes: [0x41, 0x45, 0x41, 0x31],
                    description: "AEA1 Apple Encrypted Archive Header"
                )
            ],
            supportedEncryption: [
                EncryptionStandardSpec(
                    standardName: "Apple Encrypted Archive (AEA1)",
                    keyDerivationFunction: "HKDF-SHA256 / Secure Enclave",
                    cipher: "AES-256-GCM / ChaCha20-Poly1305",
                    authenticationTag: "AEAD 16-byte Tag"
                )
            ]
        ))

        // 17. SNAPPY
        register(spec: ArchiveFormatStandardSpec(
            id: "snappy",
            format: .snappy,
            officialName: "Snappy Framing Format",
            standardCitations: [
                StandardCitation(
                    organization: "Google Inc.",
                    standardNumber: "Snappy Framing Format v1.1.10",
                    title: "Snappy Framing Format Description",
                    canonicalURL: "https://github.com/google/snappy/blob/main/framing_format.txt"
                )
            ],
            mimeType: "application/x-snappy-framed",
            appleUTI: "org.google.snappy-archive",
            magicSignatures: [
                ArchiveMagicSignature(
                    anchor: .head(offset: 0),
                    bytes: [0xFF, 0x06, 0x00, 0x00, 0x73, 0x4E, 0x61, 0x50, 0x70, 0x59],
                    description: "\\xFF\\x06\\x00\\x00sNaPpY Snappy Stream Identifier"
                )
            ]
        ))

        // 18. WIM
        register(spec: ArchiveFormatStandardSpec(
            id: "wim",
            format: .wim,
            officialName: "Microsoft Windows Imaging Format (WIM)",
            standardCitations: [
                StandardCitation(
                    organization: "Microsoft Corporation",
                    standardNumber: "MS-WIM Specification v3.0",
                    title: "Windows Imaging (WIM) File Format",
                    canonicalURL: "https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/wim-overview"
                )
            ],
            mimeType: "application/x-ms-wim",
            appleUTI: "com.microsoft.wim-archive",
            magicSignatures: [
                ArchiveMagicSignature(
                    anchor: .head(offset: 0),
                    bytes: [0x4D, 0x53, 0x57, 0x49, 0x4D, 0x00, 0x00, 0x00],
                    description: "MSWIM\\0\\0\\0 Header Magic"
                )
            ],
            supportsMultiVolume: true
        ))

        // 19. DMG
        register(spec: ArchiveFormatStandardSpec(
            id: "dmg",
            format: .dmg,
            officialName: "Apple Universal Disk Image Format (UDIF)",
            standardCitations: [
                StandardCitation(
                    organization: "Apple Inc.",
                    standardNumber: "UDIF / koly Trailer Specification",
                    title: "Apple Universal Disk Image Format Specification",
                    canonicalURL: "https://developer.apple.com/documentation/applearchive"
                )
            ],
            mimeType: "application/x-apple-diskimage",
            appleUTI: "com.apple.disk-image-udif",
            magicSignatures: [
                ArchiveMagicSignature(
                    anchor: .tail(offsetFromEOF: 512),
                    bytes: [0x6B, 0x6F, 0x6C, 0x79],
                    description: "koly UDIF Trailer Magic"
                )
            ],
            supportedEncryption: [
                EncryptionStandardSpec(
                    standardName: "Apple Encrypted DMG (V1/V2 CEnc)",
                    keyDerivationFunction: "PBKDF2-HMAC-SHA1",
                    cipher: "AES-128-CBC / AES-256-CBC",
                    authenticationTag: nil
                )
            ]
        ))

        // 20. ISO
        register(spec: ArchiveFormatStandardSpec(
            id: "iso",
            format: .iso,
            officialName: "ISO 9660 / ECMA-119 / UDF Optical Disc Image",
            standardCitations: [
                StandardCitation(
                    organization: "ISO/IEC",
                    standardNumber: "ISO 9660:1988 / ECMA-119",
                    title: "Information processing — Volume and file structure of CD-ROM for information interchange",
                    canonicalURL: "https://www.iso.org/standard/17505.html"
                ),
                StandardCitation(
                    organization: "OSTA",
                    standardNumber: "UDF 2.60",
                    title: "Universal Disk Format Specification",
                    canonicalURL: "http://www.osta.org/specs/"
                )
            ],
            mimeType: "application/x-iso9660-image",
            appleUTI: "public.iso-image",
            magicSignatures: [
                ArchiveMagicSignature(
                    anchor: .sector(sectorIndex: 16, byteOffset: 1),
                    bytes: [0x43, 0x44, 0x30, 0x30, 0x31],
                    description: "CD001 Primary Volume Descriptor Magic (Sector 16, Offset 1)"
                ),
                ArchiveMagicSignature(
                    anchor: .sector(sectorIndex: 16, byteOffset: 1),
                    bytes: [0x42, 0x45, 0x41, 0x30, 0x31],
                    description: "BEA01 Beginning Extended Area Descriptor (Sector 16, Offset 1)"
                )
            ]
        ))
    }
}
