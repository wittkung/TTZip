// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Format signature registry for 16 primary container and compression formats.

use super::anchors::Anchor;
use crate::types::TTZipArchiveFormat;

/// Supported archive and compression formats identified via magic signatures.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[repr(i32)]
pub enum DetectedFormat {
    Unknown = 0,
    Zip = 1,
    SevenZip = 2,
    Tar = 3,
    Gzip = 4,
    Bzip2 = 5,
    Xz = 6,
    Zstd = 7,
    Rar = 8,
    Cab = 9,
    Iso = 10,
    Dmg = 11,
    Xar = 12,
    Lzh = 13,
    Ar = 14,
    Lzfse = 15,
    Snappy = 16,
    Lz4 = 17,
}

impl DetectedFormat {
    /// Maps detected format to TTZip core archive format enum.
    pub fn to_ttzip_format(self) -> TTZipArchiveFormat {
        match self {
            DetectedFormat::Zip => TTZipArchiveFormat::Zip,
            DetectedFormat::SevenZip => TTZipArchiveFormat::SevenZip,
            DetectedFormat::Tar => TTZipArchiveFormat::Tar,
            DetectedFormat::Dmg => TTZipArchiveFormat::Dmg,
            DetectedFormat::Lzfse => TTZipArchiveFormat::Lzfse,
            DetectedFormat::Snappy => TTZipArchiveFormat::Snappy,
            _ => TTZipArchiveFormat::Unknown,
        }
    }

    /// Primary standard file extension for this format.
    pub fn primary_extension(self) -> &'static str {
        match self {
            DetectedFormat::Zip => "zip",
            DetectedFormat::SevenZip => "7z",
            DetectedFormat::Tar => "tar",
            DetectedFormat::Gzip => "gz",
            DetectedFormat::Bzip2 => "bz2",
            DetectedFormat::Xz => "xz",
            DetectedFormat::Zstd => "zst",
            DetectedFormat::Rar => "rar",
            DetectedFormat::Cab => "cab",
            DetectedFormat::Iso => "iso",
            DetectedFormat::Dmg => "dmg",
            DetectedFormat::Xar => "xar",
            DetectedFormat::Lzh => "lzh",
            DetectedFormat::Ar => "ar",
            DetectedFormat::Lzfse => "lzfse",
            DetectedFormat::Snappy => "sz",
            DetectedFormat::Lz4 => "lz4",
            DetectedFormat::Unknown => "bin",
        }
    }

    /// Primary MIME type identifier.
    pub fn mime_type(self) -> &'static str {
        match self {
            DetectedFormat::Zip => "application/zip",
            DetectedFormat::SevenZip => "application/x-7z-compressed",
            DetectedFormat::Tar => "application/x-tar",
            DetectedFormat::Gzip => "application/gzip",
            DetectedFormat::Bzip2 => "application/x-bzip2",
            DetectedFormat::Xz => "application/x-xz",
            DetectedFormat::Zstd => "application/zstd",
            DetectedFormat::Rar => "application/vnd.rar",
            DetectedFormat::Cab => "application/vnd.ms-cab-compressed",
            DetectedFormat::Iso => "application/x-iso9660-image",
            DetectedFormat::Dmg => "application/x-apple-diskimage",
            DetectedFormat::Xar => "application/x-xar",
            DetectedFormat::Lzh => "application/x-lzh-compressed",
            DetectedFormat::Ar => "application/x-archive",
            DetectedFormat::Lzfse => "application/x-lzfse",
            DetectedFormat::Snappy => "application/x-snappy-framed",
            DetectedFormat::Lz4 => "application/x-lz4",
            DetectedFormat::Unknown => "application/octet-stream",
        }
    }
}

/// Compound tar formats derived from outer compression and file extension.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum CompoundFormat {
    TarGz,
    TarBz2,
    TarXz,
    TarZstd,
    TarLz4,
}

impl CompoundFormat {
    /// Maps compound format to TTZip core archive format enum.
    pub fn to_ttzip_format(self) -> TTZipArchiveFormat {
        match self {
            CompoundFormat::TarGz => TTZipArchiveFormat::TarGz,
            CompoundFormat::TarBz2 => TTZipArchiveFormat::TarBz2,
            CompoundFormat::TarXz => TTZipArchiveFormat::TarXz,
            CompoundFormat::TarZstd => TTZipArchiveFormat::TarZstd,
            CompoundFormat::TarLz4 => TTZipArchiveFormat::Tar,
        }
    }

    /// Primary file extension for compound format.
    pub fn primary_extension(self) -> &'static str {
        match self {
            CompoundFormat::TarGz => "tar.gz",
            CompoundFormat::TarBz2 => "tar.bz2",
            CompoundFormat::TarXz => "tar.xz",
            CompoundFormat::TarZstd => "tar.zst",
            CompoundFormat::TarLz4 => "tar.lz4",
        }
    }
}

/// Magic signature entry in static lookup table.
#[derive(Debug, Clone, Copy)]
pub struct SignatureEntry {
    pub format: DetectedFormat,
    pub anchor: Anchor,
    pub magic: &'static [u8],
    pub min_total_size: usize,
    pub description: &'static str,
    pub priority: u32,
}

/// Static prioritized signature table covering 16 primary formats.
pub static PRIORITIZED_SIGNATURES: &[SignatureEntry] = &[
    // 1. 7-Zip Container (High priority, exact 6-byte match)
    SignatureEntry {
        format: DetectedFormat::SevenZip,
        anchor: Anchor::Head(0),
        magic: &[0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C],
        min_total_size: 6,
        description: "7-Zip Archive",
        priority: 100,
    },
    // 2. XZ Compression Container (6 bytes)
    SignatureEntry {
        format: DetectedFormat::Xz,
        anchor: Anchor::Head(0),
        magic: &[0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00],
        min_total_size: 6,
        description: "XZ Compressed Stream",
        priority: 95,
    },
    // 3. RAR5 Archive
    SignatureEntry {
        format: DetectedFormat::Rar,
        anchor: Anchor::Head(0),
        magic: &[0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x01, 0x00],
        min_total_size: 8,
        description: "RAR5 Archive",
        priority: 90,
    },
    // 4. RAR4 Archive
    SignatureEntry {
        format: DetectedFormat::Rar,
        anchor: Anchor::Head(0),
        magic: &[0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x00],
        min_total_size: 7,
        description: "RAR4 Archive",
        priority: 89,
    },
    // 5. Zstandard Compression Frame
    SignatureEntry {
        format: DetectedFormat::Zstd,
        anchor: Anchor::Head(0),
        magic: &[0x28, 0xB5, 0x2F, 0xFD],
        min_total_size: 4,
        description: "Zstandard Compressed Stream",
        priority: 85,
    },
    // 6. XAR Archive (e.g. macOS pkg)
    SignatureEntry {
        format: DetectedFormat::Xar,
        anchor: Anchor::Head(0),
        magic: &[0x78, 0x61, 0x72, 0x21], // "xar!"
        min_total_size: 4,
        description: "eXtensible ARchive (XAR)",
        priority: 80,
    },
    // 7. Microsoft CAB Container
    SignatureEntry {
        format: DetectedFormat::Cab,
        anchor: Anchor::Head(0),
        magic: &[0x4D, 0x53, 0x43, 0x46], // "MSCF"
        min_total_size: 4,
        description: "Microsoft Cabinet Archive",
        priority: 75,
    },
    // 8. Unix AR / Debian package
    SignatureEntry {
        format: DetectedFormat::Ar,
        anchor: Anchor::Head(0),
        magic: &[0x21, 0x3C, 0x61, 0x72, 0x63, 0x68, 0x3E, 0x0A], // "!<arch>\n"
        min_total_size: 8,
        description: "UNIX Archive / Debian Package",
        priority: 70,
    },
    // 9. Snappy Framed Stream
    SignatureEntry {
        format: DetectedFormat::Snappy,
        anchor: Anchor::Head(0),
        magic: &[0xFF, 0x06, 0x00, 0x00, 0x73, 0x4E, 0x61, 0x50, 0x70, 0x59], // "\xFF\x06\x00\x00sNaPpY"
        min_total_size: 10,
        description: "Snappy Framed Stream",
        priority: 65,
    },
    // 10. LZ4 Framed Stream
    SignatureEntry {
        format: DetectedFormat::Lz4,
        anchor: Anchor::Head(0),
        magic: &[0x04, 0x22, 0x4D, 0x18],
        min_total_size: 4,
        description: "LZ4 Framed Stream",
        priority: 60,
    },
    // 11. Apple LZFSE Stream
    SignatureEntry {
        format: DetectedFormat::Lzfse,
        anchor: Anchor::Head(0),
        magic: &[0x62, 0x76, 0x78, 0x2D], // "bvx-"
        min_total_size: 4,
        description: "Apple LZFSE Compressed Stream",
        priority: 55,
    },
    // 12. ZIP Container Local File Header
    SignatureEntry {
        format: DetectedFormat::Zip,
        anchor: Anchor::Head(0),
        magic: &[0x50, 0x4B, 0x03, 0x04], // "PK\x03\x04"
        min_total_size: 4,
        description: "ZIP Archive (Local File Header)",
        priority: 50,
    },
    // 13. ZIP Empty Archive (EOCD only)
    SignatureEntry {
        format: DetectedFormat::Zip,
        anchor: Anchor::Head(0),
        magic: &[0x50, 0x4B, 0x05, 0x06], // "PK\x05\x06"
        min_total_size: 4,
        description: "ZIP Empty Archive (EOCD)",
        priority: 49,
    },
    // 14. GZIP Container
    SignatureEntry {
        format: DetectedFormat::Gzip,
        anchor: Anchor::Head(0),
        magic: &[0x1F, 0x8B],
        min_total_size: 2,
        description: "GZIP Compressed Stream",
        priority: 45,
    },
    // 15. BZIP2 Container
    SignatureEntry {
        format: DetectedFormat::Bzip2,
        anchor: Anchor::Head(0),
        magic: &[0x42, 0x5A, 0x68], // "BZh"
        min_total_size: 3,
        description: "BZIP2 Compressed Stream",
        priority: 40,
    },
    // 16. POSIX.1 ustar TAR (ustar\0)
    SignatureEntry {
        format: DetectedFormat::Tar,
        anchor: Anchor::TarOffset(257),
        magic: &[0x75, 0x73, 0x74, 0x61, 0x72, 0x00], // "ustar\0"
        min_total_size: 512,
        description: "POSIX.1 ustar Archive",
        priority: 35,
    },
    // 17. GNU TAR (ustar  \0)
    SignatureEntry {
        format: DetectedFormat::Tar,
        anchor: Anchor::TarOffset(257),
        magic: &[0x75, 0x73, 0x74, 0x61, 0x72, 0x20, 0x20, 0x00], // "ustar  \0"
        min_total_size: 512,
        description: "GNU tar Archive",
        priority: 34,
    },
    // 18. ISO 9660 Volume Descriptor at Sector 16 (offset 32769 = 0x8001)
    SignatureEntry {
        format: DetectedFormat::Iso,
        anchor: Anchor::Head(0x8001),
        magic: &[0x43, 0x44, 0x30, 0x30, 0x31], // "CD001"
        min_total_size: 32768 + 2048,
        description: "ISO 9660 Disk Image",
        priority: 30,
    },
    // 19. Apple DMG UDIF koly trailer (Tail 512)
    SignatureEntry {
        format: DetectedFormat::Dmg,
        anchor: Anchor::Tail(512),
        magic: &[0x6B, 0x6F, 0x6C, 0x79], // "koly"
        min_total_size: 512,
        description: "Apple Disk Image (UDIF DMG)",
        priority: 25,
    },
    // 20. LHA / LZH Archive (-lh5-)
    SignatureEntry {
        format: DetectedFormat::Lzh,
        anchor: Anchor::Head(2),
        magic: &[0x2D, 0x6C, 0x68], // "-lh"
        min_total_size: 24,
        description: "LHA/LZH Archive",
        priority: 20,
    },
];
