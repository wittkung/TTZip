// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#[cfg(test)]
mod tests {
    use crate::crypto::rs_fec::cauchy::*;
    use crate::crypto::rs_fec::gf8::*;
    use crate::crypto::rs_fec::recovery_record::*;
    use crate::crypto::crc32::crc32_fast;

    #[test]
    fn test_gf8_arithmetic_invariants() {
        // Identity: a * 1 == a, a * 0 == 0
        for a in 0..=255u8 {
            assert_eq!(gf_mul(a, 1), a);
            assert_eq!(gf_mul(a, 0), 0);
            assert_eq!(gf_add(a, 0), a);
            assert_eq!(gf_sub(a, a), 0);
            if a != 0 {
                let inv = gf_inv(a);
                assert_eq!(gf_mul(a, inv), 1, "Inverse check failed for {}", a);
                assert_eq!(gf_div(a, a), 1);
            }
        }
    }

    #[test]
    fn test_gf8_nibble_simd_matches_scalar() {
        for coeff in [1u8, 2, 7, 19, 42, 128, 255] {
            let mut src = vec![0u8; 1024];
            for (i, b) in src.iter_mut().enumerate() {
                *b = (i * 37 + 13) as u8;
            }
            let mut dst_simd = vec![0x55u8; 1024];
            let mut dst_scalar = vec![0x55u8; 1024];

            scalar_gf8_mul_add_raw(coeff, &src, &mut dst_scalar, 1024);
            gf8_mul_add_slice(coeff, &src, &mut dst_simd);

            assert_eq!(dst_simd, dst_scalar, "SIMD and scalar mismatch for coeff {}", coeff);
        }
    }

    #[test]
    fn test_cauchy_matrix_and_rs_encode_decode_roundtrip() {
        let k = 8;
        let m = 4;
        let slice_size = 1024;

        let rs = ReedSolomonEngine::new(k, m).expect("Failed to create RS engine");

        // Prepare K data slices
        let mut data_slices = Vec::new();
        for i in 0..k {
            let slice = (0..slice_size)
                .map(|b| ((b + i * 41) & 0xFF) as u8)
                .collect::<Vec<u8>>();
            data_slices.push(slice);
        }

        let mut parity_slices = vec![vec![0u8; slice_size]; m];
        let data_refs: Vec<&[u8]> = data_slices.iter().map(|s| s.as_slice()).collect();
        let mut parity_muts: Vec<&mut [u8]> =
            parity_slices.iter_mut().map(|s| s.as_mut_slice()).collect();

        rs.encode(&data_refs, &mut parity_muts)
            .expect("Encode failed");

        // Simulate 4 erasures: drop data slices 1, 3, 6, and parity 0
        // Available: data 0, 2, 4, 5, 7 and parities 1, 2, 3 (total 8 shards)
        let available_indices = vec![0, 2, 4, 5, 7, k + 1, k + 2, k + 3];
        let available_shards = vec![
            data_slices[0].as_slice(),
            data_slices[2].as_slice(),
            data_slices[4].as_slice(),
            data_slices[5].as_slice(),
            data_slices[7].as_slice(),
            parity_slices[1].as_slice(),
            parity_slices[2].as_slice(),
            parity_slices[3].as_slice(),
        ];

        let missing_indices = vec![1, 3, 6];
        let mut reconstructed = vec![vec![0u8; slice_size]; missing_indices.len()];
        let mut recon_muts: Vec<&mut [u8]> =
            reconstructed.iter_mut().map(|s| s.as_mut_slice()).collect();

        rs.decode(
            &available_shards,
            &available_indices,
            &missing_indices,
            &mut recon_muts,
        )
        .expect("Decode failed");

        assert_eq!(reconstructed[0], data_slices[1]);
        assert_eq!(reconstructed[1], data_slices[3]);
        assert_eq!(reconstructed[2], data_slices[6]);
    }

    #[test]
    fn test_recovery_record_roundtrip_and_self_healing() {
        let original_payload: Vec<u8> = (0..128 * 1024)
            .map(|i| ((i * 17 + 5) & 0xFF) as u8)
            .collect();
        let slice_size = 16384; // 16 KB -> 8 data shards

        let rec_block = create_recovery_record(&original_payload, 25.0, slice_size)
            .expect("Failed to create recovery record");

        let mut archive_with_fec = original_payload.clone();
        archive_with_fec.extend_from_slice(&rec_block);

        let info = inspect_recovery_record(&archive_with_fec)
            .expect("Inspect failed")
            .expect("No recovery record found");

        assert_eq!(info.slice_size, slice_size);
        assert_eq!(info.data_slices_count, 8);
        assert_eq!(info.protected_payload_length, original_payload.len() as u64);

        // Intact archive returns true without modification
        let intact_res = repair_archive_data(&mut archive_with_fec).expect("Repair check failed");
        assert!(intact_res);

        // Corrupt 2 data slices: slice 2 and slice 5
        let corrupt_offset_1 = 2 * slice_size + 128;
        for i in 0..256 {
            archive_with_fec[corrupt_offset_1 + i] ^= 0xAA;
        }

        let corrupt_offset_2 = 5 * slice_size + 64;
        for i in 0..512 {
            archive_with_fec[corrupt_offset_2 + i] ^= 0x55;
        }

        // Repair corrupt archive
        let repair_res = repair_archive_data(&mut archive_with_fec).expect("Repair failed");
        assert!(repair_res, "Archive repair should succeed");

        // Verify repaired data matches original exactly
        let restored_payload = &archive_with_fec[..original_payload.len()];
        assert_eq!(restored_payload, &original_payload[..]);
        assert_eq!(
            crc32_fast(0, restored_payload),
            crc32_fast(0, &original_payload)
        );
    }
}
