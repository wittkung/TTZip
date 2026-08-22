// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Task T007: 7z SignatureHeader, Varint & EncodedHeader Fuzzing.

use std::panic::{catch_unwind, AssertUnwindSafe};
use ttzip_glue::sevenz::{
    parse_7z_metadata, read_varint, write_varint, SevenZArchive, SevenZSignatureHeader,
};

use super::common::{
    build_baseline_7z, fuzz_scale, mutate_bit_flip, mutate_byte_truncation, mutate_composite,
    mutate_corrupt_magic, mutate_offset_overflow, FuzzRng,
};

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
    let sig_bytes = [
        0x37u8, 0x7A, 0xBC, 0xAF, 0x27, 0x1C, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
    ];

    for _ in 0..fuzz_scale(10_000) {
        let mut mutated = sig_bytes;
        mutate_bit_flip(&mut mutated, &mut rng);

        let res = catch_unwind(AssertUnwindSafe(|| {
            let _ = SevenZSignatureHeader::parse(&mutated);
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
