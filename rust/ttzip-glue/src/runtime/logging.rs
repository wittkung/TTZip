// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Structured logging router forwarding Rust `log` records to Swift `TTLogger` C callback.

use crate::types::{TTZipLogLevel, TTZipStatus};
use libc::{c_char, c_void};
use log::{Level, LevelFilter, Metadata, Record};
use std::ffi::CString;
use std::panic::catch_unwind;
use std::sync::atomic::{AtomicBool, AtomicPtr, AtomicU8, Ordering};

/// C-ABI callback for log dispatch.
pub type TTZipLogCallback = Option<
    unsafe extern "C" fn(
        level: TTZipLogLevel,
        target_module: *const c_char,
        message: *const c_char,
        file: *const c_char,
        line: i32,
        user_data: *mut c_void,
    ),
>;

struct LoggerGlobalState {
    callback: AtomicPtr<c_void>,
    user_data: AtomicPtr<c_void>,
    min_level: AtomicU8,
    is_installed: AtomicBool,
}

static LOGGER_STATE: LoggerGlobalState = LoggerGlobalState {
    callback: AtomicPtr::new(std::ptr::null_mut()),
    user_data: AtomicPtr::new(std::ptr::null_mut()),
    min_level: AtomicU8::new(TTZipLogLevel::Info as u8),
    is_installed: AtomicBool::new(false),
};

/// Logger implementation bridging Rust `log` crate to C-ABI callback.
pub struct TTZipLogger;

impl log::Log for TTZipLogger {
    fn enabled(&self, metadata: &Metadata) -> bool {
        let min_lvl = LOGGER_STATE.min_level.load(Ordering::Acquire);
        let record_lvl = match metadata.level() {
            Level::Error => TTZipLogLevel::Error as u8,
            Level::Warn => TTZipLogLevel::Warning as u8,
            Level::Info => TTZipLogLevel::Info as u8,
            Level::Debug | Level::Trace => TTZipLogLevel::Debug as u8,
        };
        record_lvl >= min_lvl
    }

    fn log(&self, record: &Record) {
        if !self.enabled(record.metadata()) {
            return;
        }

        let cb_ptr = LOGGER_STATE.callback.load(Ordering::Acquire);
        if cb_ptr.is_null() {
            return;
        }

        let user_data = LOGGER_STATE.user_data.load(Ordering::Acquire);
        let level = match record.level() {
            Level::Error => TTZipLogLevel::Error,
            Level::Warn => TTZipLogLevel::Warning,
            Level::Info => TTZipLogLevel::Info,
            Level::Debug | Level::Trace => TTZipLogLevel::Debug,
        };

        let target_str = record.target();
        let msg_str = format!("{}", record.args());
        let file_str = record.file().unwrap_or("");
        let line_num = record.line().unwrap_or(0) as i32;

        let target_c = CString::new(target_str).unwrap_or_default();
        let msg_c = CString::new(msg_str).unwrap_or_default();
        let file_c = CString::new(file_str).unwrap_or_default();

        let cb: unsafe extern "C" fn(
            TTZipLogLevel,
            *const c_char,
            *const c_char,
            *const c_char,
            i32,
            *mut c_void,
        ) = unsafe { std::mem::transmute(cb_ptr) };

        let _ = catch_unwind(|| unsafe {
            cb(
                level,
                target_c.as_ptr(),
                msg_c.as_ptr(),
                file_c.as_ptr(),
                line_num,
                user_data,
            );
        });
    }

    fn flush(&self) {}
}

static STATIC_LOGGER: TTZipLogger = TTZipLogger;

/// Configures global logger callback and minimum log level.
pub fn set_logger_callback(
    callback: TTZipLogCallback,
    min_level: TTZipLogLevel,
    user_data: *mut c_void,
) -> TTZipStatus {
    let cb_ptr = match callback {
        Some(cb) => cb as *mut c_void,
        None => std::ptr::null_mut(),
    };

    LOGGER_STATE.callback.store(cb_ptr, Ordering::Release);
    LOGGER_STATE.user_data.store(user_data, Ordering::Release);
    LOGGER_STATE.min_level.store(min_level as u8, Ordering::Release);

    if !LOGGER_STATE.is_installed.swap(true, Ordering::SeqCst) {
        let max_filter = match min_level {
            TTZipLogLevel::Debug => LevelFilter::Debug,
            TTZipLogLevel::Info => LevelFilter::Info,
            TTZipLogLevel::Warning => LevelFilter::Warn,
            TTZipLogLevel::Error => LevelFilter::Error,
        };
        let _ = log::set_logger(&STATIC_LOGGER);
        log::set_max_level(max_filter);
    } else {
        let max_filter = match min_level {
            TTZipLogLevel::Debug => LevelFilter::Debug,
            TTZipLogLevel::Info => LevelFilter::Info,
            TTZipLogLevel::Warning => LevelFilter::Warn,
            TTZipLogLevel::Error => LevelFilter::Error,
        };
        log::set_max_level(max_filter);
    }

    TTZipStatus::Ok
}

/// Directly sends a log event to the registered C callback.
pub fn emit_log_direct(
    level: TTZipLogLevel,
    target: &str,
    message: &str,
    file: &str,
    line: i32,
) {
    let cb_ptr = LOGGER_STATE.callback.load(Ordering::Acquire);
    if cb_ptr.is_null() {
        return;
    }

    let min_lvl = LOGGER_STATE.min_level.load(Ordering::Acquire);
    if (level as u8) < min_lvl {
        return;
    }

    let user_data = LOGGER_STATE.user_data.load(Ordering::Acquire);
    let target_c = CString::new(target).unwrap_or_default();
    let msg_c = CString::new(message).unwrap_or_default();
    let file_c = CString::new(file).unwrap_or_default();

    let cb: unsafe extern "C" fn(
        TTZipLogLevel,
        *const c_char,
        *const c_char,
        *const c_char,
        i32,
        *mut c_void,
    ) = unsafe { std::mem::transmute(cb_ptr) };

    let _ = catch_unwind(|| unsafe {
        cb(
            level,
            target_c.as_ptr(),
            msg_c.as_ptr(),
            file_c.as_ptr(),
            line,
            user_data,
        );
    });
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::AtomicUsize;

    static LOG_CALL_COUNT: AtomicUsize = AtomicUsize::new(0);

    unsafe extern "C" fn test_log_sink(
        level: TTZipLogLevel,
        target: *const c_char,
        msg: *const c_char,
        _file: *const c_char,
        _line: i32,
        _user_data: *mut c_void,
    ) {
        LOG_CALL_COUNT.fetch_add(1, Ordering::SeqCst);
        assert_eq!(level, TTZipLogLevel::Warning);
        let target_str = std::ffi::CStr::from_ptr(target).to_str().unwrap();
        let msg_str = std::ffi::CStr::from_ptr(msg).to_str().unwrap();
        assert_eq!(target_str, "test::module");
        assert_eq!(msg_str, "Disk space low warning");
    }

    #[test]
    fn test_logger_routing_to_c_callback() {
        LOG_CALL_COUNT.store(0, Ordering::SeqCst);
        let status = set_logger_callback(Some(test_log_sink), TTZipLogLevel::Debug, std::ptr::null_mut());
        assert_eq!(status, TTZipStatus::Ok);

        emit_log_direct(
            TTZipLogLevel::Warning,
            "test::module",
            "Disk space low warning",
            "logging.rs",
            42,
        );

        assert_eq!(LOG_CALL_COUNT.load(Ordering::SeqCst), 1);
    }
}
