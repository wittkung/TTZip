// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! RAII Safe Cleanup Guards for Libarchive pointers.

use super::sys::*;
use libc::c_void;

pub(crate) struct ArchiveReadGuard(pub *mut c_void);

impl Drop for ArchiveReadGuard {
    fn drop(&mut self) {
        if !self.0.is_null() {
            unsafe {
                archive_read_close(self.0);
                archive_read_free(self.0);
            }
            self.0 = std::ptr::null_mut();
        }
    }
}

pub(crate) struct ArchiveWriteGuard(pub *mut c_void);

impl Drop for ArchiveWriteGuard {
    fn drop(&mut self) {
        if !self.0.is_null() {
            unsafe {
                archive_write_close(self.0);
                archive_write_free(self.0);
            }
            self.0 = std::ptr::null_mut();
        }
    }
}

pub(crate) struct ArchiveEntryGuard(pub *mut c_void);

impl Drop for ArchiveEntryGuard {
    fn drop(&mut self) {
        if !self.0.is_null() {
            unsafe {
                archive_entry_free(self.0);
            }
            self.0 = std::ptr::null_mut();
        }
    }
}
