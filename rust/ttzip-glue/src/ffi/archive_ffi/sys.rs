// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Libarchive raw C-ABI external symbols declarations.

use libc::{c_char, c_int, c_long, c_uint, c_void, mode_t, size_t, ssize_t, time_t};

extern "C" {
    pub(crate) fn archive_read_new() -> *mut c_void;
    pub(crate) fn archive_read_support_format_all(a: *mut c_void) -> c_int;
    pub(crate) fn archive_read_support_filter_all(a: *mut c_void) -> c_int;
    pub(crate) fn archive_read_add_passphrase(a: *mut c_void, passphrase: *const c_char) -> c_int;
    pub(crate) fn archive_read_open_filename(
        a: *mut c_void,
        filename: *const c_char,
        block_size: size_t,
    ) -> c_int;
    pub(crate) fn archive_read_next_header(a: *mut c_void, entry: *mut *mut c_void) -> c_int;
    pub(crate) fn archive_read_data(a: *mut c_void, buff: *mut c_void, len: size_t) -> ssize_t;
    pub(crate) fn archive_read_data_skip(a: *mut c_void) -> c_int;
    pub(crate) fn archive_read_close(a: *mut c_void) -> c_int;
    pub(crate) fn archive_read_free(a: *mut c_void) -> c_int;

    pub(crate) fn archive_entry_pathname(e: *mut c_void) -> *const c_char;
    pub(crate) fn archive_entry_size(e: *mut c_void) -> i64;
    pub(crate) fn archive_entry_filetype(e: *mut c_void) -> mode_t;
    pub(crate) fn archive_entry_mode(e: *mut c_void) -> mode_t;
    pub(crate) fn archive_entry_mtime(e: *mut c_void) -> time_t;
    pub(crate) fn archive_entry_symlink(e: *mut c_void) -> *const c_char;
    pub(crate) fn archive_entry_set_symlink(e: *mut c_void, symlink: *const c_char);
    pub(crate) fn archive_entry_is_data_encrypted(e: *mut c_void) -> c_int;
    pub(crate) fn archive_entry_is_metadata_encrypted(e: *mut c_void) -> c_int;

    pub(crate) fn archive_entry_new() -> *mut c_void;
    pub(crate) fn archive_entry_free(e: *mut c_void);
    pub(crate) fn archive_entry_set_pathname(e: *mut c_void, pathname: *const c_char);
    pub(crate) fn archive_entry_set_size(e: *mut c_void, size: i64);
    pub(crate) fn archive_entry_set_filetype(e: *mut c_void, filetype: c_uint);
    pub(crate) fn archive_entry_set_perm(e: *mut c_void, perm: mode_t);
    pub(crate) fn archive_entry_set_mtime(e: *mut c_void, mtime: time_t, nanos: c_long);

    pub(crate) fn archive_write_new() -> *mut c_void;
    pub(crate) fn archive_write_set_format_zip(a: *mut c_void) -> c_int;
    pub(crate) fn archive_write_set_format_pax_restricted(a: *mut c_void) -> c_int;
    pub(crate) fn archive_write_set_format_7zip(a: *mut c_void) -> c_int;
    pub(crate) fn archive_write_add_filter_gzip(a: *mut c_void) -> c_int;
    pub(crate) fn archive_write_add_filter_bzip2(a: *mut c_void) -> c_int;
    pub(crate) fn archive_write_add_filter_xz(a: *mut c_void) -> c_int;
    pub(crate) fn archive_write_add_filter_zstd(a: *mut c_void) -> c_int;
    pub(crate) fn archive_write_set_passphrase(a: *mut c_void, passphrase: *const c_char) -> c_int;
    pub(crate) fn archive_write_set_options(a: *mut c_void, opts: *const c_char) -> c_int;
    pub(crate) fn archive_write_open_filename(a: *mut c_void, filename: *const c_char) -> c_int;
    pub(crate) fn archive_write_header(a: *mut c_void, entry: *mut c_void) -> c_int;
    pub(crate) fn archive_write_data(a: *mut c_void, buff: *const c_void, len: size_t) -> ssize_t;
    pub(crate) fn archive_write_finish_entry(a: *mut c_void) -> c_int;
    pub(crate) fn archive_write_close(a: *mut c_void) -> c_int;
    pub(crate) fn archive_write_free(a: *mut c_void) -> c_int;
}
