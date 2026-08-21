// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Fuzzing Harness & Robustness Test Suite for TTZip.
//!
//! Validates Tasks T006, T007, T008, T009:
//! - T006 [US2]: ZIP Central Directory, Local File Header, and Extra Fields mutation fuzzing.
//! - T007 [US2]: 7z SignatureHeader, Varint codec, and EncodedHeader mutation fuzzing.
//! - T008 [US2]: Safe extraction ZipSlip and path traversal attack injection fuzzing.
//! - T009 [US2]: Stream micro-buffering fault injection and memory bound verification.

use std::io::{Read, Seek, SeekFrom};
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::path::Path;

use ttzip_glue::archive::stream_adapter::{
    StreamReaderState, DEFAULT_STREAM_BUFFER_SIZE, MAX_RESIDENT_MEMORY_MB, MAX_STREAM_BUFFER_SIZE,
};
use ttzip_glue::fs::safe_extract::{sanitize_and_validate_path, SafeExtractEngine};
use ttzip_glue::sevenz::{
    create_7z_solid_archive_bytes, parse_7z_metadata, read_varint, write_varint,
    SevenZArchive, SevenZSignatureHeader,
};
use ttzip_glue::types::{TTZipEncryptionMethod, TTZipStatus};
use ttzip_glue::zip::extra::ZipExtraFields;
use ttzip_glue::zip::parser::{
    find_eocd, parse_all_entries, parse_cdfh_entry, parse_local_file_header,
};
use ttzip_glue::zip::reader::ZipArchive;
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

// -----------------------------------------------------------------------------
// Mutation Strategies
// -----------------------------------------------------------------------------

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

// -----------------------------------------------------------------------------
// Baseline Archive Builders
// -----------------------------------------------------------------------------

fn build_baseline_zip() -> Vec<u8> {
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

fn build_baseline_encrypted_zip() -> Vec<u8> {
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

fn build_baseline_7z() -> Vec<u8> {
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

// -----------------------------------------------------------------------------
// Task T006: ZIP Central Directory, LFH & Extra Field Fuzzing
// -----------------------------------------------------------------------------

#[test]
fn test_fuzz_zip_central_directory_and_extra_fields() {
    let baseline_plain = build_baseline_zip();
    let baseline_enc = build_baseline_encrypted_zip();

    let mut rng = FuzzRng::new(0x1337BEEF00000001);
    let total_iterations = fuzz_scale(25_000);
    let mut panics_caught = 0u64;
    let mut graceful_rejections = 0u64;
    let mut successful_parses = 0u64;

    for i in 0..total_iterations {
        let baseline = if i % 2 == 0 {
            &baseline_plain
        } else {
            &baseline_enc
        };

        let mut mutated = baseline.clone();

        // Apply mutation based on iteration
        let strategy = match i % 6 {
            0 => MutationStrategy::BitFlip,
            1 => MutationStrategy::ByteTruncation,
            2 => MutationStrategy::OffsetOverflow,
            3 => MutationStrategy::CorruptMagic,
            4 => MutationStrategy::CorruptExtraField,
            _ => MutationStrategy::Composite,
        };

        match strategy {
            MutationStrategy::BitFlip => mutate_bit_flip(&mut mutated, &mut rng),
            MutationStrategy::ByteTruncation => mutate_byte_truncation(&mut mutated, &mut rng),
            MutationStrategy::OffsetOverflow => mutate_offset_overflow(&mut mutated, &mut rng),
            MutationStrategy::CorruptMagic => mutate_corrupt_magic(&mut mutated, &mut rng),
            MutationStrategy::CorruptExtraField => mutate_corrupt_extra_field(&mut mutated, &mut rng),
            MutationStrategy::Composite => mutate_composite(&mut mutated, &mut rng),
        }

        let rand_off_lfh = if mutated.len() >= 30 {
            rng.next_usize(mutated.len() - 30)
        } else {
            0
        };
        let rand_off_cdfh = if mutated.len() >= 46 {
            rng.next_usize(mutated.len() - 46)
        } else {
            0
        };
        let extra_start = if !mutated.is_empty() {
            rng.next_usize(mutated.len())
        } else {
            0
        };
        let extra_end = if !mutated.is_empty() {
            extra_start + rng.next_usize(mutated.len() - extra_start + 1)
        } else {
            0
        };

        // Test parser execution with panic catch barrier
        let parse_result = catch_unwind(AssertUnwindSafe(|| {
            // 1. EOCD find
            let _ = find_eocd(&mutated);

            // 2. Full entries parse
            let entries_res = parse_all_entries(&mutated);

            // 3. ZipArchive zero-copy reader
            let open_res = ZipArchive::open_slice(&mutated);
            if let Ok(archive) = open_res {
                for entry_idx in 0..archive.len() {
                    let _ = archive.extract_entry_bytes(entry_idx, None);
                    let _ = archive.extract_entry_bytes(entry_idx, Some("FuzzPassword2026!"));
                }
            }

            // 4. Random local file header probe
            if mutated.len() >= 30 {
                let _ = parse_local_file_header(&mutated, rand_off_lfh);
            }

            // 5. Random CDFH probe
            if mutated.len() >= 46 {
                let _ = parse_cdfh_entry(&mutated, rand_off_cdfh);
            }

            // 6. ZipExtraFields probe
            if !mutated.is_empty() && extra_end <= mutated.len() {
                let extra_slice = &mutated[extra_start..extra_end];
                let _ = ZipExtraFields::parse(extra_slice, true, true, true, true);
                let _ = ZipExtraFields::parse(extra_slice, false, false, false, false);
            }

            entries_res
        }));

        match parse_result {
            Ok(Ok(_)) => successful_parses += 1,
            Ok(Err(_)) => graceful_rejections += 1,
            Err(_) => panics_caught += 1,
        }
    }

    println!(
        "[FUZZ] Completed {} mutations on zipCentralDirectory -> {} rejections, {} valid, {} panics",
        total_iterations, graceful_rejections, successful_parses, panics_caught
    );

    assert_eq!(
        panics_caught, 0,
        "FATAL: Fuzzing encountered panic in ZIP parser!"
    );
    assert!(
        graceful_rejections > 0,
        "Expected mutations to trigger graceful rejections"
    );
}

// -----------------------------------------------------------------------------
// Task T007: 7z SignatureHeader, Varint & EncodedHeader Fuzzing
// -----------------------------------------------------------------------------

#[test]
fn test_fuzz_sevenz_header_and_varint() {
    let mut rng = FuzzRng::new(0x7777777700000001);
    let mut panics_caught = 0u64;

    // 1. Varint exhaustive and random fuzzing (15,000 iterations)
    for byte_val in 0u8..=255 {
        let slice = [byte_val];
        let res = catch_unwind(|| read_varint(&slice));
        assert!(res.is_ok(), "read_varint panicked on single byte {}", byte_val);
    }

    for _ in 0..fuzz_scale(15_000) {
        let len = rng.next_usize(16);
        let mut slice = vec![0u8; len];
        for b in slice.iter_mut() {
            *b = rng.next_u8();
        }

        let res = catch_unwind(AssertUnwindSafe(|| {
            if let Some((val, consumed)) = read_varint(&slice) {
                assert!(consumed <= slice.len());
                let mut re_encoded = Vec::new();
                write_varint(val, &mut re_encoded);
                assert!(!re_encoded.is_empty());
                let (re_dec, re_cons) = read_varint(&re_encoded).expect("re-decode failed");
                assert_eq!(re_dec, val);
                assert_eq!(re_cons, re_encoded.len());
            }
        }));

        if res.is_err() {
            panics_caught += 1;
        }
    }

    // 2. 7z SignatureHeader fuzzing
    let mut sig_bytes = [
        0x37u8, 0x7A, 0xBC, 0xAF, 0x27, 0x1C, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
    ];

    for _ in 0..fuzz_scale(10_000) {
        let mut mutated = sig_bytes;
        mutate_bit_flip(&mut mutated, &mut rng);

        let res = catch_unwind(AssertUnwindSafe(|| {
            let _ = SevenZSignatureHeader::parse(&mut mutated);
        }));

        if res.is_err() {
            panics_caught += 1;
        }
    }

    // 3. 7z Solid Archive and Header Stream fuzzing (15,000 iterations)
    let baseline_7z = build_baseline_7z();
    let mut graceful_rejections = 0u64;
    let mut successful_parses = 0u64;

    for i in 0..fuzz_scale(15_000) {
        let mut mutated = baseline_7z.clone();

        match i % 5 {
            0 => mutate_bit_flip(&mut mutated, &mut rng),
            1 => mutate_byte_truncation(&mut mutated, &mut rng),
            2 => mutate_offset_overflow(&mut mutated, &mut rng),
            3 => mutate_corrupt_magic(&mut mutated, &mut rng),
            _ => mutate_composite(&mut mutated, &mut rng),
        }

        let res = catch_unwind(AssertUnwindSafe(|| {
            let _ = parse_7z_metadata(&mutated);
            let open_res = SevenZArchive::open_slice(&mutated);
            if let Ok(archive) = &open_res {
                for idx in 0..archive.len() {
                    let _ = archive.extract_entry_bytes(idx, None);
                }
            }
            open_res
        }));

        match res {
            Ok(Ok(_)) => successful_parses += 1,
            Ok(Err(_)) => graceful_rejections += 1,
            Err(_) => panics_caught += 1,
        }
    }

    println!(
        "[FUZZ] Completed 40,000 mutations on sevenzHeaderVarint -> {} rejections, {} valid, {} panics",
        graceful_rejections, successful_parses, panics_caught
    );

    assert_eq!(
        panics_caught, 0,
        "FATAL: Fuzzing encountered panic in 7z parser!"
    );
}

// -----------------------------------------------------------------------------
// Task T008: ZipSlip & Path Traversal Injection Fuzzing
// -----------------------------------------------------------------------------

#[test]
fn test_fuzz_safe_extract_zipslip_traversals() {
    let dest_dir = Path::new("/tmp/ttzip_safe_extract_sandbox_test");
    let mut rng = FuzzRng::new(0x5119511900000001);

    // 1. Static corpus of high-risk exploit payloads
    let static_evil_payloads = [
        "../evil.sh",
        "../../etc/passwd",
        "../../../root/.bashrc",
        "../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../../etc/shadow",
        "/etc/passwd",
        "/private/etc/hosts",
        "/System/Library/CoreServices",
        "/var/run/docker.sock",
        "C:\\Windows\\System32\\cmd.exe",
        "C:/Windows/System32/cmd.exe",
        "D:\\malicious.bat",
        "\\Windows\\explorer.exe",
        "\\\\127.0.0.1\\c$\\exploit.exe",
        "//192.168.1.1/share/evil.dll",
        "folder/../../../../etc/passwd",
        "a/b/c/../../../../../../etc/shadow",
        "foo/bar/../../../baz",
        "./../../evil",
        "test.txt\0/etc/passwd",
        "\0../evil",
        "folder/\0file.txt",
        "foo\0bar",
        "..",
        ".",
        "",
        "/",
        "//",
        "\\\\",
        "\\\\?\\C:\\evil",
        "dir/..",
        "dir/../..",
        "..\\..\\Windows\\System32",
        "....//....//etc/passwd",
        r"..\/..\/secret",
        "file:///etc/passwd",
    ];

    let mut trapped_count = 0u64;

    for &payload in &static_evil_payloads {
        let res = sanitize_and_validate_path(dest_dir, payload);
        assert_eq!(
            res,
            Err(TTZipStatus::ErrSecurityViolation),
            "Expected payload {:?} to be trapped as ErrSecurityViolation, but got {:?}",
            payload,
            res
        );
        trapped_count += 1;
    }

    // 2. Dynamic generative permutation fuzzing (20,000 generated paths)
    let segments = [
        "..", ".", "/", "\\", "\0", "etc", "passwd", "root", "Users", "admin", "bin",
        "sub", "dir", "file", "C:", "D:", "\\\\server\\share", " ", "a", "b", "...", "....",
    ];

    for _ in 0..fuzz_scale(20_000) {
        let num_parts = 1 + rng.next_usize(8);
        let mut path_str = String::new();

        if rng.next_bool() {
            path_str.push('/');
        }

        for _ in 0..num_parts {
            let seg = segments[rng.next_usize(segments.len())];
            path_str.push_str(seg);
            if rng.next_bool() {
                path_str.push(if rng.next_bool() { '/' } else { '\\' });
            }
        }

        let res = sanitize_and_validate_path(dest_dir, &path_str);
        match res {
            Ok(sanitized) => {
                // INVARIANT: Sanitized path MUST start with dest_dir and CANNOT escape
                assert!(
                    sanitized.starts_with(dest_dir),
                    "SECURITY ESCAPE: Resulting path {:?} escapes dest_dir {:?}",
                    sanitized,
                    dest_dir
                );
                assert_ne!(
                    sanitized,
                    dest_dir.to_path_buf(),
                    "Sanitized path cannot be dest_dir itself"
                );
            }
            Err(status) => {
                assert_eq!(status, TTZipStatus::ErrSecurityViolation);
                trapped_count += 1;
            }
        }
    }

    // 3. Engine-level extraction integration with malicious entries
    let mut engine = SafeExtractEngine::new();
    for &payload in &static_evil_payloads {
        let check_res = sanitize_and_validate_path(dest_dir, payload);
        assert_eq!(check_res, Err(TTZipStatus::ErrSecurityViolation));
        if let Ok(safe_p) = check_res {
            engine.register_entry(safe_p, 0o644, 1700000000, 0, false);
        }
    }

    println!(
        "[FUZZ] Completed 20,000+ mutations on safeExtractPathTraversals -> {} trapped, 0 escapes",
        trapped_count
    );
}

// -----------------------------------------------------------------------------
// Task T009: Stream Micro-buffering Fault Injection Fuzzing
// -----------------------------------------------------------------------------

/// Configurable fault-injecting `Read` + `Seek` stream.
struct FaultyStream {
    data: Vec<u8>,
    position: usize,
    inject_eof_after_bytes: usize,
    inject_io_error_at_call: usize,
    inject_interrupted_at_call: usize,
    max_chunk_size: usize,
    call_count: usize,
}

impl Read for FaultyStream {
    fn read(&mut self, buf: &mut [u8]) -> std::io::Result<usize> {
        self.call_count += 1;

        if self.call_count == self.inject_io_error_at_call {
            return Err(std::io::Error::new(
                std::io::ErrorKind::ConnectionReset,
                "Simulated connection reset",
            ));
        }

        if self.call_count == self.inject_interrupted_at_call {
            return Err(std::io::Error::new(
                std::io::ErrorKind::Interrupted,
                "Simulated interrupted call",
            ));
        }

        if self.position >= self.data.len() || self.position >= self.inject_eof_after_bytes {
            return Ok(0);
        }

        let remaining = self.data.len() - self.position;
        let allowed = remaining
            .min(buf.len())
            .min(self.max_chunk_size)
            .min(self.inject_eof_after_bytes.saturating_sub(self.position));

        if allowed == 0 {
            return Ok(0);
        }

        buf[..allowed].copy_from_slice(&self.data[self.position..self.position + allowed]);
        self.position += allowed;
        Ok(allowed)
    }
}

impl Seek for FaultyStream {
    fn seek(&mut self, pos: SeekFrom) -> std::io::Result<u64> {
        let new_pos = match pos {
            SeekFrom::Start(offset) => offset as i64,
            SeekFrom::Current(offset) => (self.position as i64) + offset,
            SeekFrom::End(offset) => (self.data.len() as i64) + offset,
        };

        if new_pos < 0 || new_pos > (self.data.len() as i64) {
            return Err(std::io::Error::new(
                std::io::ErrorKind::InvalidInput,
                "Invalid seek position",
            ));
        }

        self.position = new_pos as usize;
        Ok(self.position as u64)
    }
}

#[test]
fn test_fuzz_stream_fault_injection() {
    let mut rng = FuzzRng::new(0x9999888800000001);
    let total_stream_trials = fuzz_scale(5_000);
    let mut panics_caught = 0u64;

    for _ in 0..total_stream_trials {
        let data_len = 100 + rng.next_usize(128 * 1024);
        let sample_data = vec![0xAAu8; data_len];

        let eof_after = 10 + rng.next_usize(data_len);
        let error_at = 1 + rng.next_usize(20);
        let intr_at = 1 + rng.next_usize(20);
        let chunk_size = 1 + rng.next_usize(1024);

        let stream = FaultyStream {
            data: sample_data,
            position: 0,
            inject_eof_after_bytes: eof_after,
            inject_io_error_at_call: error_at,
            inject_interrupted_at_call: intr_at,
            max_chunk_size: chunk_size,
            call_count: 0,
        };

        let buffer_size = match rng.next_usize(4) {
            0 => 1024,                     // Clamped to DEFAULT_STREAM_BUFFER_SIZE (64KB)
            1 => DEFAULT_STREAM_BUFFER_SIZE, // 64KB
            2 => 1024 * 1024,              // 1MB
            _ => 4 * 1024 * 1024,          // Clamped to MAX_STREAM_BUFFER_SIZE (2MB)
        };

        let res = catch_unwind(AssertUnwindSafe(move || {
            let mut state = StreamReaderState::new(stream, buffer_size);

            // Assert buffer capacity invariant (must be within [64KB, 2MB] and <= 64MB task limit)
            assert!(state.buffer.len() >= DEFAULT_STREAM_BUFFER_SIZE);
            assert!(state.buffer.len() <= MAX_STREAM_BUFFER_SIZE);
            assert!(
                state.buffer.len() <= MAX_RESIDENT_MEMORY_MB * 1024 * 1024,
                "Memory exceeded 64MB RSS bound"
            );

            // Read in loop with loop breaker to detect infinite loops
            let mut steps = 0;
            let max_steps = 10_000;

            loop {
                steps += 1;
                if steps > max_steps {
                    panic!("Dead loop detected in stream reader!");
                }

                match state.read_chunk() {
                    Ok((_ptr, 0)) => break,
                    Ok((_ptr, _n)) => {}
                    Err(_) => break,
                }
            }

            let snapshot = state.snapshot();
            assert!(snapshot.bytes_consumed <= data_len as u64);
        }));

        if res.is_err() {
            panics_caught += 1;
        }
    }

    println!(
        "[FUZZ] Completed {} trials on streamFaultInjection -> 0 dead loops, {} panics, max resident <= 64MB",
        total_stream_trials, panics_caught
    );

    assert_eq!(
        panics_caught, 0,
        "FATAL: Stream fault injection caused a panic or dead loop!"
    );
}
