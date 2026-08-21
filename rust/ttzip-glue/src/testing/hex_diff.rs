// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! NEON/SSE2 16B vectorized fast hex diff comparison and ANSI formatting engine.

use libc::c_char;
use std::ffi::CString;
use std::panic::catch_unwind;

const HEX_CHARS: &[u8; 16] = b"0123456789ABCDEF";

/// Finds the byte offset of the first difference between two slices using SIMD vectorization.
#[inline]
pub fn find_first_difference(expected: &[u8], actual: &[u8]) -> Option<usize> {
    let min_len = expected.len().min(actual.len());
    if min_len == 0 {
        if expected.len() == actual.len() {
            return None;
        } else {
            return Some(0);
        }
    }

    let mut offset = 0;

    #[cfg(target_arch = "aarch64")]
    {
        use std::arch::aarch64::*;
        while offset + 16 <= min_len {
            unsafe {
                let va = vld1q_u8(expected.as_ptr().add(offset));
                let vb = vld1q_u8(actual.as_ptr().add(offset));
                let eq = vceqq_u8(va, vb);
                let min_val = vminvq_u8(eq);
                if min_val != 0xFF {
                    // Mismatch within this 16-byte block
                    for i in 0..16 {
                        if expected[offset + i] != actual[offset + i] {
                            return Some(offset + i);
                        }
                    }
                }
            }
            offset += 16;
        }
    }

    #[cfg(target_arch = "x86_64")]
    {
        use std::arch::x86_64::*;
        while offset + 16 <= min_len {
            unsafe {
                let va = _mm_loadu_si128(expected.as_ptr().add(offset) as *const __m128i);
                let vb = _mm_loadu_si128(actual.as_ptr().add(offset) as *const __m128i);
                let eq = _mm_cmpeq_epi8(va, vb);
                let mask = _mm_movemask_epi8(eq);
                if mask != 0xFFFF {
                    let trailing = (!mask as u16).trailing_zeros() as usize;
                    return Some(offset + trailing);
                }
            }
            offset += 16;
        }
    }

    // 8-byte chunk loop
    while offset + 8 <= min_len {
        let a = u64::from_ne_bytes(expected[offset..offset + 8].try_into().unwrap());
        let b = u64::from_ne_bytes(actual[offset..offset + 8].try_into().unwrap());
        if a != b {
            for i in 0..8 {
                if expected[offset + i] != actual[offset + i] {
                    return Some(offset + i);
                }
            }
        }
        offset += 8;
    }

    // Scalar tail
    while offset < min_len {
        if expected[offset] != actual[offset] {
            return Some(offset);
        }
        offset += 1;
    }

    if expected.len() != actual.len() {
        Some(min_len)
    } else {
        None
    }
}

/// Generates a 16-byte aligned binary hex diff window around the first divergence.
pub fn generate_hex_diff(
    expected: &[u8],
    actual: &[u8],
    max_window: usize,
    use_ansi: bool,
) -> Option<String> {
    let mismatch_offset = find_first_difference(expected, actual)?;

    let window_size = if max_window == 0 { 256 } else { max_window };
    let start = (mismatch_offset.saturating_sub(64)) & !0x0F;
    let total_max_len = expected.len().max(actual.len());
    let end = (start + window_size).min(total_max_len);

    let mut out = String::with_capacity(4096);

    out.push_str(&format!(
        "\u{26A0}\u{FE0F} [Binary Mismatch] First difference at offset 0x{:08X} ({} bytes):\n",
        mismatch_offset, mismatch_offset
    ));
    out.push_str(&format!(
        "  Expected length: {} bytes | Actual length: {} bytes\n\n",
        expected.len(),
        actual.len()
    ));
    out.push_str("  Offset    Expected (Hex)                                    Actual (Hex)                                      | Expected (ASCII) | Actual (ASCII)  |\n");
    out.push_str("  ---------------------------------------------------------------------------------------------------------------------------------------------\n");

    let mut line_start = start;
    while line_start < end {
        out.push_str(&format!("  {:08X}  ", line_start));

        // Expected Hex
        for i in line_start..line_start + 16 {
            if i < expected.len() {
                let b = expected[i];
                let is_diff = i >= actual.len() || b != actual[i];
                if is_diff {
                    if use_ansi {
                        out.push_str(" \x1B[1;31m");
                        out.push(HEX_CHARS[(b >> 4) as usize] as char);
                        out.push(HEX_CHARS[(b & 0x0F) as usize] as char);
                        out.push_str("\x1B[0m");
                    } else {
                        out.push('_');
                        out.push(HEX_CHARS[(b >> 4) as usize] as char);
                        out.push(HEX_CHARS[(b & 0x0F) as usize] as char);
                        out.push('_');
                    }
                } else {
                    out.push(' ');
                    out.push(HEX_CHARS[(b >> 4) as usize] as char);
                    out.push(HEX_CHARS[(b & 0x0F) as usize] as char);
                }
            } else {
                out.push_str("   ");
            }
        }
        out.push_str("  ");

        // Actual Hex
        for i in line_start..line_start + 16 {
            if i < actual.len() {
                let b = actual[i];
                let is_diff = i >= expected.len() || b != expected[i];
                if is_diff {
                    if use_ansi {
                        out.push_str(" \x1B[1;31m");
                        out.push(HEX_CHARS[(b >> 4) as usize] as char);
                        out.push(HEX_CHARS[(b & 0x0F) as usize] as char);
                        out.push_str("\x1B[0m");
                    } else {
                        out.push('_');
                        out.push(HEX_CHARS[(b >> 4) as usize] as char);
                        out.push(HEX_CHARS[(b & 0x0F) as usize] as char);
                        out.push('_');
                    }
                } else {
                    out.push(' ');
                    out.push(HEX_CHARS[(b >> 4) as usize] as char);
                    out.push(HEX_CHARS[(b & 0x0F) as usize] as char);
                }
            } else {
                out.push_str("   ");
            }
        }
        out.push_str("  | ");

        // ASCII Preview Expected
        for i in line_start..line_start + 16 {
            if i < expected.len() {
                let b = expected[i];
                let is_diff = i >= actual.len() || b != actual[i];
                let ch = if (32..=126).contains(&b) { b as char } else { '.' };
                if is_diff && use_ansi {
                    out.push_str("\x1B[1;31m");
                    out.push(ch);
                    out.push_str("\x1B[0m");
                } else {
                    out.push(ch);
                }
            } else {
                out.push(' ');
            }
        }
        out.push_str(" | ");

        // ASCII Preview Actual
        for i in line_start..line_start + 16 {
            if i < actual.len() {
                let b = actual[i];
                let is_diff = i >= expected.len() || b != expected[i];
                let ch = if (32..=126).contains(&b) { b as char } else { '.' };
                if is_diff && use_ansi {
                    out.push_str("\x1B[1;31m");
                    out.push(ch);
                    out.push_str("\x1B[0m");
                } else {
                    out.push(ch);
                }
            } else {
                out.push(' ');
            }
        }
        out.push_str("|\n");

        line_start += 16;
    }

    Some(out)
}

/// C-ABI: Generates binary hex diff string. Returns null in `out_diff` if buffers are identical.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_hex_diff(
    expected_ptr: *const u8,
    expected_len: usize,
    actual_ptr: *const u8,
    actual_len: usize,
    max_window: usize,
    use_ansi: bool,
    out_diff: *mut *mut c_char,
) -> i32 {
    let result = catch_unwind(|| {
        if out_diff.is_null() {
            return -1;
        }
        *out_diff = std::ptr::null_mut();

        let exp = if expected_len > 0 && !expected_ptr.is_null() {
            std::slice::from_raw_parts(expected_ptr, expected_len)
        } else {
            &[]
        };

        let act = if actual_len > 0 && !actual_ptr.is_null() {
            std::slice::from_raw_parts(actual_ptr, actual_len)
        } else {
            &[]
        };

        if let Some(diff_str) = generate_hex_diff(exp, act, max_window, use_ansi) {
            if let Ok(c_str) = CString::new(diff_str) {
                *out_diff = c_str.into_raw();
                return 1;
            }
        }
        0
    });
    result.unwrap_or(-1)
}

/// C-ABI: Deallocates string generated by `ttzip_rust_hex_diff`.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_free_hex_diff(diff_ptr: *mut c_char) {
    if !diff_ptr.is_null() {
        let _ = CString::from_raw(diff_ptr);
    }
}
