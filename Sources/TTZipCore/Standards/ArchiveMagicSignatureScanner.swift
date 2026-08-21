// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

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
