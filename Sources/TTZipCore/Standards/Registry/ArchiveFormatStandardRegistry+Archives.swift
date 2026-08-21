// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

extension ArchiveFormatStandardRegistry {

    func registerArchiveSpecs() {
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
    }
}
