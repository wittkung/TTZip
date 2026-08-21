// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Platform memory management, volatile zeroization, and CPU capability topology sniffing.

pub mod cpu;
pub mod memory;

pub use cpu::*;
pub use memory::*;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_secure_zeroize_and_buffer() {
        let mut buf = SecureBuffer::new(64).unwrap();
        buf.set_len(64);
        let slice = buf.as_mut_slice();
        slice.fill(0x5A);
        assert_eq!(slice[0], 0x5A);

        secure_zeroize(slice.as_mut_ptr(), slice.len());
        assert_eq!(slice[0], 0x00);
        assert_eq!(slice[63], 0x00);
    }

    #[test]
    fn test_cpu_capabilities_detection() {
        let caps = CpuCapabilities::get();
        assert!(caps.logical_cores > 0);
        assert!(caps.physical_page_size >= 4096);

        #[cfg(target_arch = "aarch64")]
        {
            assert_eq!(caps.architecture, "arm64");
            assert!(caps.has_arm_neon);
            assert!(caps.has_arm_crypto);
            assert!(caps.has_hardware_crc32);
        }
    }

    #[test]
    fn test_aligned_allocation_ffi() {
        unsafe {
            let ptr = ttzip_rust_alloc_aligned(16384, 65536);
            assert!(!ptr.is_null());
            assert_eq!((ptr as usize) % 16384, 0);

            std::ptr::write_bytes(ptr, 0xAB, 65536);
            assert_eq!(*ptr, 0xAB);

            ttzip_rust_secure_zeroize(ptr, 65536);
            assert_eq!(*ptr, 0x00);

            ttzip_rust_free_aligned(ptr, 16384, 65536);
        }
    }
}
