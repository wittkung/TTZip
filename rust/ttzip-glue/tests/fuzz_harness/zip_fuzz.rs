// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Task T006: ZIP Central Directory, LFH & Extra Field Fuzzing.

use std::panic::{catch_unwind, AssertUnwindSafe};
use ttzip_glue::zip::extra::ZipExtraFields;
use ttzip_glue::zip::parser::{
    find_eocd, parse_all_entries, parse_cdfh_entry, parse_local_file_header,
};
use ttzip_glue::zip::reader::ZipArchive;

use super::common::{
    build_baseline_encrypted_zip, build_baseline_zip, fuzz_scale, mutate_bit_flip,
    mutate_byte_truncation, mutate_composite, mutate_corrupt_extra_field, mutate_corrupt_magic,
    mutate_offset_overflow, FuzzRng, MutationStrategy,
};

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
