// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Testing utilities, SIMD binary hex diff engine, and deterministic fuzz mutation suite.

pub mod differential;
pub mod fuzz;
pub mod hex_diff;

pub use differential::*;
pub use fuzz::*;
pub use hex_diff::*;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_hex_diff_exact_match() {
        let a = b"Hello, World! 1234567890";
        let b = b"Hello, World! 1234567890";
        assert_eq!(find_first_difference(a, b), None);
        assert_eq!(generate_hex_diff(a, b, 256, false), None);
    }

    #[test]
    fn test_hex_diff_mismatch_detection() {
        let a = b"Hello, World! 1234567890";
        let b = b"Hello, World? 1234567890";
        assert_eq!(find_first_difference(a, b), Some(12));

        let diff = generate_hex_diff(a, b, 256, true);
        assert!(diff.is_some());
        let s = diff.unwrap();
        assert!(s.contains("Binary Mismatch"));
        assert!(s.contains("0x0000000C"));
    }

    #[test]
    fn test_hex_diff_simd_long_buffers() {
        let a = vec![0xAA; 1024];
        let mut b = vec![0xAA; 1024];
        b[513] = 0xBB;

        assert_eq!(find_first_difference(&a, &b), Some(513));
        let diff = generate_hex_diff(&a, &b, 256, false);
        assert!(diff.is_some());
    }

    #[test]
    fn test_splitmix64_determinism() {
        let mut prng1 = SplitMix64::new(0x123456789ABCDEF0);
        let mut prng2 = SplitMix64::new(0x123456789ABCDEF0);

        for _ in 0..100 {
            assert_eq!(prng1.next_u64(), prng2.next_u64());
        }
    }

    #[test]
    fn test_all_10_fuzz_operators() {
        let seed = 0xCAFEBABE_DEADBEEF;
        let original = b"PK\x03\x04\x14\x00\x00\x00\x08\x00\x00\x00\x00\x00\x12\x34\x56\x78\x20\x00\x00\x00\x20\x00\x00\x00\x08\x00\x00\x00test.txtHelloWorldFromTTZipTestingSuite1234567890";

        for op_idx in 0..10 {
            let op = MutationOperator::from_u32(op_idx).unwrap();
            let mut prng = SplitMix64::new(seed);
            let mutated = mutate_stream(original, op, &mut prng);

            // Repeat with same seed to verify bit-exact determinism
            let mut prng_repeat = SplitMix64::new(seed);
            let mutated_repeat = mutate_stream(original, op, &mut prng_repeat);
            assert_eq!(mutated, mutated_repeat, "Operator {:?} must be deterministic", op);
        }
    }
}
