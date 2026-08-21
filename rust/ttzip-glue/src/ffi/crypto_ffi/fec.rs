// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! C-ABI / FFI export functions for Reed-Solomon FEC and self-healing recovery records.

use crate::crypto::rs_fec;
use crate::types::TTZipStatus;
use std::ffi::CStr;
use std::panic::catch_unwind;
use std::slice;

/// C-ABI exported Cauchy Reed-Solomon encoder over GF(2^8).
///
/// # Safety
/// - `data_ptrs` must point to `k_data` pointers to readable memory blocks of `block_size` bytes.
/// - `parity_ptrs` must point to `m_parity` pointers to writable memory blocks of `block_size` bytes.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_rs_encode(
    data_ptrs: *const *const u8,
    k_data: usize,
    parity_ptrs: *const *mut u8,
    m_parity: usize,
    block_size: usize,
) -> i32 {
    let result = catch_unwind(|| {
        if data_ptrs.is_null()
            || parity_ptrs.is_null()
            || k_data == 0
            || m_parity == 0
            || block_size == 0
        {
            return TTZipStatus::ErrInvalidParam.to_i32();
        }

        let rs = match rs_fec::ReedSolomonEngine::new(k_data, m_parity) {
            Ok(engine) => engine,
            Err(e) => return e.to_i32(),
        };

        let data_raw = slice::from_raw_parts(data_ptrs, k_data);
        let parity_raw = slice::from_raw_parts(parity_ptrs, m_parity);

        let mut data_slices = Vec::with_capacity(k_data);
        for &ptr in data_raw {
            if ptr.is_null() {
                return TTZipStatus::ErrInvalidParam.to_i32();
            }
            data_slices.push(slice::from_raw_parts(ptr, block_size));
        }

        let mut parity_slices = Vec::with_capacity(m_parity);
        for &ptr in parity_raw {
            if ptr.is_null() {
                return TTZipStatus::ErrInvalidParam.to_i32();
            }
            parity_slices.push(slice::from_raw_parts_mut(ptr, block_size));
        }

        match rs.encode(&data_slices, &mut parity_slices) {
            Ok(()) => TTZipStatus::Ok.to_i32(),
            Err(e) => e.to_i32(),
        }
    });

    result.unwrap_or(TTZipStatus::ErrPanicCaught.to_i32())
}

/// C-ABI exported Cauchy Reed-Solomon decoder over GF(2^8).
///
/// # Safety
/// - `available_ptrs` points to `num_available` buffer pointers of `block_size` bytes.
/// - `available_indices` points to `num_available` indices.
/// - `missing_indices` points to `num_missing` indices.
/// - `reconstructed_ptrs` points to `num_missing` writable buffer pointers of `block_size` bytes.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_rs_decode(
    available_ptrs: *const *const u8,
    available_indices: *const i32,
    num_available: usize,
    k_data: usize,
    m_parity: usize,
    missing_indices: *const i32,
    num_missing: usize,
    reconstructed_ptrs: *const *mut u8,
    block_size: usize,
) -> i32 {
    let result = catch_unwind(|| {
        if available_ptrs.is_null()
            || available_indices.is_null()
            || missing_indices.is_null()
            || reconstructed_ptrs.is_null()
            || num_available < k_data
            || num_missing == 0
            || block_size == 0
        {
            return TTZipStatus::ErrInvalidParam.to_i32();
        }

        let rs = match rs_fec::ReedSolomonEngine::new(k_data, m_parity) {
            Ok(engine) => engine,
            Err(e) => return e.to_i32(),
        };

        let avail_ptrs_slice = slice::from_raw_parts(available_ptrs, num_available);
        let avail_idx_slice = slice::from_raw_parts(available_indices, num_available);
        let miss_idx_slice = slice::from_raw_parts(missing_indices, num_missing);
        let recon_ptrs_slice = slice::from_raw_parts(reconstructed_ptrs, num_missing);

        let mut available_shards = Vec::with_capacity(num_available);
        let mut available_idxs = Vec::with_capacity(num_available);
        for i in 0..num_available {
            let ptr = avail_ptrs_slice[i];
            if ptr.is_null() || avail_idx_slice[i] < 0 {
                return TTZipStatus::ErrInvalidParam.to_i32();
            }
            available_shards.push(slice::from_raw_parts(ptr, block_size));
            available_idxs.push(avail_idx_slice[i] as usize);
        }

        let mut missing_idxs = Vec::with_capacity(num_missing);
        for &idx in miss_idx_slice {
            if idx < 0 {
                return TTZipStatus::ErrInvalidParam.to_i32();
            }
            missing_idxs.push(idx as usize);
        }

        let mut reconstructed_shards = Vec::with_capacity(num_missing);
        for &ptr in recon_ptrs_slice {
            if ptr.is_null() {
                return TTZipStatus::ErrInvalidParam.to_i32();
            }
            reconstructed_shards.push(slice::from_raw_parts_mut(ptr, block_size));
        }

        match rs.decode(
            &available_shards,
            &available_idxs,
            &missing_idxs,
            &mut reconstructed_shards,
        ) {
            Ok(()) => TTZipStatus::Ok.to_i32(),
            Err(e) => e.to_i32(),
        }
    });

    result.unwrap_or(TTZipStatus::ErrPanicCaught.to_i32())
}

/// C-ABI exported recovery record generator.
///
/// # Safety
/// - `payload` points to `payload_len` bytes.
/// - `out_record` receives the pointer to allocated record bytes on success.
/// - `out_record_len` receives the length of allocated bytes.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_rs_create_recovery_record(
    payload: *const u8,
    payload_len: usize,
    redundancy_percent: f64,
    slice_size: usize,
    out_record: *mut *mut u8,
    out_record_len: *mut usize,
) -> i32 {
    let result = catch_unwind(|| {
        if payload.is_null()
            || payload_len == 0
            || out_record.is_null()
            || out_record_len.is_null()
        {
            return TTZipStatus::ErrInvalidParam.to_i32();
        }

        let payload_slice = slice::from_raw_parts(payload, payload_len);
        match rs_fec::create_recovery_record(payload_slice, redundancy_percent, slice_size) {
            Ok(mut block) => {
                block.shrink_to_fit();
                *out_record_len = block.len();
                let ptr = block.as_mut_ptr();
                std::mem::forget(block);
                *out_record = ptr;
                TTZipStatus::Ok.to_i32()
            }
            Err(e) => e.to_i32(),
        }
    });

    result.unwrap_or(TTZipStatus::ErrPanicCaught.to_i32())
}

/// C-ABI exported in-place archive self-healing repair.
///
/// # Safety
/// - `archive_path` must be a valid null-terminated C string.
/// - `out_repaired` receives 1 if repaired or already intact, 0 on repair failure.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_rs_repair_archive(
    archive_path: *const libc::c_char,
    out_repaired: *mut bool,
) -> i32 {
    let result = catch_unwind(|| {
        if archive_path.is_null() {
            return TTZipStatus::ErrInvalidParam.to_i32();
        }

        let c_str = CStr::from_ptr(archive_path);
        let path_str = match c_str.to_str() {
            Ok(s) => s,
            Err(_) => return TTZipStatus::ErrInvalidParam.to_i32(),
        };

        match rs_fec::repair_archive_file(std::path::Path::new(path_str)) {
            Ok(repaired) => {
                if !out_repaired.is_null() {
                    *out_repaired = repaired;
                }
                TTZipStatus::Ok.to_i32()
            }
            Err(e) => e.to_i32(),
        }
    });

    result.unwrap_or(TTZipStatus::ErrPanicCaught.to_i32())
}

/// C-ABI free allocated recovery record buffer.
///
/// # Safety
/// - `ptr` must be a pointer returned by `ttzip_rust_rs_create_recovery_record` with size `len`.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_rs_free_buffer(ptr: *mut u8, len: usize) {
    if !ptr.is_null() && len > 0 {
        let _ = Vec::from_raw_parts(ptr, len, len);
    }
}
