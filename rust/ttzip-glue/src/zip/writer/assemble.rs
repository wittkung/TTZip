// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! ZIP archive binary serialization and layout assembly (LFH, CDFH, Zip64, EOCD).

use super::types::{unix_to_dos_time, ZipCompressedItem};
use crate::types::TTZipStatus;
use crate::zip::extra::ZipExtraFields;
use crate::zip::parser::{
    MAGIC_CDFH, MAGIC_EOCD, MAGIC_LFH, MAGIC_ZIP64_EOCD, MAGIC_ZIP64_LOCATOR,
};

/// Assembles compressed items into final ZIP archive binary bytes.
pub fn assemble_zip_archive(items: &[ZipCompressedItem]) -> Result<Vec<u8>, TTZipStatus> {
    let mut out = Vec::new();
    let mut lfh_offsets = Vec::with_capacity(items.len());

    // 1. Write Local File Headers + Payloads
    for item in items {
        let lfh_offset = out.len() as u64;
        lfh_offsets.push(lfh_offset);

        let (dos_time, dos_date) = unix_to_dos_time(item.mtime_epoch_secs);
        let name_bytes = item.rel_path.as_bytes();

        let use_zip64 = item.uncompressed_size >= 0xFFFFFFFF
            || item.compressed_size >= 0xFFFFFFFF
            || lfh_offset >= 0xFFFFFFFF;

        let mut extra_bytes = Vec::new();
        if use_zip64 {
            let z64 = ZipExtraFields::build_zip64_extra(
                Some(item.uncompressed_size),
                Some(item.compressed_size),
                None,
            );
            extra_bytes.extend_from_slice(&z64);
        }
        if item.is_encrypted && item.compression_method == 99 {
            let aes_extra = ZipExtraFields::build_winzip_aes_extra(item.actual_method);
            extra_bytes.extend_from_slice(&aes_extra);
        }
        let ts_extra = ZipExtraFields::build_extended_timestamp(item.mtime_epoch_secs);
        extra_bytes.extend_from_slice(&ts_extra);

        let version_needed = if use_zip64 {
            45u16
        } else if item.is_encrypted {
            51u16
        } else if item.compression_method == 8 {
            20u16
        } else {
            10u16
        };

        let flag = if item.is_encrypted {
            0x0801u16 // bit 0 = encrypted, bit 11 = UTF-8
        } else {
            0x0800u16 // bit 11 = UTF-8
        };

        let uncomp_size_field = if item.uncompressed_size >= 0xFFFFFFFF {
            0xFFFFFFFFu32
        } else {
            item.uncompressed_size as u32
        };
        let comp_size_field = if item.compressed_size >= 0xFFFFFFFF {
            0xFFFFFFFFu32
        } else {
            item.compressed_size as u32
        };

        // LFH Record
        out.extend_from_slice(&MAGIC_LFH.to_le_bytes());
        out.extend_from_slice(&version_needed.to_le_bytes());
        out.extend_from_slice(&flag.to_le_bytes());
        out.extend_from_slice(&item.compression_method.to_le_bytes());
        out.extend_from_slice(&dos_time.to_le_bytes());
        out.extend_from_slice(&dos_date.to_le_bytes());
        out.extend_from_slice(&item.crc32.to_le_bytes());
        out.extend_from_slice(&comp_size_field.to_le_bytes());
        out.extend_from_slice(&uncomp_size_field.to_le_bytes());
        out.extend_from_slice(&(name_bytes.len() as u16).to_le_bytes());
        out.extend_from_slice(&(extra_bytes.len() as u16).to_le_bytes());
        out.extend_from_slice(name_bytes);
        out.extend_from_slice(&extra_bytes);

        // Payload
        out.extend_from_slice(&item.payload);
    }

    // 2. Write Central Directory
    let cd_offset = out.len() as u64;

    for (i, item) in items.iter().enumerate() {
        let lfh_offset = lfh_offsets[i];
        let (dos_time, dos_date) = unix_to_dos_time(item.mtime_epoch_secs);
        let name_bytes = item.rel_path.as_bytes();

        let use_zip64 = item.uncompressed_size >= 0xFFFFFFFF
            || item.compressed_size >= 0xFFFFFFFF
            || lfh_offset >= 0xFFFFFFFF;

        let mut extra_bytes = Vec::new();
        if use_zip64 {
            let u_sz = if item.uncompressed_size >= 0xFFFFFFFF {
                Some(item.uncompressed_size)
            } else {
                None
            };
            let c_sz = if item.compressed_size >= 0xFFFFFFFF {
                Some(item.compressed_size)
            } else {
                None
            };
            let off = if lfh_offset >= 0xFFFFFFFF {
                Some(lfh_offset)
            } else {
                None
            };
            let z64 = ZipExtraFields::build_zip64_extra(u_sz, c_sz, off);
            extra_bytes.extend_from_slice(&z64);
        }
        if item.is_encrypted && item.compression_method == 99 {
            let aes_extra = ZipExtraFields::build_winzip_aes_extra(item.actual_method);
            extra_bytes.extend_from_slice(&aes_extra);
        }
        let ts_extra = ZipExtraFields::build_extended_timestamp(item.mtime_epoch_secs);
        extra_bytes.extend_from_slice(&ts_extra);

        let version_made_by = 0x031Eu16; // Unix / macOS
        let version_needed = if use_zip64 {
            45u16
        } else if item.is_encrypted {
            51u16
        } else if item.compression_method == 8 {
            20u16
        } else {
            10u16
        };

        let flag = if item.is_encrypted {
            0x0801u16
        } else {
            0x0800u16
        };

        let uncomp_size_field = if item.uncompressed_size >= 0xFFFFFFFF {
            0xFFFFFFFFu32
        } else {
            item.uncompressed_size as u32
        };
        let comp_size_field = if item.compressed_size >= 0xFFFFFFFF {
            0xFFFFFFFFu32
        } else {
            item.compressed_size as u32
        };
        let lfh_offset_field = if lfh_offset >= 0xFFFFFFFF {
            0xFFFFFFFFu32
        } else {
            lfh_offset as u32
        };

        let ext_attr = (item.mode << 16) | if item.is_directory { 0x10 } else { 0 };

        // CDFH Record
        out.extend_from_slice(&MAGIC_CDFH.to_le_bytes());
        out.extend_from_slice(&version_made_by.to_le_bytes());
        out.extend_from_slice(&version_needed.to_le_bytes());
        out.extend_from_slice(&flag.to_le_bytes());
        out.extend_from_slice(&item.compression_method.to_le_bytes());
        out.extend_from_slice(&dos_time.to_le_bytes());
        out.extend_from_slice(&dos_date.to_le_bytes());
        out.extend_from_slice(&item.crc32.to_le_bytes());
        out.extend_from_slice(&comp_size_field.to_le_bytes());
        out.extend_from_slice(&uncomp_size_field.to_le_bytes());
        out.extend_from_slice(&(name_bytes.len() as u16).to_le_bytes());
        out.extend_from_slice(&(extra_bytes.len() as u16).to_le_bytes());
        out.extend_from_slice(&0u16.to_le_bytes()); // comment length = 0
        out.extend_from_slice(&0u16.to_le_bytes()); // disk number = 0
        out.extend_from_slice(&0u16.to_le_bytes()); // internal attr = 0
        out.extend_from_slice(&ext_attr.to_le_bytes());
        out.extend_from_slice(&lfh_offset_field.to_le_bytes());
        out.extend_from_slice(name_bytes);
        out.extend_from_slice(&extra_bytes);
    }

    let cd_size = (out.len() as u64) - cd_offset;
    let num_entries = items.len() as u64;

    let is_zip64_required = num_entries >= 0xFFFF
        || cd_size >= 0xFFFFFFFF
        || cd_offset >= 0xFFFFFFFF;

    if is_zip64_required {
        // Zip64 EOCD Record
        let z64_eocd_pos = out.len() as u64;
        let z64_record_size = 44u64; // Size after this field

        out.extend_from_slice(&MAGIC_ZIP64_EOCD.to_le_bytes());
        out.extend_from_slice(&z64_record_size.to_le_bytes());
        out.extend_from_slice(&45u16.to_le_bytes()); // version made by
        out.extend_from_slice(&45u16.to_le_bytes()); // version needed
        out.extend_from_slice(&0u32.to_le_bytes()); // disk number
        out.extend_from_slice(&0u32.to_le_bytes()); // disk with CD
        out.extend_from_slice(&num_entries.to_le_bytes()); // total entries on disk
        out.extend_from_slice(&num_entries.to_le_bytes()); // total entries in CD
        out.extend_from_slice(&cd_size.to_le_bytes());
        out.extend_from_slice(&cd_offset.to_le_bytes());

        // Zip64 EOCD Locator
        out.extend_from_slice(&MAGIC_ZIP64_LOCATOR.to_le_bytes());
        out.extend_from_slice(&0u32.to_le_bytes()); // disk with zip64 EOCD
        out.extend_from_slice(&z64_eocd_pos.to_le_bytes()); // offset of zip64 EOCD
        out.extend_from_slice(&1u32.to_le_bytes()); // total disks
    }

    // Standard EOCD Record
    let entries_field = if num_entries >= 0xFFFF {
        0xFFFFu16
    } else {
        num_entries as u16
    };
    let cd_size_field = if cd_size >= 0xFFFFFFFF {
        0xFFFFFFFFu32
    } else {
        cd_size as u32
    };
    let cd_offset_field = if cd_offset >= 0xFFFFFFFF {
        0xFFFFFFFFu32
    } else {
        cd_offset as u32
    };

    out.extend_from_slice(&MAGIC_EOCD.to_le_bytes());
    out.extend_from_slice(&0u16.to_le_bytes()); // disk number
    out.extend_from_slice(&0u16.to_le_bytes()); // disk with CD
    out.extend_from_slice(&entries_field.to_le_bytes()); // entries on this disk
    out.extend_from_slice(&entries_field.to_le_bytes()); // total entries in CD
    out.extend_from_slice(&cd_size_field.to_le_bytes());
    out.extend_from_slice(&cd_offset_field.to_le_bytes());
    out.extend_from_slice(&0u16.to_le_bytes()); // comment length = 0

    Ok(out)
}
