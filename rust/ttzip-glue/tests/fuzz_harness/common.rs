// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Common Fuzzing Harness Utilities: PRNG, Mutation Strategies, and Baseline Archive Builders.

use ttzip_glue::sevenz::create_7z_solid_archive_bytes;
use ttzip_glue::types::TTZipEncryptionMethod;
use ttzip_glue::zip::writer::{assemble_zip_archive, compress_items_parallel, ZipInputItem};

/// Fast, deterministic PRNG (Xorshift64Star) for reproducible fuzz mutations.
#[derive(Debug, Clone)]
pub struct FuzzRng {
    state: u64,
}

impl FuzzRng {
    pub fn new(seed: u64) -> Self {
        Self {
            state: if seed == 0 {
                0x853c49e6748fea9b
            } else {
                seed
            },
        }
    }

    #[inline]
    pub fn next_u64(&mut self) -> u64 {
        self.state ^= self.state >> 12;
        self.state ^= self.state << 25;
        self.state ^= self.state >> 27;
        self.state = self.state.wrapping_mul(0x2545F4914F6CDD1D);
        self.state
    }

    #[inline]
    pub fn next_usize(&mut self, bound: usize) -> usize {
        if bound == 0 {
            0
        } else {
            (self.next_u64() % (bound as u64)) as usize
        }
    }

    #[inline]
    pub fn next_u8(&mut self) -> u8 {
        (self.next_u64() & 0xFF) as u8
    }

    #[inline]
    pub fn next_bool(&mut self) -> bool {
        (self.next_u64() & 1) == 1
    }
}

/// Dynamically scales fuzz iterations for blazing fast local CI while supporting deep audits.
#[inline]
pub fn fuzz_scale(base: usize) -> usize {
    if let Ok(scale_str) = std::env::var("TTZIP_FUZZ_SCALE") {
        if let Ok(scale) = scale_str.parse::<f64>() {
            return ((base as f64) * scale).max(100.0) as usize;
        }
    }
    if std::env::var("TTZIP_FUZZ_DEEP").is_ok() {
        return base;
    }
    // High-coverage balanced mode for ultra-fast local CI (<3s total)
    (base / 5).max(500)
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MutationStrategy {
    BitFlip,
    ByteTruncation,
    OffsetOverflow,
    CorruptMagic,
    CorruptExtraField,
    Composite,
}

/// Applies a single bit flip mutation at a random position.
pub fn mutate_bit_flip(buf: &mut [u8], rng: &mut FuzzRng) {
    if buf.is_empty() {
        return;
    }
    let idx = rng.next_usize(buf.len());
    let bit = rng.next_usize(8);
    buf[idx] ^= 1 << bit;
}

/// Applies a truncation mutation by slicing the buffer to a random length.
pub fn mutate_byte_truncation(buf: &mut Vec<u8>, rng: &mut FuzzRng) {
    if buf.is_empty() {
        return;
    }
    let new_len = rng.next_usize(buf.len());
    buf.truncate(new_len);
}

/// Overwrites a 2-byte, 4-byte, or 8-byte field with extreme overflow values.
pub fn mutate_offset_overflow(buf: &mut [u8], rng: &mut FuzzRng) {
    if buf.is_empty() {
        return;
    }
    let extreme_values_32 = [
        0xFFFFFFFFu32,
        0xFFFFFFFEu32,
        0x80000000u32,
        0x7FFFFFFFu32,
        0x0000FFFFu32,
        0x00010000u32,
        0xDEADBEEFu32,
        0x00000000u32,
    ];
    let extreme_values_64 = [
        u64::MAX,
        u64::MAX - 1,
        0x8000000000000000u64,
        0x7FFFFFFFFFFFFFFFu64,
        0x00000000FFFFFFFFu64,
        0x0000000100000000u64,
        0xDEADBEEFCAFEBABEu64,
    ];

    if rng.next_bool() && buf.len() >= 4 {
        let max_pos = buf.len() - 4;
        let pos = rng.next_usize(max_pos + 1);
        let val = extreme_values_32[rng.next_usize(extreme_values_32.len())];
        buf[pos..pos + 4].copy_from_slice(&val.to_le_bytes());
    } else if buf.len() >= 8 {
        let max_pos = buf.len() - 8;
        let pos = rng.next_usize(max_pos + 1);
        let val = extreme_values_64[rng.next_usize(extreme_values_64.len())];
        buf[pos..pos + 8].copy_from_slice(&val.to_le_bytes());
    }
}

/// Corrupts known magic signatures in the buffer.
pub fn mutate_corrupt_magic(buf: &mut [u8], rng: &mut FuzzRng) {
    if buf.len() < 4 {
        return;
    }
    let corrupted_magics = [
        [0x50, 0x4B, 0x00, 0x00], // Corrupted PK..
        [0x00, 0x00, 0x00, 0x00], // Zeroes
        [0xFF, 0xFF, 0xFF, 0xFF], // 0xFF
        [0x37, 0x7A, 0x00, 0x00], // Corrupted 7z
        [0x50, 0x4B, 0x07, 0x08], // Data descriptor magic in wrong place
    ];
    let choice = corrupted_magics[rng.next_usize(corrupted_magics.len())];
    let max_pos = buf.len() - 4;
    let pos = rng.next_usize(max_pos + 1);
    buf[pos..pos + 4].copy_from_slice(&choice);
}

/// Injects corrupted Extra Fields into the buffer.
pub fn mutate_corrupt_extra_field(buf: &mut Vec<u8>, rng: &mut FuzzRng) {
    let bad_extra_headers = [
        vec![0x01, 0x00, 0x00, 0x00],             // Zip64 with len 0
        vec![0x01, 0x00, 0xFF, 0x00],             // Zip64 with len 255 (overflowing)
        vec![0x01, 0x00, 0x03, 0x00, 0x01, 0x02], // Zip64 with partial payload
        vec![0x01, 0x99, 0x02, 0x00, 0x01],       // AES with truncated payload
        vec![0x55, 0x54, 0x00, 0x00],             // InfoZip mtime with len 0
        vec![0x75, 0x70, 0xFF, 0xFF],             // Unicode path with len 0xFFFF
    ];
    let extra = &bad_extra_headers[rng.next_usize(bad_extra_headers.len())];
    let insert_pos = rng.next_usize(buf.len() + 1);
    buf.splice(insert_pos..insert_pos, extra.iter().cloned());
}

/// Applies a composite mutation (1..5 random mutations chained).
pub fn mutate_composite(buf: &mut Vec<u8>, rng: &mut FuzzRng) {
    let steps = 1 + rng.next_usize(5);
    for _ in 0..steps {
        match rng.next_usize(5) {
            0 => {
                if !buf.is_empty() {
                    mutate_bit_flip(buf, rng);
                }
            }
            1 => mutate_byte_truncation(buf, rng),
            2 => {
                if !buf.is_empty() {
                    mutate_offset_overflow(buf, rng);
                }
            }
            3 => {
                if buf.len() >= 4 {
                    mutate_corrupt_magic(buf, rng);
                }
            }
            4 => mutate_corrupt_extra_field(buf, rng),
            _ => unreachable!(),
        }
    }
}

pub fn build_baseline_zip() -> Vec<u8> {
    let items = vec![
        ZipInputItem {
            rel_path: "fuzz_target_1.txt".to_string(),
            data: b"Fuzzing TTZip Central Directory Parser with Safe Invariants.".to_vec(),
            mtime_epoch_secs: 1700000000,
            mode: 0o644,
            is_directory: false,
        },
        ZipInputItem {
            rel_path: "fuzz_dir/".to_string(),
            data: Vec::new(),
            mtime_epoch_secs: 1700000000,
            mode: 0o755,
            is_directory: true,
        },
        ZipInputItem {
            rel_path: "fuzz_dir/nested.bin".to_string(),
            data: vec![0x5Au8; 4096],
            mtime_epoch_secs: 1700000000,
            mode: 0o644,
            is_directory: false,
        },
    ];

    let compressed = compress_items_parallel(
        items,
        6,
        TTZipEncryptionMethod::None,
        None,
        2,
    ).expect("baseline zip compression failed");

    assemble_zip_archive(&compressed).expect("baseline zip assembly failed")
}

pub fn build_baseline_encrypted_zip() -> Vec<u8> {
    let items = vec![ZipInputItem {
        rel_path: "secret.dat".to_string(),
        data: vec![0x77u8; 1024],
        mtime_epoch_secs: 1700000000,
        mode: 0o600,
        is_directory: false,
    }];

    let compressed = compress_items_parallel(
        items,
        6,
        TTZipEncryptionMethod::Aes256,
        Some("FuzzPassword2026!"),
        2,
    ).expect("baseline encrypted zip compression failed");

    assemble_zip_archive(&compressed).expect("baseline encrypted zip assembly failed")
}

pub fn build_baseline_7z() -> Vec<u8> {
    let items = vec![
        ZipInputItem {
            rel_path: "doc.txt".to_string(),
            data: b"7z fuzz baseline payload".to_vec(),
            mtime_epoch_secs: 1700000000,
            mode: 0o644,
            is_directory: false,
        },
        ZipInputItem {
            rel_path: "folder/".to_string(),
            data: Vec::new(),
            mtime_epoch_secs: 1700000000,
            mode: 0o755,
            is_directory: true,
        },
        ZipInputItem {
            rel_path: "folder/data.bin".to_string(),
            data: vec![0x42u8; 2048],
            mtime_epoch_secs: 1700000000,
            mode: 0o644,
            is_directory: false,
        },
    ];

    create_7z_solid_archive_bytes(&items, 1, 2).expect("baseline 7z creation failed")
}
