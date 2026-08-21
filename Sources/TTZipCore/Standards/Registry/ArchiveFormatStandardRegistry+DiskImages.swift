// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

extension ArchiveFormatStandardRegistry {

    func registerDiskImageSpecs() {
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
