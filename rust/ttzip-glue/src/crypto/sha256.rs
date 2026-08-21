// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Hardware-accelerated SHA-256 and 7z SHA-256 KDF engine.
//!
//! Implements ARM64 Crypto extension SHA-256 block compression (`SHA256H`,
//! `SHA256H2`, `SHA256SU0`, `SHA256SU1`) and 7z KDF key derivation
//! (up to 524,288 cycles) with zero heap allocations.

const K256: [u32; 64] = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
];

const INITIAL_H: [u32; 8] = [
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
    0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
];

// ============================================================================
// 1. ARM64 SHA-256 Hardware Compression
// ============================================================================
#[cfg(target_arch = "aarch64")]
mod arm64 {
    use super::*;
    use core::arch::aarch64::*;
    use core::arch::asm;

    #[inline(always)]
    unsafe fn vsha256hq_u32(
        mut hash_abcd: uint32x4_t,
        hash_efgh: uint32x4_t,
        wk: uint32x4_t,
    ) -> uint32x4_t {
        asm!(
            "SHA256H {hash_abcd:q}, {hash_efgh:q}, {wk:v}.4S",
            hash_abcd = inout(vreg) hash_abcd,
            hash_efgh = in(vreg) hash_efgh,
            wk = in(vreg) wk,
            options(pure, nomem, nostack, preserves_flags)
        );
        hash_abcd
    }

    #[inline(always)]
    unsafe fn vsha256h2q_u32(
        mut hash_efgh: uint32x4_t,
        hash_abcd: uint32x4_t,
        wk: uint32x4_t,
    ) -> uint32x4_t {
        asm!(
            "SHA256H2 {hash_efgh:q}, {hash_abcd:q}, {wk:v}.4S",
            hash_efgh = inout(vreg) hash_efgh,
            hash_abcd = in(vreg) hash_abcd,
            wk = in(vreg) wk,
            options(pure, nomem, nostack, preserves_flags)
        );
        hash_efgh
    }

    #[inline(always)]
    unsafe fn vsha256su0q_u32(mut w0_3: uint32x4_t, w4_7: uint32x4_t) -> uint32x4_t {
        asm!(
            "SHA256SU0 {w0_3:v}.4S, {w4_7:v}.4S",
            w0_3 = inout(vreg) w0_3,
            w4_7 = in(vreg) w4_7,
            options(pure, nomem, nostack, preserves_flags)
        );
        w0_3
    }

    #[inline(always)]
    unsafe fn vsha256su1q_u32(
        mut tw0_3: uint32x4_t,
        w8_11: uint32x4_t,
        w12_15: uint32x4_t,
    ) -> uint32x4_t {
        asm!(
            "SHA256SU1 {tw0_3:v}.4S, {w8_11:v}.4S, {w12_15:v}.4S",
            tw0_3 = inout(vreg) tw0_3,
            w8_11 = in(vreg) w8_11,
            w12_15 = in(vreg) w12_15,
            options(pure, nomem, nostack, preserves_flags)
        );
        tw0_3
    }

    #[target_feature(enable = "sha2")]
    pub unsafe fn compress_blocks_arm64(state: &mut [u32; 8], mut data: *const u8, blocks: usize) {
        let mut abcd = vld1q_u32(state.as_ptr());
        let mut efgh = vld1q_u32(state.as_ptr().add(4));

        for _ in 0..blocks {
            let abcd_orig = abcd;
            let efgh_orig = efgh;

            let mut s0 = vreinterpretq_u32_u8(vrev32q_u8(vld1q_u8(data)));
            let mut s1 = vreinterpretq_u32_u8(vrev32q_u8(vld1q_u8(data.add(16))));
            let mut s2 = vreinterpretq_u32_u8(vrev32q_u8(vld1q_u8(data.add(32))));
            let mut s3 = vreinterpretq_u32_u8(vrev32q_u8(vld1q_u8(data.add(48))));

            // Rounds 0..3
            let mut tmp = vaddq_u32(s0, vld1q_u32(&K256[0]));
            let mut abcd_prev = abcd;
            abcd = vsha256hq_u32(abcd_prev, efgh, tmp);
            efgh = vsha256h2q_u32(efgh, abcd_prev, tmp);

            // Rounds 4..7
            tmp = vaddq_u32(s1, vld1q_u32(&K256[4]));
            abcd_prev = abcd;
            abcd = vsha256hq_u32(abcd_prev, efgh, tmp);
            efgh = vsha256h2q_u32(efgh, abcd_prev, tmp);

            // Rounds 8..11
            tmp = vaddq_u32(s2, vld1q_u32(&K256[8]));
            abcd_prev = abcd;
            abcd = vsha256hq_u32(abcd_prev, efgh, tmp);
            efgh = vsha256h2q_u32(efgh, abcd_prev, tmp);

            // Rounds 12..15
            tmp = vaddq_u32(s3, vld1q_u32(&K256[12]));
            abcd_prev = abcd;
            abcd = vsha256hq_u32(abcd_prev, efgh, tmp);
            efgh = vsha256h2q_u32(efgh, abcd_prev, tmp);

            for t in (16..64).step_by(16) {
                // Rounds t..t+3
                s0 = vsha256su1q_u32(vsha256su0q_u32(s0, s1), s2, s3);
                tmp = vaddq_u32(s0, vld1q_u32(&K256[t]));
                abcd_prev = abcd;
                abcd = vsha256hq_u32(abcd_prev, efgh, tmp);
                efgh = vsha256h2q_u32(efgh, abcd_prev, tmp);

                // Rounds t+4..t+7
                s1 = vsha256su1q_u32(vsha256su0q_u32(s1, s2), s3, s0);
                tmp = vaddq_u32(s1, vld1q_u32(&K256[t + 4]));
                abcd_prev = abcd;
                abcd = vsha256hq_u32(abcd_prev, efgh, tmp);
                efgh = vsha256h2q_u32(efgh, abcd_prev, tmp);

                // Rounds t+8..t+11
                s2 = vsha256su1q_u32(vsha256su0q_u32(s2, s3), s0, s1);
                tmp = vaddq_u32(s2, vld1q_u32(&K256[t + 8]));
                abcd_prev = abcd;
                abcd = vsha256hq_u32(abcd_prev, efgh, tmp);
                efgh = vsha256h2q_u32(efgh, abcd_prev, tmp);

                // Rounds t+12..t+15
                s3 = vsha256su1q_u32(vsha256su0q_u32(s3, s0), s1, s2);
                tmp = vaddq_u32(s3, vld1q_u32(&K256[t + 12]));
                abcd_prev = abcd;
                abcd = vsha256hq_u32(abcd_prev, efgh, tmp);
                efgh = vsha256h2q_u32(efgh, abcd_prev, tmp);
            }

            abcd = vaddq_u32(abcd, abcd_orig);
            efgh = vaddq_u32(efgh, efgh_orig);

            data = data.add(64);
        }

        vst1q_u32(state.as_mut_ptr(), abcd);
        vst1q_u32(state.as_mut_ptr().add(4), efgh);
    }
}

// ============================================================================
// 2. Scalar Reference Block Compression
// ============================================================================
#[allow(dead_code)]
pub mod scalar {
    use super::*;

    #[inline(always)]
    fn rotr(x: u32, n: u32) -> u32 {
        (x >> n) | (x << (32 - n))
    }

    #[inline(always)]
    fn ch(x: u32, y: u32, z: u32) -> u32 {
        (x & y) ^ (!x & z)
    }

    #[inline(always)]
    fn maj(x: u32, y: u32, z: u32) -> u32 {
        (x & y) ^ (x & z) ^ (y & z)
    }

    #[inline(always)]
    fn sigma0(x: u32) -> u32 {
        rotr(x, 2) ^ rotr(x, 13) ^ rotr(x, 22)
    }

    #[inline(always)]
    fn sigma1(x: u32) -> u32 {
        rotr(x, 6) ^ rotr(x, 11) ^ rotr(x, 25)
    }

    #[inline(always)]
    fn gamma0(x: u32) -> u32 {
        rotr(x, 7) ^ rotr(x, 18) ^ (x >> 3)
    }

    #[inline(always)]
    fn gamma1(x: u32) -> u32 {
        rotr(x, 17) ^ rotr(x, 19) ^ (x >> 10)
    }

    pub fn compress_blocks_scalar(state: &mut [u32; 8], mut data: *const u8, blocks: usize) {
        for _ in 0..blocks {
            let mut w = [0u32; 64];
            let raw_p = data as *const u32;

            for i in 0..16 {
                w[i] = u32::from_be(unsafe { *raw_p.add(i) });
            }

            for i in 16..64 {
                w[i] = gamma1(w[i - 2])
                    .wrapping_add(w[i - 7])
                    .wrapping_add(gamma0(w[i - 15]))
                    .wrapping_add(w[i - 16]);
            }

            let mut a = state[0];
            let mut b = state[1];
            let mut c = state[2];
            let mut d = state[3];
            let mut e = state[4];
            let mut f = state[5];
            let mut g = state[6];
            let mut h = state[7];

            for i in 0..64 {
                let t1 = h
                    .wrapping_add(sigma1(e))
                    .wrapping_add(ch(e, f, g))
                    .wrapping_add(K256[i])
                    .wrapping_add(w[i]);
                let t2 = sigma0(a).wrapping_add(maj(a, b, c));

                h = g;
                g = f;
                f = e;
                e = d.wrapping_add(t1);
                d = c;
                c = b;
                b = a;
                a = t1.wrapping_add(t2);
            }

            state[0] = state[0].wrapping_add(a);
            state[1] = state[1].wrapping_add(b);
            state[2] = state[2].wrapping_add(c);
            state[3] = state[3].wrapping_add(d);
            state[4] = state[4].wrapping_add(e);
            state[5] = state[5].wrapping_add(f);
            state[6] = state[6].wrapping_add(g);
            state[7] = state[7].wrapping_add(h);

            unsafe {
                data = data.add(64);
            }
        }
    }
}

// ============================================================================
// 3. Fast Streaming SHA-256 Engine
// ============================================================================

/// Stack-allocated zero-heap streaming SHA-256 hasher.
#[derive(Clone)]
pub struct FastSha256 {
    state: [u32; 8],
    buffer: [u8; 64],
    buf_len: usize,
    total_len: u64,
}

impl Default for FastSha256 {
    fn default() -> Self {
        Self::new()
    }
}

impl FastSha256 {
    pub const fn new() -> Self {
        Self {
            state: INITIAL_H,
            buffer: [0u8; 64],
            buf_len: 0,
            total_len: 0,
        }
    }

    /// Computes one-shot SHA-256 digest of input data.
    pub fn digest(data: &[u8]) -> [u8; 32] {
        let mut hasher = Self::new();
        hasher.update(data);
        hasher.finalize()
    }

    #[inline(always)]
    fn compress(&mut self, data: *const u8, blocks: usize) {
        #[cfg(target_arch = "aarch64")]
        unsafe {
            arm64::compress_blocks_arm64(&mut self.state, data, blocks);
        }

        #[cfg(not(target_arch = "aarch64"))]
        {
            scalar::compress_blocks_scalar(&mut self.state, data, blocks);
        }
    }

    pub fn update(&mut self, mut data: &[u8]) {
        self.total_len += data.len() as u64;

        if self.buf_len > 0 {
            let take = (64 - self.buf_len).min(data.len());
            self.buffer[self.buf_len..self.buf_len + take].copy_from_slice(&data[..take]);
            self.buf_len += take;
            data = &data[take..];

            if self.buf_len == 64 {
                let buf_ptr = self.buffer.as_ptr();
                self.compress(buf_ptr, 1);
                self.buf_len = 0;
            }
        }

        let full_blocks = data.len() / 64;
        if full_blocks > 0 {
            self.compress(data.as_ptr(), full_blocks);
            data = &data[full_blocks * 64..];
        }

        if !data.is_empty() {
            self.buffer[..data.len()].copy_from_slice(data);
            self.buf_len = data.len();
        }
    }

    pub fn finalize(mut self) -> [u8; 32] {
        let bit_len = self.total_len * 8;
        self.buffer[self.buf_len] = 0x80;
        self.buf_len += 1;

        if self.buf_len > 56 {
            self.buffer[self.buf_len..64].fill(0);
            let buf_ptr = self.buffer.as_ptr();
            self.compress(buf_ptr, 1);
            self.buf_len = 0;
        }

        self.buffer[self.buf_len..56].fill(0);
        self.buffer[56..64].copy_from_slice(&bit_len.to_be_bytes());
        let buf_ptr = self.buffer.as_ptr();
        self.compress(buf_ptr, 1);

        let mut out = [0u8; 32];
        for i in 0..8 {
            out[i * 4..i * 4 + 4].copy_from_slice(&self.state[i].to_be_bytes());
        }
        out
    }
}

// ============================================================================
// 4. 7z SHA-256 Key Derivation Function (KDF)
// ============================================================================

/// Derives a 32-byte AES key for 7z archives using hardware-accelerated SHA-256.
///
/// Memory allocations: 0 heap allocations (fully operates on fixed stack storage).
pub fn sha256_7z_kdf(
    password: &str,
    salt: &[u8],
    num_cycles_power: u32,
) -> [u8; 32] {
    let mut hasher = FastSha256::new();
    let num_cycles = 1u64 << num_cycles_power;

    // Convert UTF-8 password to UTF-16LE in a fixed stack buffer
    let mut utf16_buf = [0u8; 1024];
    let mut utf16_len = 0;

    for val in password.encode_utf16() {
        if utf16_len + 2 <= utf16_buf.len() {
            let bytes = val.to_le_bytes();
            utf16_buf[utf16_len] = bytes[0];
            utf16_buf[utf16_len + 1] = bytes[1];
            utf16_len += 2;
        }
    }

    let pass_bytes = &utf16_buf[..utf16_len];

    for i in 0..num_cycles {
        if !salt.is_empty() {
            hasher.update(salt);
        }
        if !pass_bytes.is_empty() {
            hasher.update(pass_bytes);
        }
        let counter_bytes = i.to_le_bytes();
        hasher.update(&counter_bytes);
    }

    hasher.finalize()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_sha256_nist_vectors() {
        // Empty string
        let empty_hash = FastSha256::new().finalize();
        assert_eq!(
            hex::encode(empty_hash),
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        );

        // "abc"
        let mut h = FastSha256::new();
        h.update(b"abc");
        assert_eq!(
            hex::encode(h.finalize()),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        );

        // "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
        let mut h2 = FastSha256::new();
        h2.update(b"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq");
        assert_eq!(
            hex::encode(h2.finalize()),
            "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"
        );
    }

    #[test]
    fn test_7z_kdf_sha256_cycles() {
        let salt = [0x01, 0x02, 0x03, 0x04];
        let key = sha256_7z_kdf("password123", &salt, 6); // 64 cycles
        assert_ne!(key, [0u8; 32]);
    }
}
