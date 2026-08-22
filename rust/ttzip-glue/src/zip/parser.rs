// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! ZIP Central Directory and Local Header Zero-Copy Parser.
//!
//! Handles standard ZIP, Zip64 large archives (>4GB / >65535 entries), and WinZip AES headers.

use crate::types::TTZipStatus;
use crate::zip::extra::ZipExtraFields;

pub const MAGIC_LFH: u32 = 0x04034B50;
pub const MAGIC_CDFH: u32 = 0x02014B50;
pub const MAGIC_EOCD: u32 = 0x06054B50;
pub const MAGIC_ZIP64_EOCD: u32 = 0x06064B50;
pub const MAGIC_ZIP64_LOCATOR: u32 = 0x07064B50;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EocdInfo {
    pub total_entries: u64,
    pub cd_size: u64,
    pub cd_offset: u64,
    pub is_zip64: bool,
    pub eocd_offset: u64,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ZipEntry {
    pub rel_path: String,
    pub uncompressed_size: u64,
    pub compressed_size: u64,
    pub crc32: u32,
    pub compression_method: u16,
    pub actual_method: u16,
    pub aes_strength: u8,
    pub lfh_offset: u64,
    pub mtime_epoch_secs: i64,
    pub mode: u32,
    pub is_directory: bool,
    pub is_encrypted: bool,
    pub flag: u16,
}

/// Finds End of Central Directory (EOCD) and optional Zip64 EOCD structures.
pub fn find_eocd(mapped: &[u8]) -> Result<EocdInfo, TTZipStatus> {
    let file_size = mapped.len();
    if file_size < 22 {
        return Err(TTZipStatus::ErrCorruptHeader);
    }

    let search_back = file_size.min(65557);
    let search_start = file_size - search_back;

    let mut eocd_pos = None;

    // Search backwards for MAGIC_EOCD
    let mut pos = file_size - 22;
    loop {
        if pos < search_start {
            break;
        }
        let sig = u32::from_le_bytes(mapped[pos..pos + 4].try_into().unwrap());
        if sig == MAGIC_EOCD {
            // Validate comment length matches remaining bytes
            let comment_len = u16::from_le_bytes(mapped[pos + 20..pos + 22].try_into().unwrap()) as usize;
            if pos + 22 + comment_len <= file_size {
                eocd_pos = Some(pos);
                break;
            }
        }
        if pos == 0 {
            break;
        }
        pos -= 1;
    }

    let p = eocd_pos.ok_or(TTZipStatus::ErrCorruptHeader)?;

    let entries16 = u16::from_le_bytes(mapped[p + 10..p + 12].try_into().unwrap()) as u64;
    let cd_size32 = u32::from_le_bytes(mapped[p + 12..p + 16].try_into().unwrap()) as u64;
    let cd_off32 = u32::from_le_bytes(mapped[p + 16..p + 20].try_into().unwrap()) as u64;

    let mut info = EocdInfo {
        total_entries: entries16,
        cd_size: cd_size32,
        cd_offset: cd_off32,
        is_zip64: false,
        eocd_offset: p as u64,
    };

    // Check for Zip64 EOCD Locator (20 bytes before standard EOCD)
    if p >= 20 {
        let locator_pos = p - 20;
        let locator_sig = u32::from_le_bytes(mapped[locator_pos..locator_pos + 4].try_into().unwrap());
        if locator_sig == MAGIC_ZIP64_LOCATOR {
            let z64_eocd_off = u64::from_le_bytes(mapped[locator_pos + 8..locator_pos + 16].try_into().unwrap()) as usize;
            if z64_eocd_off + 56 <= file_size {
                let z64_sig = u32::from_le_bytes(mapped[z64_eocd_off..z64_eocd_off + 4].try_into().unwrap());
                if z64_sig == MAGIC_ZIP64_EOCD {
                    info.is_zip64 = true;
                    info.total_entries = u64::from_le_bytes(mapped[z64_eocd_off + 32..z64_eocd_off + 40].try_into().unwrap());
                    info.cd_size = u64::from_le_bytes(mapped[z64_eocd_off + 40..z64_eocd_off + 48].try_into().unwrap());
                    info.cd_offset = u64::from_le_bytes(mapped[z64_eocd_off + 48..z64_eocd_off + 56].try_into().unwrap());
                }
            }
        }
    }

    Ok(info)
}

/// Converts DOS timestamp (time: u16, date: u16) to Unix epoch timestamp in seconds.
pub fn dos_to_unix_time(dos_time: u16, dos_date: u16) -> i64 {
    let sec = ((dos_time & 0x1F) * 2) as u32;
    let min = ((dos_time >> 5) & 0x3F) as u32;
    let hour = ((dos_time >> 11) & 0x1F) as u32;

    let day = (dos_date & 0x1F) as u32;
    let month = ((dos_date >> 5) & 0x0F) as u32;
    let year = (((dos_date >> 9) & 0x7F) + 1980) as i32;

    // Approximate days calculation for valid DOS dates
    let month_days = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    let is_leap = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);

    let mut days_since_1970 = 0i64;
    for y in 1970..year {
        let leap = (y % 4 == 0 && y % 100 != 0) || (y % 400 == 0);
        days_since_1970 += if leap { 366 } else { 365 };
    }

    for m in 1..month.clamp(1, 12) {
        days_since_1970 += month_days[m as usize] as i64;
        if m == 2 && is_leap {
            days_since_1970 += 1;
        }
    }

    days_since_1970 += (day.saturating_sub(1)) as i64;

    
    days_since_1970 * 86400 + (hour as i64 * 3600) + (min as i64 * 60) + sec as i64
}

/// Parses a single Central Directory File Header (CDFH) entry.
pub fn parse_cdfh_entry(mapped: &[u8], curr_pos: usize) -> Result<(ZipEntry, usize), TTZipStatus> {
    if curr_pos + 46 > mapped.len() {
        return Err(TTZipStatus::ErrCorruptHeader);
    }

    let sig = u32::from_le_bytes(mapped[curr_pos..curr_pos + 4].try_into().unwrap());
    if sig != MAGIC_CDFH {
        return Err(TTZipStatus::ErrCorruptHeader);
    }

    let flag = u16::from_le_bytes(mapped[curr_pos + 8..curr_pos + 10].try_into().unwrap());
    let method = u16::from_le_bytes(mapped[curr_pos + 10..curr_pos + 12].try_into().unwrap());
    let dos_time = u16::from_le_bytes(mapped[curr_pos + 12..curr_pos + 14].try_into().unwrap());
    let dos_date = u16::from_le_bytes(mapped[curr_pos + 14..curr_pos + 16].try_into().unwrap());
    let crc32 = u32::from_le_bytes(mapped[curr_pos + 16..curr_pos + 20].try_into().unwrap());
    let comp_size32 = u32::from_le_bytes(mapped[curr_pos + 20..curr_pos + 24].try_into().unwrap());
    let uncomp_size32 = u32::from_le_bytes(mapped[curr_pos + 24..curr_pos + 28].try_into().unwrap());
    let fn_len = u16::from_le_bytes(mapped[curr_pos + 28..curr_pos + 30].try_into().unwrap()) as usize;
    let extra_len = u16::from_le_bytes(mapped[curr_pos + 30..curr_pos + 32].try_into().unwrap()) as usize;
    let comment_len = u16::from_le_bytes(mapped[curr_pos + 32..curr_pos + 34].try_into().unwrap()) as usize;
    let ext_attr = u32::from_le_bytes(mapped[curr_pos + 38..curr_pos + 42].try_into().unwrap());
    let lfh_offset32 = u32::from_le_bytes(mapped[curr_pos + 42..curr_pos + 46].try_into().unwrap());

    let rec_len = 46 + fn_len + extra_len + comment_len;
    if curr_pos + rec_len > mapped.len() {
        return Err(TTZipStatus::ErrCorruptHeader);
    }

    let fn_start = curr_pos + 46;
    let fn_bytes = &mapped[fn_start..fn_start + fn_len];
    let mut filename = String::from_utf8_lossy(fn_bytes).to_string();
    filename = filename.replace('\\', "/");

    let extra_start = fn_start + fn_len;
    let extra_bytes = &mapped[extra_start..extra_start + extra_len];

    let extra = ZipExtraFields::parse(
        extra_bytes,
        true,
        uncomp_size32 == 0xFFFFFFFF,
        comp_size32 == 0xFFFFFFFF,
        lfh_offset32 == 0xFFFFFFFF,
    );

    if let Some(upath) = extra.unicode_path {
        filename = upath.replace('\\', "/");
    }

    let uncompressed_size = extra.uncompressed_size.unwrap_or(uncomp_size32 as u64);
    let compressed_size = extra.compressed_size.unwrap_or(comp_size32 as u64);
    let lfh_offset = extra.local_header_offset.unwrap_or(lfh_offset32 as u64);

    let mut actual_method = method;
    let mut aes_strength = 0;
    if extra.has_winzip_aes {
        aes_strength = extra.aes_strength;
        actual_method = extra.aes_actual_method;
    }

    let is_encrypted = (flag & 0x0001) != 0;

    let mut is_directory = filename.ends_with('/');
    if !is_directory && ext_attr != 0 {
        let posix_mode = ext_attr >> 16;
        if (posix_mode & 0o170000) == 0o040000 || (ext_attr & 0x10) != 0 {
            is_directory = true;
        }
    }

    let mut mtime_epoch = dos_to_unix_time(dos_time, dos_date);
    if let Some(ext_mtime) = extra.mod_time {
        mtime_epoch = ext_mtime as i64;
    }

    let posix_mode = (ext_attr >> 16) & 0o7777;
    let mode = if posix_mode != 0 {
        posix_mode
    } else if is_directory {
        0o755
    } else {
        0o644
    };

    let entry = ZipEntry {
        rel_path: filename,
        uncompressed_size,
        compressed_size,
        crc32,
        compression_method: method,
        actual_method,
        aes_strength,
        lfh_offset,
        mtime_epoch_secs: mtime_epoch,
        mode,
        is_directory,
        is_encrypted,
        flag,
    };

    Ok((entry, curr_pos + rec_len))
}

/// Parses all Central Directory entries.
pub fn parse_all_entries(mapped: &[u8]) -> Result<Vec<ZipEntry>, TTZipStatus> {
    let eocd = find_eocd(mapped)?;
    let mut entries = Vec::with_capacity(eocd.total_entries.min(65536) as usize);

    let mut pos = eocd.cd_offset as usize;
    let cd_end = (eocd.cd_offset + eocd.cd_size) as usize;

    if cd_end > mapped.len() {
        return Err(TTZipStatus::ErrCorruptHeader);
    }

    while pos < cd_end {
        let (entry, next_pos) = parse_cdfh_entry(mapped, pos)?;
        entries.push(entry);
        pos = next_pos;
    }

    Ok(entries)
}

/// Parses Local File Header at `lfh_offset` and returns payload byte range `(payload_offset, header_size)`.
pub fn parse_local_file_header(mapped: &[u8], lfh_offset: usize) -> Result<(usize, usize), TTZipStatus> {
    if lfh_offset + 30 > mapped.len() {
        return Err(TTZipStatus::ErrCorruptHeader);
    }

    let sig = u32::from_le_bytes(mapped[lfh_offset..lfh_offset + 4].try_into().unwrap());
    if sig != MAGIC_LFH {
        return Err(TTZipStatus::ErrCorruptHeader);
    }

    let fn_len = u16::from_le_bytes(mapped[lfh_offset + 26..lfh_offset + 28].try_into().unwrap()) as usize;
    let extra_len = u16::from_le_bytes(mapped[lfh_offset + 28..lfh_offset + 30].try_into().unwrap()) as usize;

    let header_size = 30 + fn_len + extra_len;
    let payload_offset = lfh_offset + header_size;

    if payload_offset > mapped.len() {
        return Err(TTZipStatus::ErrCorruptHeader);
    }

    Ok((payload_offset, header_size))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_dos_to_unix_time() {
        // 2026-01-01 00:00:00
        let dos_date = ((2026 - 1980) << 9) | (1 << 5) | 1;
        let dos_time = 0;
        let unix = dos_to_unix_time(dos_time, dos_date as u16);
        assert!(unix > 1700000000);
    }
}
