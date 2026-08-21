// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! C-ABI FFI exports for Event-Driven Worker Pool.

use crate::runtime::worker_pool::{EventDrivenWorkerPool, WorkerPoolState};
use libc::c_void;
use std::panic::{catch_unwind, AssertUnwindSafe};

pub type TTZipWorkerPoolHandle = EventDrivenWorkerPool;
pub type TTZipWorkerTaskFn = Option<unsafe extern "C" fn(context: *mut c_void)>;

#[no_mangle]
pub extern "C" fn ttzip_rust_worker_pool_new(worker_count: u32) -> *mut TTZipWorkerPoolHandle {
    let result = catch_unwind(AssertUnwindSafe(|| {
        Box::into_raw(Box::new(EventDrivenWorkerPool::new(worker_count as usize)))
    }));
    result.unwrap_or(std::ptr::null_mut())
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_worker_pool_submit(
    handle: *mut TTZipWorkerPoolHandle,
    task_fn: TTZipWorkerTaskFn,
    context: *mut c_void,
) -> bool {
    let result = catch_unwind(AssertUnwindSafe(|| {
        if handle.is_null() {
            return false;
        }
        let Some(func) = task_fn else {
            return false;
        };
        let func_usize = func as usize;
        let ctx_usize = context as usize;

        (*handle).submit(move || {
            let real_fn: unsafe extern "C" fn(*mut c_void) = std::mem::transmute(func_usize);
            real_fn(ctx_usize as *mut c_void);
        })
    }));
    result.unwrap_or(false)
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_worker_pool_set_workers(
    handle: *mut TTZipWorkerPoolHandle,
    count: u32,
) {
    let _ = catch_unwind(AssertUnwindSafe(|| {
        if !handle.is_null() {
            (*handle).set_worker_count(count as usize);
        }
    }));
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_worker_pool_pause(handle: *mut TTZipWorkerPoolHandle) {
    let _ = catch_unwind(AssertUnwindSafe(|| {
        if !handle.is_null() {
            (*handle).pause();
        }
    }));
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_worker_pool_resume(handle: *mut TTZipWorkerPoolHandle) {
    let _ = catch_unwind(AssertUnwindSafe(|| {
        if !handle.is_null() {
            (*handle).resume();
        }
    }));
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_worker_pool_drain(handle: *mut TTZipWorkerPoolHandle) {
    let _ = catch_unwind(AssertUnwindSafe(|| {
        if !handle.is_null() {
            (*handle).drain();
        }
    }));
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_worker_pool_shutdown(handle: *mut TTZipWorkerPoolHandle) {
    let _ = catch_unwind(AssertUnwindSafe(|| {
        if !handle.is_null() {
            (*handle).shutdown();
        }
    }));
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_worker_pool_get_active_workers(
    handle: *const TTZipWorkerPoolHandle,
) -> u32 {
    let result = catch_unwind(AssertUnwindSafe(|| {
        if handle.is_null() {
            0
        } else {
            (*handle).active_workers() as u32
        }
    }));
    result.unwrap_or(0)
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_worker_pool_get_pending_tasks(
    handle: *const TTZipWorkerPoolHandle,
) -> u32 {
    let result = catch_unwind(AssertUnwindSafe(|| {
        if handle.is_null() {
            0
        } else {
            (*handle).pending_tasks() as u32
        }
    }));
    result.unwrap_or(0)
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_worker_pool_get_completed_tasks(
    handle: *const TTZipWorkerPoolHandle,
) -> u64 {
    let result = catch_unwind(AssertUnwindSafe(|| {
        if handle.is_null() {
            0
        } else {
            (*handle).completed_tasks()
        }
    }));
    result.unwrap_or(0)
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_worker_pool_get_failed_tasks(
    handle: *const TTZipWorkerPoolHandle,
) -> u64 {
    let result = catch_unwind(AssertUnwindSafe(|| {
        if handle.is_null() {
            0
        } else {
            (*handle).failed_tasks()
        }
    }));
    result.unwrap_or(0)
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_worker_pool_get_state(
    handle: *const TTZipWorkerPoolHandle,
) -> WorkerPoolState {
    let result = catch_unwind(AssertUnwindSafe(|| {
        if handle.is_null() {
            WorkerPoolState::Shutdown
        } else {
            (*handle).state()
        }
    }));
    result.unwrap_or(WorkerPoolState::Shutdown)
}

#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_worker_pool_free(handle: *mut TTZipWorkerPoolHandle) {
    let _ = catch_unwind(AssertUnwindSafe(|| {
        if !handle.is_null() {
            drop(Box::from_raw(handle));
        }
    }));
}
