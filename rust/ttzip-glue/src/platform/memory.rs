// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Dead-Store Elimination immune memory sanitization, RAII SecureBuffer, and aligned allocations.

use crate::types::TTZipStatus;
use std::alloc::{alloc, dealloc, Layout};
use std::panic::catch_unwind;
use std::sync::atomic::{compiler_fence, Ordering};

/// Erases sensitive memory with volatile writes and sequentially consistent compiler fence.
#[inline]
pub fn secure_zeroize(ptr: *mut u8, len: usize) {
    if ptr.is_null() || len == 0 {
        return;
    }
    unsafe {
        for i in 0..len {
            std::ptr::write_volatile(ptr.add(i), 0);
        }
        compiler_fence(Ordering::SeqCst);
    }
}

/// RAII secure heap buffer with automatic volatile zeroize-on-drop.
pub struct SecureBuffer {
    ptr: *mut u8,
    len: usize,
    capacity: usize,
    layout: Layout,
}

unsafe impl Send for SecureBuffer {}
unsafe impl Sync for SecureBuffer {}

impl SecureBuffer {
    /// Allocates a new zeroed secure memory buffer.
    pub fn new(capacity: usize) -> Option<Self> {
        if capacity == 0 {
            return Some(Self {
                ptr: std::ptr::NonNull::dangling().as_ptr(),
                len: 0,
                capacity: 0,
                layout: Layout::from_size_align(0, 1).unwrap(),
            });
        }
        let layout = Layout::from_size_align(capacity, 16).ok()?;
        let ptr = unsafe { alloc(layout) };
        if ptr.is_null() {
            return None;
        }
        unsafe {
            std::ptr::write_bytes(ptr, 0, capacity);
        }
        Some(Self {
            ptr,
            len: 0,
            capacity,
            layout,
        })
    }

    #[inline]
    pub fn as_slice(&self) -> &[u8] {
        if self.len == 0 || self.ptr.is_null() {
            &[]
        } else {
            unsafe { std::slice::from_raw_parts(self.ptr, self.len) }
        }
    }

    #[inline]
    pub fn as_mut_slice(&mut self) -> &mut [u8] {
        if self.len == 0 || self.ptr.is_null() {
            &mut []
        } else {
            unsafe { std::slice::from_raw_parts_mut(self.ptr, self.len) }
        }
    }

    #[inline]
    pub fn len(&self) -> usize {
        self.len
    }

    #[inline]
    pub fn is_empty(&self) -> bool {
        self.len == 0
    }

    #[inline]
    pub fn capacity(&self) -> usize {
        self.capacity
    }

    #[inline]
    pub fn set_len(&mut self, new_len: usize) {
        assert!(new_len <= self.capacity);
        self.len = new_len;
    }
}

impl Drop for SecureBuffer {
    fn drop(&mut self) {
        if self.capacity > 0 && !self.ptr.is_null() {
            secure_zeroize(self.ptr, self.capacity);
            unsafe {
                dealloc(self.ptr, self.layout);
            }
            self.ptr = std::ptr::null_mut();
        }
    }
}

/// C-ABI: Erases sensitive memory (passwords, crypto keys, cipher contexts).
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_secure_zeroize(ptr: *mut u8, len: usize) {
    secure_zeroize(ptr, len);
}

/// C-ABI: Allocates page-aligned heap buffer.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_alloc_aligned(alignment: usize, size: usize) -> *mut u8 {
    let result = catch_unwind(|| {
        if size == 0 || alignment == 0 || !alignment.is_power_of_two() {
            return std::ptr::null_mut();
        }
        let layout = match Layout::from_size_align(size, alignment) {
            Ok(l) => l,
            Err(_) => return std::ptr::null_mut(),
        };
        alloc(layout)
    });
    result.unwrap_or(std::ptr::null_mut())
}

/// C-ABI: Deallocates aligned memory previously allocated by `ttzip_rust_alloc_aligned`.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_free_aligned(ptr: *mut u8, alignment: usize, size: usize) {
    let _ = catch_unwind(|| {
        if !ptr.is_null() && size > 0 && alignment > 0 && alignment.is_power_of_two() {
            if let Ok(layout) = Layout::from_size_align(size, alignment) {
                dealloc(ptr, layout);
            }
        }
    });
}

/// C-ABI: Queries process RSS, peak RSS, and virtual memory snapshot.
#[no_mangle]
#[allow(deprecated)]
pub unsafe extern "C" fn ttzip_rust_memory_usage(
    out_current_rss: *mut u64,
    out_peak_rss: *mut u64,
    out_virtual_size: *mut u64,
) -> TTZipStatus {
    let result = catch_unwind(|| {
        if out_current_rss.is_null() || out_peak_rss.is_null() || out_virtual_size.is_null() {
            return TTZipStatus::ErrInvalidParam;
        }

        #[cfg(target_os = "macos")]
        {
            #[allow(deprecated)]
            use libc::{integer_t, mach_msg_type_number_t, mach_task_self, natural_t, task_info, KERN_SUCCESS};

            #[repr(C)]
            struct mach_task_basic_info {
                virtual_size: u64,
                resident_size: u64,
                resident_size_max: u64,
                user_time: [i32; 2],
                system_time: [i32; 2],
                policy: i32,
                suspend_count: i32,
            }
            const MACH_TASK_BASIC_INFO: u32 = 20;

            let mut info: mach_task_basic_info = std::mem::zeroed();
            let mut count = (std::mem::size_of::<mach_task_basic_info>() / std::mem::size_of::<natural_t>()) as mach_msg_type_number_t;
            let ret = task_info(
                mach_task_self(),
                MACH_TASK_BASIC_INFO,
                &mut info as *mut _ as *mut integer_t,
                &mut count,
            );

            if ret == KERN_SUCCESS {
                *out_current_rss = info.resident_size;
                *out_peak_rss = info.resident_size_max;
                *out_virtual_size = info.virtual_size;
                return TTZipStatus::Ok;
            }
        }

        #[cfg(not(target_os = "macos"))]
        {
            let mut usage: libc::rusage = std::mem::zeroed();
            if libc::getrusage(libc::RUSAGE_SELF, &mut usage) == 0 {
                let bytes = (usage.ru_maxrss.max(0) as u64) * 1024;
                *out_current_rss = bytes;
                *out_peak_rss = bytes;
                *out_virtual_size = 0;
                return TTZipStatus::Ok;
            }
        }

        *out_current_rss = 0;
        *out_peak_rss = 0;
        *out_virtual_size = 0;
        TTZipStatus::Ok
    });
    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}
