// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

extension ArchiveFormatStandardRegistry {

    func registerStreamSpecs() {
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
    }
}
