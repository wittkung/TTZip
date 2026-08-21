// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! POSIX ustar and GNU TAR 512-byte header representation, dual-mode checksums,
//! octal and base-256 binary encoding and decoding.

use crate::types::TTZipStatus;

pub const TAR_BLOCK_SIZE: usize = 512;

pub const TYPE_REGULAR: u8 = b'0';
pub const TYPE_REGULAR_ALT: u8 = 0;
pub const TYPE_HARDLINK: u8 = b'1';
pub const TYPE_SYMLINK: u8 = b'2';
pub const TYPE_CHAR_SPECIAL: u8 = b'3';
pub const TYPE_BLOCK_SPECIAL: u8 = b'4';
pub const TYPE_DIRECTORY: u8 = b'5';
pub const TYPE_FIFO: u8 = b'6';
pub const TYPE_CONTIGUOUS: u8 = b'7';
pub const TYPE_PAX_EXT_HEADER: u8 = b'x';
pub const TYPE_PAX_GLOBAL_HEADER: u8 = b'g';
pub const TYPE_GNU_LONGNAME: u8 = b'L';
pub const TYPE_GNU_LONGLINK: u8 = b'K';
pub const TYPE_SOLARIS_EXT: u8 = b'X';

pub const MAGIC_USTAR: &[u8; 6] = b"ustar\0";
pub const MAGIC_GNU: &[u8; 6] = b"ustar ";
pub const VERSION_USTAR: &[u8; 2] = b"00";

/// Parsed TAR header record representation.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TarHeader {
    pub name: String,
    pub mode: u32,
    pub uid: u64,
    pub gid: u64,
    pub size: u64,
    pub mtime: i64,
    pub chksum: u32,
    pub typeflag: u8,
    pub linkname: String,
    pub magic: [u8; 6],
    pub version: [u8; 2],
    pub uname: String,
    pub gname: String,
    pub devmajor: u32,
    pub devminor: u32,
    pub prefix: String,
}

/// Dual-mode unsigned and signed octal checksum computation over 512-byte block.
///
/// Bytes 148..156 (checksum field) are treated as 8 ASCII space characters (0x20).
pub fn compute_tar_checksum(block: &[u8; TAR_BLOCK_SIZE]) -> (u32, i32) {
    let mut unsigned_sum: u32 = 0;
    let mut signed_sum: i32 = 0;

    for (i, &b) in block.iter().enumerate() {
        let val = if (148..156).contains(&i) {
            0x20u8
        } else {
            b
        };
        unsigned_sum += val as u32;
        signed_sum += (val as i8) as i32;
    }

    (unsigned_sum, signed_sum)
}

/// Verifies whether the 512-byte block contains a valid TAR header checksum.
pub fn verify_tar_checksum(block: &[u8; TAR_BLOCK_SIZE]) -> bool {
    let expected = match parse_octal(&block[148..156]) {
        Some(v) => v as u32,
        None => return false,
    };
    let (unsigned_sum, signed_sum) = compute_tar_checksum(block);
    expected == unsigned_sum || (expected as i32) == signed_sum
}

/// Checks if an entire 512-byte block consists solely of zeroes (End-of-Archive marker).
#[inline]
pub fn is_tar_zero_block(block: &[u8; TAR_BLOCK_SIZE]) -> bool {
    block.iter().all(|&b| b == 0)
}

/// Parses an ASCII octal field into a `u64`.
pub fn parse_octal(bytes: &[u8]) -> Option<u64> {
    let mut trimmed = bytes;
    while !trimmed.is_empty() && (trimmed[0] == b' ' || trimmed[0] == 0) {
        trimmed = &trimmed[1..];
    }
    while !trimmed.is_empty() && (trimmed[trimmed.len() - 1] == b' ' || trimmed[trimmed.len() - 1] == 0) {
        trimmed = &trimmed[..trimmed.len() - 1];
    }
    if trimmed.is_empty() {
        return Some(0);
    }

    let mut result: u64 = 0;
    for &b in trimmed {
        if !(b'0'..=b'7').contains(&b) {
            return None;
        }
        result = result.checked_mul(8)?.checked_add((b - b'0') as u64)?;
    }
    Some(result)
}

/// Parses numeric field with support for GNU base-256 binary encoding (for sizes >= 8GB).
pub fn parse_numeric(bytes: &[u8]) -> Option<u64> {
    if bytes.is_empty() {
        return Some(0);
    }

    // GNU base-256 extension: leading byte 0x80 indicates positive binary base-256
    if bytes[0] == 0x80 {
        let mut val: u64 = 0;
        for &b in &bytes[1..] {
            val = (val << 8) | (b as u64);
        }
        return Some(val);
    }

    parse_octal(bytes)
}

/// Formats a `u64` value into an octal ASCII byte slice with trailing null or space.
pub fn format_octal(val: u64, dest: &mut [u8]) {
    let len = dest.len();
    if len == 0 {
        return;
    }
    dest.fill(b'0');
    dest[len - 1] = 0; // standard null terminator

    let mut curr = val;
    let mut idx = len - 2;
    while idx < len {
        dest[idx] = b'0' + (curr % 8) as u8;
        curr /= 8;
        if curr == 0 || idx == 0 {
            break;
        }
        idx -= 1;
    }
}

/// Formats numeric value into octal, or GNU base-256 binary if it exceeds octal capacity.
pub fn format_numeric(val: u64, dest: &mut [u8]) {
    let len = dest.len();
    let max_octal = (1u64 << ((len - 1) * 3)) - 1;

    if val <= max_octal {
        format_octal(val, dest);
    } else {
        // Encode GNU base-256 binary format
        dest.fill(0);
        dest[0] = 0x80; // Positive binary marker
        let mut curr = val;
        for i in (1..len).rev() {
            dest[i] = (curr & 0xFF) as u8;
            curr >>= 8;
        }
    }
}

/// Trims null bytes and whitespace to extract a string slice.
pub fn parse_null_trimmed_str(bytes: &[u8]) -> &str {
    let end = bytes.iter().position(|&b| b == 0).unwrap_or(bytes.len());
    std::str::from_utf8(&bytes[..end]).unwrap_or("")
}

/// Parses a 512-byte raw TAR block into a `TarHeader`.
pub fn parse_tar_header_block(block: &[u8; TAR_BLOCK_SIZE]) -> Result<TarHeader, TTZipStatus> {
    if !verify_tar_checksum(block) {
        return Err(TTZipStatus::ErrCorruptHeader);
    }

    let name = parse_null_trimmed_str(&block[0..100]).to_string();
    let mode = parse_octal(&block[100..108]).unwrap_or(0o644) as u32;
    let uid = parse_numeric(&block[108..116]).unwrap_or(0);
    let gid = parse_numeric(&block[116..124]).unwrap_or(0);
    let size = parse_numeric(&block[124..136]).unwrap_or(0);
    let mtime = parse_numeric(&block[136..148]).unwrap_or(0) as i64;
    let chksum = parse_octal(&block[148..156]).unwrap_or(0) as u32;
    let typeflag = block[156];
    let linkname = parse_null_trimmed_str(&block[157..257]).to_string();

    let mut magic = [0u8; 6];
    magic.copy_from_slice(&block[257..263]);

    let mut version = [0u8; 2];
    version.copy_from_slice(&block[263..265]);

    let uname = parse_null_trimmed_str(&block[265..297]).to_string();
    let gname = parse_null_trimmed_str(&block[297..329]).to_string();
    let devmajor = parse_octal(&block[329..337]).unwrap_or(0) as u32;
    let devminor = parse_octal(&block[337..345]).unwrap_or(0) as u32;
    let prefix = parse_null_trimmed_str(&block[345..500]).to_string();

    Ok(TarHeader {
        name,
        mode,
        uid,
        gid,
        size,
        mtime,
        chksum,
        typeflag,
        linkname,
        magic,
        version,
        uname,
        gname,
        devmajor,
        devminor,
        prefix,
    })
}

/// Serializes a `TarHeader` into a 512-byte block with a valid checksum.
pub fn build_tar_header_block(header: &TarHeader) -> [u8; TAR_BLOCK_SIZE] {
    let mut block = [0u8; TAR_BLOCK_SIZE];

    let name_bytes = header.name.as_bytes();
    let name_len = name_bytes.len().min(100);
    block[0..name_len].copy_from_slice(&name_bytes[..name_len]);

    format_octal(header.mode as u64, &mut block[100..108]);
    format_numeric(header.uid, &mut block[108..116]);
    format_numeric(header.gid, &mut block[116..124]);
    format_numeric(header.size, &mut block[124..136]);
    format_numeric(header.mtime.max(0) as u64, &mut block[136..148]);

    block[156] = if header.typeflag == 0 { TYPE_REGULAR } else { header.typeflag };

    let link_bytes = header.linkname.as_bytes();
    let link_len = link_bytes.len().min(100);
    block[157..157 + link_len].copy_from_slice(&link_bytes[..link_len]);

    block[257..263].copy_from_slice(&header.magic);
    block[263..265].copy_from_slice(&header.version);

    let uname_bytes = header.uname.as_bytes();
    let uname_len = uname_bytes.len().min(32);
    block[265..265 + uname_len].copy_from_slice(&uname_bytes[..uname_len]);

    let gname_bytes = header.gname.as_bytes();
    let gname_len = gname_bytes.len().min(32);
    block[297..297 + gname_len].copy_from_slice(&gname_bytes[..gname_len]);

    if header.devmajor > 0 {
        format_octal(header.devmajor as u64, &mut block[329..337]);
    }
    if header.devminor > 0 {
        format_octal(header.devminor as u64, &mut block[337..345]);
    }

    let prefix_bytes = header.prefix.as_bytes();
    let prefix_len = prefix_bytes.len().min(155);
    block[345..345 + prefix_len].copy_from_slice(&prefix_bytes[..prefix_len]);

    // Compute checksum with spaces
    let (unsigned_chksum, _) = compute_tar_checksum(&block);
    let chk_str = format!("{:06o}\0 ", unsigned_chksum);
    block[148..156].copy_from_slice(chk_str.as_bytes());

    block
}
