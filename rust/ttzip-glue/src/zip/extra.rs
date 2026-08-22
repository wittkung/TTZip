// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! ZIP Extra Field parser and serializer.
//!
//! Handles Zip64 (`0x0001`), WinZip AES (`0x9901`), Extended Timestamp (`0x5455`),
//! Info-ZIP Unix (`0x7875`), and Unicode Path (`0x7075`).

use crate::crypto::crc32::crc32_fast;

pub const TAG_ZIP64: u16 = 0x0001;
pub const TAG_EXT_TIMESTAMP: u16 = 0x5455;
pub const TAG_INFOZIP_UNIX: u16 = 0x7875;
pub const TAG_UNICODE_PATH: u16 = 0x7075;
pub const TAG_WINZIP_AES: u16 = 0x9901;

/// Parsed Extra Fields metadata.
#[derive(Debug, Default, Clone, PartialEq, Eq)]
pub struct ZipExtraFields {
    // Zip64
    pub has_zip64: bool,
    pub uncompressed_size: Option<u64>,
    pub compressed_size: Option<u64>,
    pub local_header_offset: Option<u64>,
    pub disk_number: Option<u32>,

    // WinZip AES
    pub has_winzip_aes: bool,
    pub aes_version: u16,
    pub aes_vendor_id: u16,
    pub aes_strength: u8, // 1 = 128-bit, 2 = 192-bit, 3 = 256-bit
    pub aes_actual_method: u16,

    // Extended Timestamp
    pub has_extended_timestamp: bool,
    pub mod_time: Option<u32>,
    pub acc_time: Option<u32>,
    pub create_time: Option<u32>,

    // Info-ZIP Unix
    pub has_posix_permissions: bool,
    pub uid: Option<u32>,
    pub gid: Option<u32>,

    // Unicode Path
    pub unicode_path: Option<String>,
}

impl ZipExtraFields {
    /// Parses extra fields from a raw slice.
    pub fn parse(
        extra_data: &[u8],
        is_cdfh: bool,
        uncomp_size_placeholder: bool,
        comp_size_placeholder: bool,
        lfh_offset_placeholder: bool,
    ) -> Self {
        let mut fields = Self::default();
        if extra_data.len() < 4 {
            return fields;
        }

        let mut offset = 0;
        while offset + 4 <= extra_data.len() {
            let header_id = u16::from_le_bytes([extra_data[offset], extra_data[offset + 1]]);
            let data_size = u16::from_le_bytes([extra_data[offset + 2], extra_data[offset + 3]]) as usize;
            let payload_start = offset + 4;

            if payload_start + data_size > extra_data.len() {
                break; // Truncated field
            }

            let payload = &extra_data[payload_start..payload_start + data_size];

            match header_id {
                TAG_ZIP64 => {
                    fields.has_zip64 = true;
                    let mut cursor = 0;

                    if is_cdfh {
                        if uncomp_size_placeholder && cursor + 8 <= payload.len() {
                            fields.uncompressed_size = Some(u64::from_le_bytes(
                                payload[cursor..cursor + 8].try_into().unwrap(),
                            ));
                            cursor += 8;
                        }
                        if comp_size_placeholder && cursor + 8 <= payload.len() {
                            fields.compressed_size = Some(u64::from_le_bytes(
                                payload[cursor..cursor + 8].try_into().unwrap(),
                            ));
                            cursor += 8;
                        }
                        if lfh_offset_placeholder && cursor + 8 <= payload.len() {
                            fields.local_header_offset = Some(u64::from_le_bytes(
                                payload[cursor..cursor + 8].try_into().unwrap(),
                            ));
                            cursor += 8;
                        }
                        if cursor + 4 <= payload.len() {
                            fields.disk_number = Some(u32::from_le_bytes(
                                payload[cursor..cursor + 4].try_into().unwrap(),
                            ));
                        }
                    } else {
                        // In Local File Header, uncomp and comp sizes appear if present
                        if cursor + 8 <= payload.len() {
                            fields.uncompressed_size = Some(u64::from_le_bytes(
                                payload[cursor..cursor + 8].try_into().unwrap(),
                            ));
                            cursor += 8;
                        }
                        if cursor + 8 <= payload.len() {
                            fields.compressed_size = Some(u64::from_le_bytes(
                                payload[cursor..cursor + 8].try_into().unwrap(),
                            ));
                        }
                    }
                }

                TAG_WINZIP_AES => {
                    if payload.len() >= 7 {
                        fields.has_winzip_aes = true;
                        fields.aes_version = u16::from_le_bytes([payload[0], payload[1]]);
                        fields.aes_vendor_id = u16::from_le_bytes([payload[2], payload[3]]);
                        let mode = payload[4];
                        fields.aes_strength = if mode == 1 || mode == 2 || mode == 3 {
                            mode
                        } else {
                            0
                        };
                        fields.aes_actual_method = u16::from_le_bytes([payload[5], payload[6]]);
                    }
                }

                TAG_EXT_TIMESTAMP => {
                    if !payload.is_empty() {
                        fields.has_extended_timestamp = true;
                        let flags = payload[0];
                        let mut cursor = 1;
                        if (flags & 0x01) != 0 && cursor + 4 <= payload.len() {
                            fields.mod_time = Some(u32::from_le_bytes(
                                payload[cursor..cursor + 4].try_into().unwrap(),
                            ));
                            cursor += 4;
                        }
                        if (flags & 0x02) != 0 && cursor + 4 <= payload.len() {
                            fields.acc_time = Some(u32::from_le_bytes(
                                payload[cursor..cursor + 4].try_into().unwrap(),
                            ));
                            cursor += 4;
                        }
                        if (flags & 0x04) != 0 && cursor + 4 <= payload.len() {
                            fields.create_time = Some(u32::from_le_bytes(
                                payload[cursor..cursor + 4].try_into().unwrap(),
                            ));
                        }
                    }
                }

                TAG_INFOZIP_UNIX => {
                    if payload.len() >= 4 && payload[0] == 1 {
                        let uid_size = payload[1] as usize;
                        let mut cursor = 2;
                        if cursor + uid_size <= payload.len() {
                            if uid_size == 2 {
                                fields.uid = Some(u16::from_le_bytes([payload[cursor], payload[cursor + 1]]) as u32);
                            } else if uid_size == 4 {
                                fields.uid = Some(u32::from_le_bytes(
                                    payload[cursor..cursor + 4].try_into().unwrap(),
                                ));
                            }
                            cursor += uid_size;
                        }
                        if cursor < payload.len() {
                            let gid_size = payload[cursor] as usize;
                            cursor += 1;
                            if cursor + gid_size <= payload.len() {
                                if gid_size == 2 {
                                    fields.gid = Some(u16::from_le_bytes([payload[cursor], payload[cursor + 1]]) as u32);
                                } else if gid_size == 4 {
                                    fields.gid = Some(u32::from_le_bytes(
                                        payload[cursor..cursor + 4].try_into().unwrap(),
                                    ));
                                }
                            }
                        }
                        fields.has_posix_permissions = true;
                    }
                }

                TAG_UNICODE_PATH
                    if payload.len() >= 5 && payload[0] == 1 => {
                        let _expected_crc = u32::from_le_bytes(payload[1..5].try_into().unwrap());
                        if let Ok(s) = std::str::from_utf8(&payload[5..]) {
                            fields.unicode_path = Some(s.to_string());
                        }
                    }

                _ => {}
            }

            offset = payload_start + data_size;
        }

        fields
    }

    /// Serializes Zip64 extra field for Central Directory or Local File Header.
    pub fn build_zip64_extra(
        uncompressed_size: Option<u64>,
        compressed_size: Option<u64>,
        local_header_offset: Option<u64>,
    ) -> Vec<u8> {
        let mut payload = Vec::new();
        if let Some(u_sz) = uncompressed_size {
            payload.extend_from_slice(&u_sz.to_le_bytes());
        }
        if let Some(c_sz) = compressed_size {
            payload.extend_from_slice(&c_sz.to_le_bytes());
        }
        if let Some(offset) = local_header_offset {
            payload.extend_from_slice(&offset.to_le_bytes());
        }

        if payload.is_empty() {
            return Vec::new();
        }

        let mut out = Vec::with_capacity(4 + payload.len());
        out.extend_from_slice(&TAG_ZIP64.to_le_bytes());
        out.extend_from_slice(&(payload.len() as u16).to_le_bytes());
        out.extend_from_slice(&payload);
        out
    }

    /// Serializes WinZip AES extra field (0x9901).
    pub fn build_winzip_aes_extra(actual_method: u16) -> Vec<u8> {
        let mut out = Vec::with_capacity(11);
        out.extend_from_slice(&TAG_WINZIP_AES.to_le_bytes());
        out.extend_from_slice(&7u16.to_le_bytes()); // Data size = 7
        out.extend_from_slice(&0x0002u16.to_le_bytes()); // AE-2 vendor version
        out.extend_from_slice(&0x4541u16.to_le_bytes()); // "AE" vendor ID
        out.push(3); // 256-bit encryption strength (mode 3)
        out.extend_from_slice(&actual_method.to_le_bytes());
        out
    }

    /// Serializes Extended Timestamp extra field (0x5455).
    pub fn build_extended_timestamp(mtime_secs: u32) -> Vec<u8> {
        let mut out = Vec::with_capacity(9);
        out.extend_from_slice(&TAG_EXT_TIMESTAMP.to_le_bytes());
        out.extend_from_slice(&5u16.to_le_bytes()); // 1 flag byte + 4 mtime bytes
        out.push(1); // bit 0: mod_time present
        out.extend_from_slice(&mtime_secs.to_le_bytes());
        out
    }

    /// Serializes Unicode Path extra field (0x7075).
    pub fn build_unicode_path(standard_filename: &str) -> Vec<u8> {
        let name_bytes = standard_filename.as_bytes();
        let name_crc = crc32_fast(0, name_bytes);
        let data_size = 5 + name_bytes.len();

        let mut out = Vec::with_capacity(4 + data_size);
        out.extend_from_slice(&TAG_UNICODE_PATH.to_le_bytes());
        out.extend_from_slice(&(data_size as u16).to_le_bytes());
        out.push(1); // Version 1
        out.extend_from_slice(&name_crc.to_le_bytes());
        out.extend_from_slice(name_bytes);
        out
    }
}
