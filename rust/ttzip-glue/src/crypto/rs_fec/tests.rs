// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#[cfg(test)]
mod tests {
    use crate::crypto::crc32::crc32_fast;
    use crate::crypto::rs_fec::cauchy::*;
    use crate::crypto::rs_fec::gf8::*;
    use crate::crypto::rs_fec::recovery_record::*;
    use crate::crypto::sha256::FastSha256;
    use tempfile::NamedTempFile;

    #[test]
    fn test_gf8_arithmetic_invariants() {
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

            assert_eq!(
                dst_simd, dst_scalar,
                "SIMD and scalar mismatch for coeff {}",
                coeff
            );
        }
    }

    #[test]
    fn test_cauchy_matrix_and_rs_encode_decode_roundtrip() {
        let k = 8;
        let m = 4;
        let slice_size = 1024;

        let rs = ReedSolomonEngine::new(k, m).expect("Failed to create RS engine");

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
    fn test_streaming_cauchy_accumulator_matches_batch() {
        let payload: Vec<u8> = (0..128 * 1024).map(|i| ((i * 19 + 7) & 0xFF) as u8).collect();
        let slice_size = 16384; // 16 KB -> 8 data shards
        let redundancy_percent = 25.0; // 2 parity shards

        let batch_block = create_recovery_record(&payload, redundancy_percent, slice_size)
            .expect("Batch creation failed");

        let mut cursor = std::io::Cursor::new(&payload);
        let (info, stream_block) = create_recovery_record_streaming(
            &mut cursor,
            payload.len() as u64,
            redundancy_percent,
            slice_size,
        )
        .expect("Streaming creation failed");

        assert_eq!(batch_block, stream_block, "Streaming and batch blocks must be identical");
        assert_eq!(info.data_slices_count, 8);
        assert_eq!(info.parity_slices_count, 2);
        assert_eq!(info.root_hash, FastSha256::digest(&payload));
    }

    #[test]
    fn test_32b_raw_binary_sha256_verification() {
        let payload = b"TTZip 2026 High-Performance Native Archiving with Streaming Cauchy RS-FEC!";
        let rec_block = create_recovery_record(payload, 20.0, 1024)
            .expect("Failed to create recovery record");

        let mut header_hash = [0u8; 32];
        header_hash.copy_from_slice(&rec_block[22..54]);

        let expected_hash = FastSha256::digest(payload);
        assert_eq!(header_hash, expected_hash, "32B header binary hash must match raw SHA-256");

        let mut archive = payload.to_vec();
        archive.extend_from_slice(&rec_block);
        let info = inspect_recovery_record(&archive).unwrap().unwrap();
        assert_eq!(info.root_hash, expected_hash);
        assert_eq!(info.root_hash_hex(), bytes_to_hex(&expected_hash));
    }

    #[test]
    fn test_recovery_record_roundtrip_and_self_healing() {
        let original_payload: Vec<u8> = (0..128 * 1024)
            .map(|i| ((i * 17 + 5) & 0xFF) as u8)
            .collect();
        let slice_size = 16384;

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

        let intact_res = repair_archive_data(&mut archive_with_fec).expect("Repair check failed");
        assert!(intact_res);

        // Corrupt slice 2 and slice 5
        let corrupt_offset_1 = 2 * slice_size + 128;
        for i in 0..256 {
            archive_with_fec[corrupt_offset_1 + i] ^= 0xAA;
        }
        let corrupt_offset_2 = 5 * slice_size + 64;
        for i in 0..512 {
            archive_with_fec[corrupt_offset_2 + i] ^= 0x55;
        }

        let repair_res = repair_archive_data(&mut archive_with_fec).expect("Repair failed");
        assert!(repair_res, "Archive repair should succeed");

        let restored_payload = &archive_with_fec[..original_payload.len()];
        assert_eq!(restored_payload, &original_payload[..]);
        assert_eq!(
            crc32_fast(0, restored_payload),
            crc32_fast(0, &original_payload)
        );
    }

    #[test]
    fn test_streaming_file_repair_in_place_self_healing() {
        let original_payload: Vec<u8> = (0..256 * 1024)
            .map(|i| ((i * 23 + 11) & 0xFF) as u8)
            .collect();
        let slice_size = 32768; // 32 KB -> 8 data shards

        let mut file = NamedTempFile::new().unwrap();
        std::io::Write::write_all(&mut file, &original_payload).unwrap();
        let path = file.path().to_path_buf();

        let info = append_recovery_record_to_file(&path, 25.0, slice_size)
            .expect("Append recovery record failed");
        assert_eq!(info.data_slices_count, 8);
        assert_eq!(info.parity_slices_count, 2);

        // Intact check
        let intact = repair_archive_file_streaming(&path).expect("Intact repair failed");
        assert!(intact);

        // Corrupt shard 1 and shard 6 on disk
        let mut file_bytes = std::fs::read(&path).unwrap();
        for i in 0..500 {
            file_bytes[1 * slice_size + 10 + i] ^= 0xEF;
            file_bytes[6 * slice_size + 20 + i] ^= 0xBE;
        }
        std::fs::write(&path, &file_bytes).unwrap();

        // Perform streaming in-place self-healing repair
        let repair_ok = repair_archive_file_streaming(&path).expect("Repair failed");
        assert!(repair_ok, "In-place repair must succeed");

        let repaired_bytes = std::fs::read(&path).unwrap();
        let restored_payload = &repaired_bytes[..original_payload.len()];
        assert_eq!(restored_payload, &original_payload[..]);
        assert_eq!(FastSha256::digest(restored_payload), info.root_hash);
    }

    #[test]
    fn test_streaming_repair_fails_gracefully_when_corruption_exceeds_redundancy() {
        let original_payload: Vec<u8> = (0..128 * 1024)
            .map(|i| ((i * 31 + 3) & 0xFF) as u8)
            .collect();
        let slice_size = 16384; // 8 shards, 1 parity (15% of 8 = 2 parity or 12.5% = 1 parity)

        let mut file = NamedTempFile::new().unwrap();
        std::io::Write::write_all(&mut file, &original_payload).unwrap();
        let path = file.path().to_path_buf();

        append_recovery_record_to_file(&path, 12.5, slice_size).unwrap();

        // Corrupt 3 shards when only 1 parity shard exists
        let mut file_bytes = std::fs::read(&path).unwrap();
        for s in [0, 2, 4] {
            for i in 0..100 {
                file_bytes[s * slice_size + i] ^= 0xFF;
            }
        }
        std::fs::write(&path, &file_bytes).unwrap();

        let res = repair_archive_file_streaming(&path).unwrap();
        assert!(!res, "Repair should return false when corruption exceeds M");
    }
}
