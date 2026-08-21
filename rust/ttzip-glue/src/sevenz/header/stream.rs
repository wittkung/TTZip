// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! 7-Zip Header and EncodedHeader Zero-Copy Binary Metadata Stream Parser.

use super::models::{SevenZCoder, SevenZFileMeta, SevenZFolder, SevenZHeaderInfo};
use crate::sevenz::format::*;
use crate::types::TTZipStatus;

/// Helper function to parse 7z Header structures from a byte buffer.
pub fn parse_7z_header_stream(hp: &[u8], out_info: &mut SevenZHeaderInfo) -> Result<(), TTZipStatus> {
    let mut hpos = 0;
    let hlen = hp.len();

    while hpos < hlen {
        let tag = hp[hpos];
        hpos += 1;

        if tag == K_END || tag == K_HEADER || tag == K_MAIN_STREAMS_INFO {
            continue;
        }

        if tag == K_PACK_INFO {
            let (_, rd1) = read_varint(&hp[hpos..]).ok_or(TTZipStatus::ErrCorruptHeader)?;
            hpos += rd1;
            let (num_pack_streams, rd2) = read_varint(&hp[hpos..]).ok_or(TTZipStatus::ErrCorruptHeader)?;
            hpos += rd2;

            while hpos < hlen {
                let ptag = hp[hpos];
                hpos += 1;
                if ptag == K_END {
                    break;
                }
                if ptag == K_SIZE {
                    for _ in 0..num_pack_streams {
                        let (_, rd) = read_varint(&hp[hpos..]).ok_or(TTZipStatus::ErrCorruptHeader)?;
                        hpos += rd;
                    }
                } else if ptag == K_CRC {
                    let all_defined = hp[hpos];
                    hpos += 1;
                    if all_defined != 0 {
                        hpos += (num_pack_streams as usize) * 4;
                    }
                } else {
                    let (sz, rd) = read_varint(&hp[hpos..]).ok_or(TTZipStatus::ErrCorruptHeader)?;
                    hpos += rd + (sz as usize);
                }
            }
        } else if tag == K_UNPACK_INFO {
            while hpos < hlen {
                let utag = hp[hpos];
                hpos += 1;
                if utag == K_END {
                    break;
                }
                if utag == K_FOLDER {
                    let (num_folders, rd) = read_varint(&hp[hpos..]).ok_or(TTZipStatus::ErrCorruptHeader)?;
                    hpos += rd;
                    let external = hp[hpos];
                    hpos += 1;

                    if external == 0 {
                        for _ in 0..num_folders {
                            let mut folder = SevenZFolder::default();
                            let (num_coders, rd) = read_varint(&hp[hpos..]).ok_or(TTZipStatus::ErrCorruptHeader)?;
                            hpos += rd;

                            for _ in 0..num_coders {
                                let flags = hp[hpos];
                                hpos += 1;
                                let method_size = (flags & 0x0F) as usize;
                                let mut mid = 0u64;
                                for m in 0..method_size.min(8) {
                                    mid = (mid << 8) | (hp[hpos + m] as u64);
                                }
                                hpos += method_size;

                                if mid == METHOD_AES {
                                    out_info.is_encrypted = true;
                                } else {
                                    out_info.primary_method_id = mid;
                                }

                                let mut in_streams = 1u64;
                                let mut out_streams = 1u64;
                                if (flags & 0x10) != 0 {
                                    let (ins, rd) = read_varint(&hp[hpos..]).ok_or(TTZipStatus::ErrCorruptHeader)?;
                                    hpos += rd;
                                    let (outs, rd) = read_varint(&hp[hpos..]).ok_or(TTZipStatus::ErrCorruptHeader)?;
                                    hpos += rd;
                                    in_streams = ins;
                                    out_streams = outs;
                                }

                                let mut props = Vec::new();
                                if (flags & 0x20) != 0 {
                                    let (props_sz, rd) = read_varint(&hp[hpos..]).ok_or(TTZipStatus::ErrCorruptHeader)?;
                                    hpos += rd;
                                    let psz = props_sz as usize;
                                    if psz > 0 && hpos + psz <= hlen {
                                        props.extend_from_slice(&hp[hpos..hpos + psz]);

                                        if mid == METHOD_AES && psz >= 1 {
                                            let b0 = props[0];
                                            out_info.aes_num_cycles_power = (b0 & 0x3F) as u32;
                                            if (b0 & 0xC0) != 0 && psz >= 2 {
                                                let b1 = props[1];
                                                let mut p_off = 2;
                                                let s_len = (b1 & 0x0F) as usize;
                                                let iv_len_enc = ((b1 >> 4) & 0x0F) as usize;
                                                let iv_len = if iv_len_enc > 0 { iv_len_enc + 1 } else { 0 };

                                                if s_len > 0 && p_off + s_len <= psz {
                                                    let copy_len = s_len.min(16);
                                                    out_info.aes_salt[..copy_len].copy_from_slice(&props[p_off..p_off + copy_len]);
                                                    out_info.aes_salt_len = s_len;
                                                    p_off += s_len;
                                                }
                                                if iv_len > 0 && p_off + iv_len <= psz {
                                                    let copy_len = iv_len.min(16);
                                                    out_info.aes_iv[..copy_len].copy_from_slice(&props[p_off..p_off + copy_len]);
                                                    out_info.aes_iv_len = iv_len;
                                                }
                                            }
                                        } else if mid != METHOD_AES {
                                            out_info.coder_props = props.clone();
                                        }

                                        hpos += psz;
                                    }
                                }

                                folder.coders.push(SevenZCoder {
                                    method_id: mid,
                                    num_in_streams: in_streams,
                                    num_out_streams: out_streams,
                                    properties: props,
                                });
                            }

                            if num_coders > 1 {
                                let num_bind_pairs = (num_coders - 1) as usize;
                                for _ in 0..num_bind_pairs {
                                    let (_, rd1) = read_varint(&hp[hpos..]).ok_or(TTZipStatus::ErrCorruptHeader)?;
                                    hpos += rd1;
                                    let (_, rd2) = read_varint(&hp[hpos..]).ok_or(TTZipStatus::ErrCorruptHeader)?;
                                    hpos += rd2;
                                }
                                let num_packed_streams = (num_coders - (num_bind_pairs as u64)) as usize;
                                if num_packed_streams > 1 {
                                    for _ in 0..num_packed_streams {
                                        let (_, rd) = read_varint(&hp[hpos..]).ok_or(TTZipStatus::ErrCorruptHeader)?;
                                        hpos += rd;
                                    }
                                }
                            }

                            out_info.folders.push(folder);
                        }
                    }
                } else if utag == K_CODERS_UNPACK_SIZE {
                    let total_coders: usize = out_info.folders.iter().map(|f| f.coders.len()).sum();
                    let read_limit = total_coders.max(out_info.folders.len()).max(1);

                    for _ in 0..read_limit {
                        if hpos >= hlen {
                            break;
                        }
                        let (folder_unpack_sz, rd) = read_varint(&hp[hpos..]).ok_or(TTZipStatus::ErrCorruptHeader)?;
                        hpos += rd;
                        if let Some(folder) = out_info.folders.first_mut() {
                            folder.unpack_sizes.push(folder_unpack_sz);
                        }
                    }
                } else if utag == K_CRC {
                    let all_defined = hp[hpos];
                    hpos += 1;
                    if all_defined != 0 {
                        hpos += out_info.folders.len().max(1) * 4;
                    }
                } else {
                    let (sz, rd) = read_varint(&hp[hpos..]).ok_or(TTZipStatus::ErrCorruptHeader)?;
                    hpos += rd + (sz as usize);
                }
            }
        } else if tag == K_SUB_STREAMS_INFO {
            let mut num_streams_val = 1u64;
            while hpos < hlen {
                let stag = hp[hpos];
                hpos += 1;
                if stag == K_END {
                    break;
                }
                if stag == K_NUM_UNPACK_STREAM {
                    let (ns, rd) = read_varint(&hp[hpos..]).ok_or(TTZipStatus::ErrCorruptHeader)?;
                    hpos += rd;
                    num_streams_val = ns;
                } else if stag == K_SIZE {
                    let num_explicit = num_streams_val.saturating_sub(1) as usize;
                    for _ in 0..num_explicit {
                        let (sval, rd) = read_varint(&hp[hpos..]).ok_or(TTZipStatus::ErrCorruptHeader)?;
                        hpos += rd;
                        out_info.stream_sizes.push(sval);
                    }
                } else if stag == K_CRC {
                    let all_defined = hp[hpos];
                    hpos += 1;
                    if all_defined != 0 {
                        for _ in 0..num_streams_val as usize {
                            if hpos + 4 <= hlen {
                                let c = u32::from_le_bytes(hp[hpos..hpos + 4].try_into().unwrap());
                                hpos += 4;
                                out_info.stream_crcs.push(c);
                            }
                        }
                    }
                } else {
                    let (sz, rd) = read_varint(&hp[hpos..]).ok_or(TTZipStatus::ErrCorruptHeader)?;
                    hpos += rd + (sz as usize);
                }
            }
        } else if tag == K_FILES_INFO {
            let (num_files_val, rd) = read_varint(&hp[hpos..]).ok_or(TTZipStatus::ErrCorruptHeader)?;
            hpos += rd;
            let num_files = num_files_val as usize;
            out_info.files.resize(num_files, SevenZFileMeta::default());

            while hpos < hlen {
                let ftag = hp[hpos];
                hpos += 1;
                if ftag == K_END {
                    break;
                }

                let (prop_size_val, rd) = read_varint(&hp[hpos..]).ok_or(TTZipStatus::ErrCorruptHeader)?;
                hpos += rd;
                let prop_size = prop_size_val as usize;
                let prop_end = hpos + prop_size;

                if ftag == K_EMPTY_STREAM {
                    for i in 0..num_files {
                        let byte_idx = i / 8;
                        let bit_idx = 7 - (i % 8);
                        if byte_idx < prop_size {
                            let b = hp[hpos + byte_idx];
                            if ((b >> bit_idx) & 1) != 0 {
                                out_info.files[i].is_empty_stream = true;
                            }
                        }
                    }
                    hpos = prop_end;
                } else if ftag == K_NAME {
                    let _ext = hp[hpos];
                    hpos += 1;
                    let mut name_pos = hpos;
                    let mut name_bytes_left = prop_size.saturating_sub(1);

                    for f in 0..num_files {
                        let mut u16_chars = Vec::new();
                        while name_bytes_left >= 2 {
                            let ch = u16::from_le_bytes(hp[name_pos..name_pos + 2].try_into().unwrap());
                            name_pos += 2;
                            name_bytes_left -= 2;
                            if ch == 0 {
                                break;
                            }
                            u16_chars.push(ch);
                        }
                        let utf8_name = String::from_utf16_lossy(&u16_chars).replace('\\', "/");
                        out_info.files[f].rel_path = utf8_name;
                    }
                    hpos = prop_end;
                } else if ftag == K_WIN_ATTRIBUTES {
                    if hpos < prop_end {
                        let all_defined = hp[hpos];
                        hpos += 1;
                        if all_defined == 1 && hpos < prop_end {
                            let external = hp[hpos];
                            hpos += 1;
                            if external == 0 {
                                for f in 0..num_files {
                                    if hpos + 4 <= prop_end {
                                        let attr = u32::from_le_bytes(hp[hpos..hpos + 4].try_into().unwrap());
                                        hpos += 4;
                                        if (attr & 0x10) != 0 {
                                            out_info.files[f].is_directory = true;
                                        }
                                        out_info.files[f].mode = if out_info.files[f].is_directory {
                                            0o755
                                        } else {
                                            0o644
                                        };
                                    }
                                }
                            }
                        }
                    }
                    hpos = prop_end;
                } else {
                    hpos = prop_end;
                }
            }
        } else {
            let (sz, rd) = read_varint(&hp[hpos..]).ok_or(TTZipStatus::ErrCorruptHeader)?;
            hpos += rd + (sz as usize);
        }
    }

    // Reconcile stream sizes if folder unpack size is known and last stream size was implicit
    if !out_info.folders.is_empty() && !out_info.folders[0].unpack_sizes.is_empty() {
        let total_unpack = out_info.folders[0].unpack_sizes[0];
        let sum_known: u64 = out_info.stream_sizes.iter().sum();
        if total_unpack > sum_known {
            out_info.stream_sizes.push(total_unpack - sum_known);
        }
    } else if out_info.stream_sizes.is_empty() && !out_info.folders.is_empty() {
        for &sz in &out_info.folders[0].unpack_sizes {
            out_info.stream_sizes.push(sz);
        }
    }

    Ok(())
}
