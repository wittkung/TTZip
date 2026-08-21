// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Scalar block compression routine for SHA-1 (RFC 3174).

use zeroize::Zeroize;

pub const SHA1_INITIAL_H: [u32; 5] = [
    0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0,
];

#[inline(always)]
pub fn rol(val: u32, bits: u32) -> u32 {
    (val << bits) | (val >> (32 - bits))
}

#[inline(always)]
pub fn sha1_compress_block(state: &mut [u32; 5], block: &[u8; 64]) {
    let mut w = [0u32; 80];

    for i in 0..16 {
        w[i] = u32::from_be_bytes([
            block[i * 4],
            block[i * 4 + 1],
            block[i * 4 + 2],
            block[i * 4 + 3],
        ]);
    }

    for i in 16..80 {
        w[i] = rol(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1);
    }

    let mut a = state[0];
    let mut b = state[1];
    let mut c = state[2];
    let mut d = state[3];
    let mut e = state[4];

    // Rounds 0..19
    for i in 0..20 {
        let f = (b & c) | ((!b) & d);
        let k = 0x5A827999;
        let temp = rol(a, 5)
            .wrapping_add(f)
            .wrapping_add(e)
            .wrapping_add(k)
            .wrapping_add(w[i]);
        e = d;
        d = c;
        c = rol(b, 30);
        b = a;
        a = temp;
    }

    // Rounds 20..39
    for i in 20..40 {
        let f = b ^ c ^ d;
        let k = 0x6ED9EBA1;
        let temp = rol(a, 5)
            .wrapping_add(f)
            .wrapping_add(e)
            .wrapping_add(k)
            .wrapping_add(w[i]);
        e = d;
        d = c;
        c = rol(b, 30);
        b = a;
        a = temp;
    }

    // Rounds 40..59
    for i in 40..60 {
        let f = (b & c) | (b & d) | (c & d);
        let k = 0x8F1BBCDC;
        let temp = rol(a, 5)
            .wrapping_add(f)
            .wrapping_add(e)
            .wrapping_add(k)
            .wrapping_add(w[i]);
        e = d;
        d = c;
        c = rol(b, 30);
        b = a;
        a = temp;
    }

    // Rounds 60..79
    for i in 60..80 {
        let f = b ^ c ^ d;
        let k = 0xCA62C1D6;
        let temp = rol(a, 5)
            .wrapping_add(f)
            .wrapping_add(e)
            .wrapping_add(k)
            .wrapping_add(w[i]);
        e = d;
        d = c;
        c = rol(b, 30);
        b = a;
        a = temp;
    }

    state[0] = state[0].wrapping_add(a);
    state[1] = state[1].wrapping_add(b);
    state[2] = state[2].wrapping_add(c);
    state[3] = state[3].wrapping_add(d);
    state[4] = state[4].wrapping_add(e);

    w.zeroize();
}
