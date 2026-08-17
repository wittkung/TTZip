import Foundation

/// High-performance, zero-allocation multi-anchor magic signature scanner.
///
/// Supports scanning byte sequences at `.head(offset)`, `.tail(offsetFromEOF)`,
/// `.sector(sectorIndex, byteOffset)` (e.g. ISO 9660 volume descriptors), and `.tarOffset(byteOffset)` (POSIX/GNU ustar).
public enum ArchiveMagicSignatureScanner {

    /// Prioritized sequence of formats for signature scanning.
    /// Formats with longer and more distinctive signatures are evaluated first.
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
    ///
    /// - Parameters:
    ///   - anchor: Signature position anchor (.head, .tail, .sector, .tarOffset).
    ///   - fileSize: Total size of the archive stream in bytes.
    /// - Returns: Absolute 0-indexed byte offset from the start of the file.
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
    ///
    /// - Parameters:
    ///   - signature: Magic signature descriptor with anchor and expected byte pattern.
    ///   - buffer: Raw byte buffer (typically mmap or contiguous memory).
    ///   - fileSize: Total file size corresponding to the underlying stream (used for `.tail` calculation).
    /// - Returns: `true` if all signature bytes match identically at the anchored offset; `false` otherwise.
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
        guard endOffset <= fileSize else { return false }
        guard endOffset <= Int64(buffer.count) else { return false }

        guard let baseAddress = buffer.baseAddress else { return false }
        let targetPtr = baseAddress.advanced(by: Int(offset))

        return sigBytes.withUnsafeBufferPointer { sigBuf in
            guard let sigBase = sigBuf.baseAddress else { return false }
            return memcmp(targetPtr, sigBase, sigLen) == 0
        }
    }

    /// Verifies if a magic signature matches within an `UnsafeBufferPointer<UInt8>`.
    @inline(__always)
    public static func matchesSignature(
        _ signature: ArchiveMagicSignature,
        in buffer: UnsafeBufferPointer<UInt8>,
        fileSize: Int64
    ) -> Bool {
        return matchesSignature(signature, in: UnsafeRawBufferPointer(buffer), fileSize: fileSize)
    }

    /// Verifies if a magic signature matches within a `Data` instance.
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

    /// Verifies if a magic signature matches the contents of a file stream via `FileHandle` seek and read.
    ///
    /// - Parameters:
    ///   - signature: Magic signature descriptor with anchor and expected byte pattern.
    ///   - fileHandle: Open `FileHandle` with read permissions.
    ///   - fileSize: Total file size in bytes.
    /// - Returns: `true` if signature matches; `false` otherwise.
    public static func matchesSignature(
        _ signature: ArchiveMagicSignature,
        fileHandle: FileHandle,
        fileSize: Int64
    ) throws -> Bool {
        let sigBytes = signature.bytes
        let sigLen = sigBytes.count
        guard sigLen > 0 else { return false }

        let offset = targetOffset(for: signature.anchor, fileSize: fileSize)
        guard offset >= 0 else { return false }

        let endOffset = offset + Int64(sigLen)
        guard endOffset <= fileSize else { return false }

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

    // MARK: - Format Detection (Buffer)

    /// Detects the archive or compression format of an in-memory buffer by evaluating magic signatures.
    ///
    /// - Parameters:
    ///   - buffer: Raw byte buffer.
    ///   - fileSize: Total file size in bytes.
    /// - Returns: Matched `ArchiveCompressionFormat`, or `nil` if unrecognized.
    public static func detectFormat(
        buffer: UnsafeRawBufferPointer,
        fileSize: Int64
    ) -> ArchiveCompressionFormat? {
        guard !buffer.isEmpty, fileSize > 0 else { return nil }

        let registry = ArchiveFormatStandardRegistry.shared

        // 1. Evaluate prioritized formats against registered magic signatures
        for format in prioritizedFormats {
            guard let spec = registry.spec(for: format) else { continue }
            for signature in spec.magicSignatures {
                if matchesSignature(signature, in: buffer, fileSize: fileSize) {
                    return format
                }
            }
        }

        // 2. Evaluate any remaining registered specifications
        for spec in registry.allSpecs() {
            if prioritizedFormats.contains(spec.format) { continue }
            for signature in spec.magicSignatures {
                if matchesSignature(signature, in: buffer, fileSize: fileSize) {
                    return spec.format
                }
            }
        }

        // 3. Self-Extracting (.exe / SFX) Zip and 7z fallback scanning
        if buffer.count >= 16, let base = buffer.baseAddress {
            let byte0 = base.load(fromByteOffset: 0, as: UInt8.self)
            let byte1 = base.load(fromByteOffset: 1, as: UInt8.self)
            if byte0 == 0x4D && byte1 == 0x5A { // MZ header
                let limit = min(buffer.count, 65536) - 6
                if limit > 0 {
                    for i in 0..<limit {
                        let b0 = base.load(fromByteOffset: i, as: UInt8.self)
                        let b1 = base.load(fromByteOffset: i + 1, as: UInt8.self)
                        let b2 = base.load(fromByteOffset: i + 2, as: UInt8.self)
                        let b3 = base.load(fromByteOffset: i + 3, as: UInt8.self)
                        if b0 == 0x50 && b1 == 0x4B && b2 == 0x03 && b3 == 0x04 {
                            return .zip
                        }
                        if b0 == 0x37 && b1 == 0x7A && b2 == 0xBC && b3 == 0xAF {
                            let b4 = base.load(fromByteOffset: i + 4, as: UInt8.self)
                            let b5 = base.load(fromByteOffset: i + 5, as: UInt8.self)
                            if b4 == 0x27 && b5 == 0x1C {
                                return .sevenZip
                            }
                        }
                    }
                }
            }
        }

        return nil
    }

    /// Detects the format of a `Data` instance.
    public static func detectFormat(data: Data, fileSize: Int64? = nil) -> ArchiveCompressionFormat? {
        let size = fileSize ?? Int64(data.count)
        return data.withUnsafeBytes { rawBuffer in
            detectFormat(buffer: rawBuffer, fileSize: size)
        }
    }

    // MARK: - Format Detection (File URL)

    /// Detects the archive or compression format of a file at the given URL using multi-anchor magic scanning.
    ///
    /// - Parameter fileURL: Target file URL.
    /// - Returns: Matched `ArchiveCompressionFormat`, or `nil` if unrecognized.
    public static func detectFormat(fileURL: URL) throws -> ArchiveCompressionFormat? {
        let path = fileURL.path
        guard FileManager.default.fileExists(atPath: path) else { return nil }

        let fileHandle = try FileHandle(forReadingFrom: fileURL)
        defer { try? fileHandle.close() }

        let fileSize = Int64(try fileHandle.seekToEnd())
        guard fileSize > 0 else { return nil }

        let registry = ArchiveFormatStandardRegistry.shared

        // 1. Evaluate prioritized formats via FileHandle seeking
        for format in prioritizedFormats {
            guard let spec = registry.spec(for: format) else { continue }
            for signature in spec.magicSignatures {
                if try matchesSignature(signature, fileHandle: fileHandle, fileSize: fileSize) {
                    return resolveCompoundFormat(detected: format, fileURL: fileURL)
                }
            }
        }

        // 2. Evaluate remaining registered specs
        for spec in registry.allSpecs() {
            if prioritizedFormats.contains(spec.format) { continue }
            for signature in spec.magicSignatures {
                if try matchesSignature(signature, fileHandle: fileHandle, fileSize: fileSize) {
                    return resolveCompoundFormat(detected: spec.format, fileURL: fileURL)
                }
            }
        }

        // 3. Fallback to extension for formats without standard magic (e.g. Brotli)
        if let extFormat = detectFormatFromExtension(fileURL: fileURL) {
            return extFormat
        }

        return nil
    }

    /// Detects format from a file path string.
    public static func detectFormat(path: String) throws -> ArchiveCompressionFormat? {
        return try detectFormat(fileURL: URL(fileURLWithPath: path))
    }

    // MARK: - Private Helpers

    /// Resolves single-stream compression formats (.gz, .bz2, .xz, .zst) to compound tarball formats (.tar.gz, .tar.bz2, etc.) when the filename indicates a tar archive.
    private static func resolveCompoundFormat(
        detected: ArchiveCompressionFormat,
        fileURL: URL
    ) -> ArchiveCompressionFormat {
        let lower = fileURL.lastPathComponent.lowercased()
        switch detected {
        case .gz:
            if lower.hasSuffix(".tar.gz") || lower.hasSuffix(".tgz") { return .tarGz }
            return .gz
        case .bz2:
            if lower.hasSuffix(".tar.bz2") || lower.hasSuffix(".tbz2") || lower.hasSuffix(".tbz") { return .tarBz2 }
            return .bz2
        case .xz:
            if lower.hasSuffix(".tar.xz") || lower.hasSuffix(".txz") { return .tarXz }
            return .xz
        case .zst:
            if lower.hasSuffix(".tar.zst") || lower.hasSuffix(".tzst") { return .tarZst }
            return .zst
        default:
            return detected
        }
    }

    /// Extension-based format heuristic for formats lacking fixed magic bytes (RFC 7932 Brotli).
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
