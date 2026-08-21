// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

use libc::c_void;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Arc;
use ttzip_glue::ffi::*;

#[test]
fn test_ffi_spsc_ring_buffer() {
    unsafe {
        let handle = ttzip_rust_spsc_ring_buffer_new(8);
        assert!(!handle.is_null());
        assert_eq!(ttzip_rust_spsc_ring_buffer_capacity(handle), 8);
        assert!(ttzip_rust_spsc_ring_buffer_is_empty(handle));
        assert_eq!(ttzip_rust_spsc_ring_buffer_count(handle), 0);

        for i in 1..=8 {
            let item = i as *mut c_void;
            assert!(ttzip_rust_spsc_ring_buffer_push(handle, item));
        }

        assert!(ttzip_rust_spsc_ring_buffer_is_full(handle));
        assert!(!ttzip_rust_spsc_ring_buffer_push(handle, 999 as *mut c_void));

        for i in 1..=8 {
            let popped = ttzip_rust_spsc_ring_buffer_pop(handle);
            assert_eq!(popped as usize, i);
        }

        assert!(ttzip_rust_spsc_ring_buffer_is_empty(handle));
        assert_eq!(ttzip_rust_spsc_ring_buffer_pop(handle), std::ptr::null_mut());

        ttzip_rust_spsc_ring_buffer_free(handle);
    }
}

#[test]
fn test_ffi_mpmc_ring_buffer() {
    unsafe {
        let handle = ttzip_rust_mpmc_ring_buffer_new(4);
        assert!(!handle.is_null());
        assert_eq!(ttzip_rust_mpmc_ring_buffer_capacity(handle), 4);
        assert!(ttzip_rust_mpmc_ring_buffer_is_empty(handle));

        for i in 1..=4 {
            assert!(ttzip_rust_mpmc_ring_buffer_push(handle, (i * 10) as *mut c_void));
        }

        assert!(ttzip_rust_mpmc_ring_buffer_is_full(handle));
        assert!(!ttzip_rust_mpmc_ring_buffer_push(handle, 50 as *mut c_void));

        for i in 1..=4 {
            let popped = ttzip_rust_mpmc_ring_buffer_pop(handle);
            assert_eq!(popped as usize, i * 10);
        }

        assert!(ttzip_rust_mpmc_ring_buffer_is_empty(handle));
        ttzip_rust_mpmc_ring_buffer_free(handle);
    }
}

struct TaskPayload {
    counter: Arc<AtomicUsize>,
    increment: usize,
}

unsafe extern "C" fn worker_task_callback(context: *mut c_void) {
    let payload = Box::from_raw(context as *mut TaskPayload);
    payload.counter.fetch_add(payload.increment, Ordering::SeqCst);
}

#[test]
fn test_ffi_worker_pool_lifecycle() {
    unsafe {
        let handle = ttzip_rust_worker_pool_new(4);
        assert!(!handle.is_null());

        let counter = Arc::new(AtomicUsize::new(0));
        let num_tasks = 50;

        for _ in 0..num_tasks {
            let payload = Box::into_raw(Box::new(TaskPayload {
                counter: Arc::clone(&counter),
                increment: 2,
            }));
            assert!(ttzip_rust_worker_pool_submit(
                handle,
                Some(worker_task_callback),
                payload as *mut c_void,
            ));
        }

        ttzip_rust_worker_pool_drain(handle);
        assert_eq!(counter.load(Ordering::SeqCst), num_tasks * 2);
        assert_eq!(
            ttzip_rust_worker_pool_get_completed_tasks(handle),
            num_tasks as u64
        );
        assert_eq!(ttzip_rust_worker_pool_get_failed_tasks(handle), 0);
        assert_eq!(ttzip_rust_worker_pool_get_pending_tasks(handle), 0);

        ttzip_rust_worker_pool_set_workers(handle, 2);
        ttzip_rust_worker_pool_shutdown(handle);
        ttzip_rust_worker_pool_free(handle);
    }
}
