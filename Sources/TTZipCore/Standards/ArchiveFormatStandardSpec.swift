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

// MARK: - Magic Signature Scanner

//
//


/// High-performance, zero-allocation multi-anchor magic signature scanner.
///
/// Dispatches primary format sniffing and SFX detection to high-performance Rust C-ABI
/// while providing zero-copy fallback inspection across registered specifications.
public enum ArchiveMagicSignatureScanner {

    /// Prioritized sequence of formats for signature scanning.
    public static let prioritizedFormats: [ArchiveCompressionFormat] = [
        .wim,       // 8 bytes (MSWIM\0\0\0)
        .snappy,    // 10 bytes (\xFF\x06\x00\x00sNaPpY)
        .sevenZip,  // 6 bytes (37 7A BC AF 27 1C)
        .xz,        // 6 bytes (\xFD7zXZ\x00) + 2 bytes footer (YZ)
        .iso,       // Sector 16, offset 1 (CD001 / BEA01)
        .dmg,       // Tail 512 (koly)
        .aar,       // 4 bytes (AA01 / AEA1)
        .lzip,      // 4 bytes (LZIP)
        .lrzip,     // 4 bytes (LRZI)
        .lz4,       // 4 bytes (0x184D2204 / 0x184C2102)
        .zst,       // 4 bytes (0xFD2FB528)
        .tar,       // Offset 257 (ustar\0 / ustar  \0)
        .zip,       // 4 bytes (PK\x03\x04 / PK\x05\x06 / PK\x07\x08 / EOCD)
        .bz2,       // 3 bytes (BZh)
        .gz         // 2 bytes (0x1F8B)
    ]

    // MARK: - Offset Calculation

    /// Resolves the absolute starting byte offset in the archive stream for a given anchor.
    @inline(__always)
    public static func targetOffset(for anchor: ArchiveMagicSignature.Anchor, fileSize: Int64) -> Int64 {
        switch anchor {
        case .head(let offset):
            return Int64(offset)
        case .tail(let offsetFromEOF):
            return fileSize - Int64(offsetFromEOF)
        case .sector(let sectorIndex, let byteOffset):
            return Int64(sectorIndex) * 2048 + Int64(byteOffset)
        case .tarOffset(let byteOffset):
            return Int64(byteOffset)
        }
    }

    // MARK: - Buffer Matching (Zero Heap Allocation)

    /// Verifies if a magic signature matches the contents of an in-memory raw buffer at its designated anchor.
    @inline(__always)
    public static func matchesSignature(
        _ signature: ArchiveMagicSignature,
        in buffer: UnsafeRawBufferPointer,
        fileSize: Int64
    ) -> Bool {
        let sigBytes = signature.bytes
        let sigLen = sigBytes.count
        guard sigLen > 0 else { return false }

        let offset = targetOffset(for: signature.anchor, fileSize: fileSize)
        guard offset >= 0 else { return false }

        let endOffset = offset + Int64(sigLen)
        guard endOffset <= fileSize, endOffset <= Int64(buffer.count) else { return false }
        guard let baseAddress = buffer.baseAddress else { return false }

        let targetPtr = baseAddress.advanced(by: Int(offset))
        return sigBytes.withUnsafeBufferPointer { sigBuf in
            guard let sigBase = sigBuf.baseAddress else { return false }
            return memcmp(targetPtr, sigBase, sigLen) == 0
        }
    }

    @inline(__always)
    public static func matchesSignature(
        _ signature: ArchiveMagicSignature,
        in buffer: UnsafeBufferPointer<UInt8>,
        fileSize: Int64
    ) -> Bool {
        return matchesSignature(signature, in: UnsafeRawBufferPointer(buffer), fileSize: fileSize)
    }

    @inline(__always)
    public static func matchesSignature(
        _ signature: ArchiveMagicSignature,
        in data: Data,
        fileSize: Int64? = nil
    ) -> Bool {
        let size = fileSize ?? Int64(data.count)
        return data.withUnsafeBytes { rawBuffer in
            matchesSignature(signature, in: rawBuffer, fileSize: size)
        }
    }

    // MARK: - FileHandle Matching

    public static func matchesSignature(
        _ signature: ArchiveMagicSignature,
        fileHandle: FileHandle,
        fileSize: Int64
    ) throws -> Bool {
        let sigBytes = signature.bytes
        let sigLen = sigBytes.count
        guard sigLen > 0 else { return false }

        let offset = targetOffset(for: signature.anchor, fileSize: fileSize)
        guard offset >= 0, offset + Int64(sigLen) <= fileSize else { return false }

        try fileHandle.seek(toOffset: UInt64(offset))
        guard let data = try fileHandle.read(upToCount: sigLen), data.count == sigLen else {
            return false
        }

        return data.withUnsafeBytes { dataBuf in
            guard let dataBase = dataBuf.baseAddress else { return false }
            return sigBytes.withUnsafeBufferPointer { sigBuf in
                guard let sigBase = sigBuf.baseAddress else { return false }
                return memcmp(dataBase, sigBase, sigLen) == 0
            }
        }
    }

    // MARK: - Format Detection (Buffer & Rust C-ABI Bridge)

    /// Detects the archive or compression format of an in-memory buffer by evaluating magic signatures.
    public static func detectFormat(
        buffer: UnsafeRawBufferPointer,
        fileSize: Int64
    ) -> ArchiveCompressionFormat? {
        guard !buffer.isEmpty, fileSize > 0, let base = buffer.baseAddress else { return nil }

        var rawFormat: Int32 = 0
        var isSfx: Bool = false
        var sfxOffset: Int = 0

        let status = ttzip_rust_detect_format_buffer(
            base.assumingMemoryBound(to: UInt8.self),
            buffer.count,
            nil,
            &rawFormat,
            &isSfx,
            &sfxOffset
        )

        if status == TTZIP_STATUS_OK, let format = mapDetectedFormat(rawFormat) {
            return format
        }

        // Secondary fallback for extended formats (.wim, .lzip, .lrzip, .aar)
        let registry = ArchiveFormatStandardRegistry.shared
        for format in prioritizedFormats {
            guard let spec = registry.spec(for: format) else { continue }
            for signature in spec.magicSignatures {
                if matchesSignature(signature, in: buffer, fileSize: fileSize) {
                    return format
                }
            }
        }
        for spec in registry.allSpecs() {
            if prioritizedFormats.contains(spec.format) { continue }
            for signature in spec.magicSignatures {
                if matchesSignature(signature, in: buffer, fileSize: fileSize) {
                    return spec.format
                }
            }
        }

        return nil
    }

    public static func detectFormat(data: Data, fileSize: Int64? = nil) -> ArchiveCompressionFormat? {
        let size = fileSize ?? Int64(data.count)
        return data.withUnsafeBytes { rawBuffer in
            detectFormat(buffer: rawBuffer, fileSize: size)
        }
    }

    // MARK: - Format Detection (File URL & Path)

    public static func detectFormat(fileURL: URL) throws -> ArchiveCompressionFormat? {
        let path = fileURL.path
        guard FileManager.default.fileExists(atPath: path) else { return nil }

        var rawFormat: Int32 = 0
        var isSfx: Bool = false
        var sfxOffset: Int = 0

        let status = path.withCString { cPath in
            ttzip_rust_detect_format_file(cPath, &rawFormat, &isSfx, &sfxOffset)
        }

        if status == TTZIP_STATUS_OK, let format = mapDetectedFormat(rawFormat) {
            return resolveCompoundFormat(detected: format, fileURL: fileURL)
        }

        // Fallback to FileHandle inspect or extension heuristic
        let fileHandle = try FileHandle(forReadingFrom: fileURL)
        defer { try? fileHandle.close() }

        let fileSize = Int64(try fileHandle.seekToEnd())
        if fileSize > 0 {
            let registry = ArchiveFormatStandardRegistry.shared
            for spec in registry.allSpecs() {
                for signature in spec.magicSignatures {
                    if try matchesSignature(signature, fileHandle: fileHandle, fileSize: fileSize) {
                        return resolveCompoundFormat(detected: spec.format, fileURL: fileURL)
                    }
                }
            }
        }

        return detectFormatFromExtension(fileURL: fileURL)
    }

    public static func detectFormat(path: String) throws -> ArchiveCompressionFormat? {
        return try detectFormat(fileURL: URL(fileURLWithPath: path))
    }

    // MARK: - Mapping & Compound Resolution Helpers

    @inline(__always)
    private static func mapDetectedFormat(_ code: Int32) -> ArchiveCompressionFormat? {
        switch code {
        case 1: return .zip
        case 2: return .sevenZip
        case 3: return .tar
        case 4: return .gz
        case 5: return .bz2
        case 6: return .xz
        case 7: return .zst
        case 10: return .iso
        case 11: return .dmg
        case 16: return .snappy
        case 17: return .lz4
        case 18: return .lzip
        case 19: return .lrzip
        case 20: return .brotli
        case 21: return .aar
        case 22: return .wim
        default: return nil
        }
    }

    private static func resolveCompoundFormat(
        detected: ArchiveCompressionFormat,
        fileURL: URL
    ) -> ArchiveCompressionFormat {
        let lower = fileURL.lastPathComponent.lowercased()
        switch detected {
        case .gz where lower.hasSuffix(".tar.gz") || lower.hasSuffix(".tgz"):
            return .tarGz
        case .bz2 where lower.hasSuffix(".tar.bz2") || lower.hasSuffix(".tbz2") || lower.hasSuffix(".tbz"):
            return .tarBz2
        case .xz where lower.hasSuffix(".tar.xz") || lower.hasSuffix(".txz"):
            return .tarXz
        case .zst where lower.hasSuffix(".tar.zst") || lower.hasSuffix(".tzst"):
            return .tarZst
        default:
            return detected
        }
    }

    private static func detectFormatFromExtension(fileURL: URL) -> ArchiveCompressionFormat? {
        let lower = fileURL.lastPathComponent.lowercased()
        if lower.hasSuffix(".tar.gz") || lower.hasSuffix(".tgz") { return .tarGz }
        if lower.hasSuffix(".tar.bz2") || lower.hasSuffix(".tbz2") || lower.hasSuffix(".tbz") { return .tarBz2 }
        if lower.hasSuffix(".tar.xz") || lower.hasSuffix(".txz") { return .tarXz }
        if lower.hasSuffix(".tar.zst") || lower.hasSuffix(".tzst") { return .tarZst }
        if lower.hasSuffix(".tar") { return .tar }
        if lower.hasSuffix(".zip") || lower.hasSuffix(".zipx") || lower.hasSuffix(".jar") || lower.hasSuffix(".apk") { return .zip }
        if lower.hasSuffix(".7z") || lower.hasSuffix(".cb7") { return .sevenZip }
        if lower.hasSuffix(".gz") { return .gz }
        if lower.hasSuffix(".bz2") { return .bz2 }
        if lower.hasSuffix(".xz") { return .xz }
        if lower.hasSuffix(".zst") { return .zst }
        if lower.hasSuffix(".lz") || lower.hasSuffix(".lzip") { return .lzip }
        if lower.hasSuffix(".lz4") { return .lz4 }
        if lower.hasSuffix(".br") || lower.hasSuffix(".brotli") { return .brotli }
        if lower.hasSuffix(".lrz") || lower.hasSuffix(".lrzip") { return .lrzip }
        if lower.hasSuffix(".aar") { return .aar }
        if lower.hasSuffix(".sz") || lower.hasSuffix(".snappy") { return .snappy }
        if lower.hasSuffix(".wim") { return .wim }
        if lower.hasSuffix(".dmg") { return .dmg }
        if lower.hasSuffix(".iso") { return .iso }
        return nil
    }
}
