// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! CPU architecture sniffing, SIMD feature detection, and dynamic P/E-core topology.

use crate::types::TTZipStatus;
use std::panic::catch_unwind;
use std::sync::OnceLock;

/// C-compatible raw CPU capabilities descriptor.
#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct TTZipCpuCapsRaw {
    pub logical_cores: u32,
    pub physical_page_size: usize,
    pub p_cores: u32,
    pub e_cores: u32,
    pub has_arm_neon: bool,
    pub has_arm_crypto: bool,
    pub has_aes_ni: bool,
    pub has_avx2: bool,
    pub has_avx512: bool,
    pub has_hardware_crc32: bool,
}

/// Dynamic CPU feature set and topology.
#[derive(Debug, Clone)]
pub struct CpuCapabilities {
    pub architecture: &'static str,
    pub logical_cores: u32,
    pub physical_page_size: usize,
    pub p_cores: u32,
    pub e_cores: u32,
    pub has_arm_neon: bool,
    pub has_arm_crypto: bool,
    pub has_aes_ni: bool,
    pub has_avx2: bool,
    pub has_avx512: bool,
    pub has_hardware_crc32: bool,
}

static CPU_CAPS: OnceLock<CpuCapabilities> = OnceLock::new();

impl CpuCapabilities {
    /// Returns the cached singleton CPU capabilities.
    pub fn get() -> &'static CpuCapabilities {
        CPU_CAPS.get_or_init(Self::detect)
    }

    fn detect() -> Self {
        #[cfg(target_os = "macos")]
        let (p_cores, e_cores, total_cores, page_size) = {
            let total = sysctl_u32("hw.ncpu").unwrap_or(1);
            let p = sysctl_u32("hw.perflevel0.logicalcpu").unwrap_or(total);
            let e = sysctl_u32("hw.perflevel1.logicalcpu").unwrap_or(0);
            let ps = sysctl_u32("hw.pagesize").map(|p| p as usize).unwrap_or(16384);
            (p, e, total, ps)
        };

        #[cfg(not(target_os = "macos"))]
        let (p_cores, e_cores, total_cores, page_size) = {
            let total = std::thread::available_parallelism()
                .map(|p| p.get() as u32)
                .unwrap_or(1);
            (total, 0, total, 4096)
        };

        #[cfg(target_arch = "aarch64")]
        {
            Self {
                architecture: "arm64",
                logical_cores: total_cores,
                physical_page_size: page_size,
                p_cores,
                e_cores,
                has_arm_neon: true,
                has_arm_crypto: true,
                has_aes_ni: true,
                has_avx2: false,
                has_avx512: false,
                has_hardware_crc32: true,
            }
        }

        #[cfg(target_arch = "x86_64")]
        {
            Self {
                architecture: "x86_64",
                logical_cores: total_cores,
                physical_page_size: page_size,
                p_cores,
                e_cores,
                has_arm_neon: false,
                has_arm_crypto: false,
                has_aes_ni: is_x86_feature_detected!("aes"),
                has_avx2: is_x86_feature_detected!("avx2"),
                has_avx512: is_x86_feature_detected!("avx512f"),
                has_hardware_crc32: is_x86_feature_detected!("sse4.2"),
            }
        }

        #[cfg(not(any(target_arch = "aarch64", target_arch = "x86_64")))]
        {
            Self {
                architecture: "unknown",
                logical_cores: total_cores,
                physical_page_size: page_size,
                p_cores,
                e_cores,
                has_arm_neon: false,
                has_arm_crypto: false,
                has_aes_ni: false,
                has_avx2: false,
                has_avx512: false,
                has_hardware_crc32: false,
            }
        }
    }
}

#[cfg(target_os = "macos")]
fn sysctl_u32(name: &str) -> Option<u32> {
    use std::ffi::CString;
    let c_name = CString::new(name).ok()?;
    let mut val: u32 = 0;
    let mut size = std::mem::size_of::<u32>();
    let ret = unsafe {
        libc::sysctlbyname(
            c_name.as_ptr(),
            &mut val as *mut _ as *mut libc::c_void,
            &mut size,
            std::ptr::null_mut(),
            0,
        )
    };
    if ret == 0 {
        Some(val)
    } else {
        None
    }
}

/// C-ABI: Retrieves hardware capabilities.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_cpu_get_capabilities(out_caps: *mut TTZipCpuCapsRaw) -> TTZipStatus {
    let result = catch_unwind(|| {
        if out_caps.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }
        let caps = CpuCapabilities::get();
        *out_caps = TTZipCpuCapsRaw {
            logical_cores: caps.logical_cores,
            physical_page_size: caps.physical_page_size,
            p_cores: caps.p_cores,
            e_cores: caps.e_cores,
            has_arm_neon: caps.has_arm_neon,
            has_arm_crypto: caps.has_arm_crypto,
            has_aes_ni: caps.has_aes_ni,
            has_avx2: caps.has_avx2,
            has_avx512: caps.has_avx512,
            has_hardware_crc32: caps.has_hardware_crc32,
        };
        TTZipStatus::Ok
    });
    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}

/// C-ABI: Retrieves P-core, E-core, and total core topology counts.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_cpu_get_topology(
    out_p_cores: *mut u32,
    out_e_cores: *mut u32,
    out_total_cores: *mut u32,
) -> TTZipStatus {
    let result = catch_unwind(|| {
        let caps = CpuCapabilities::get();
        if !out_p_cores.is_null() {
            *out_p_cores = caps.p_cores;
        }
        if !out_e_cores.is_null() {
            *out_e_cores = caps.e_cores;
        }
        if !out_total_cores.is_null() {
            *out_total_cores = caps.logical_cores;
        }
        TTZipStatus::Ok
    });
    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}
