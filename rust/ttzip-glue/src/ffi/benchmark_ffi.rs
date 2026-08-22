// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! C-ABI FFI exports for hardware MIPS benchmarking, 50-point Matrix Gate, and Pareto visualization.

use std::ffi::{CString, c_char};
use std::panic::catch_unwind;
use std::ptr;
use std::slice;

use crate::benchmark::clock::MonotonicStopwatch;
use crate::benchmark::corpus::BenchmarkCorpusType;
use crate::benchmark::mips::{MIPSHardwareBenchmarkEngine, MIPSResult};
use crate::benchmark::pareto::{
    compute_codec_pareto_frontier_raw, compute_pareto_frontier_raw, ParetoPointRaw,
    TTZipParetoCodecPointRaw,
};
use crate::benchmark::plotter::BenchmarkPlotter;
use crate::benchmark::runner::BenchmarkMatrixRunner;
use crate::types::TTZipStatus;

/// Standardized C-ABI representation of MIPS benchmark metrics.
#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct TTZipMIPSBenchmarkResult {
    pub dictionary_size_mb: u32,
    pub thread_count: u32,
    pub compress_mips: f64,
    pub decompress_mips: f64,
    pub total_mips: f64,
    pub compress_speed_mbs: f64,
    pub decompress_speed_mbs: f64,
    pub cpu_usage_percent: f64,
    pub rating_per_usage_mips: f64,
}

impl From<MIPSResult> for TTZipMIPSBenchmarkResult {
    fn from(r: MIPSResult) -> Self {
        Self {
            dictionary_size_mb: r.dictionary_size_mb,
            thread_count: r.thread_count,
            compress_mips: r.compress_mips,
            decompress_mips: r.decompress_mips,
            total_mips: r.total_mips,
            compress_speed_mbs: r.compress_speed_mbs,
            decompress_speed_mbs: r.decompress_speed_mbs,
            cpu_usage_percent: r.cpu_usage_percent,
            rating_per_usage_mips: r.rating_per_usage_mips,
        }
    }
}

/// Standardized C-ABI representation of a 2D Pareto point.
pub type TTZipParetoPointRaw = ParetoPointRaw;

/// Executes a standardized 7-Zip aligned MIPS hardware benchmark pass.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_bench_run_mips(
    dictionary_size_mb: u32,
    thread_count: u32,
    iterations: u32,
    out_result: *mut TTZipMIPSBenchmarkResult,
) -> TTZipStatus {
    if out_result.is_null() {
        return TTZipStatus::ErrInvalidParam;
    }

    let result = catch_unwind(|| {
        match MIPSHardwareBenchmarkEngine::run_benchmark(dictionary_size_mb, thread_count, iterations) {
            Ok(metric) => {
                unsafe {
                    *out_result = metric.into();
                }
                TTZipStatus::Ok
            }
            Err(st) => st,
        }
    });

    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}

/// Calculates 2D Pareto frontier and Upper Convex Hull on codec points in-place.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_calculate_pareto_frontier(
    points: *mut TTZipParetoCodecPointRaw,
    count: usize,
) -> TTZipStatus {
    if points.is_null() && count > 0 {
        return TTZipStatus::ErrInvalidParam;
    }
    if count == 0 {
        return TTZipStatus::Ok;
    }

    let result = catch_unwind(|| {
        let slice = unsafe { slice::from_raw_parts_mut(points, count) };
        compute_codec_pareto_frontier_raw(slice);
        TTZipStatus::Ok
    });

    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}

/// Computes multi-tier Pareto ranks and 2D Upper Convex Hull on ParetoPointRaw in-place.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_bench_compute_pareto_frontier(
    points: *mut TTZipParetoPointRaw,
    count: usize,
) -> TTZipStatus {
    if points.is_null() && count > 0 {
        return TTZipStatus::ErrInvalidParam;
    }
    if count == 0 {
        return TTZipStatus::Ok;
    }

    let result = catch_unwind(|| {
        let slice = unsafe { slice::from_raw_parts_mut(points, count) };
        compute_pareto_frontier_raw(slice);
        TTZipStatus::Ok
    });

    result.unwrap_or(TTZipStatus::ErrPanicCaught)
}

/// Returns elapsed nanoseconds since an arbitrary monotonic baseline.
#[no_mangle]
pub extern "C" fn ttzip_rust_bench_monotonic_nanos() -> u64 {
    lazy_static_or_instant()
}

fn lazy_static_or_instant() -> u64 {
    use std::sync::OnceLock;
    static BASELINE: OnceLock<std::time::Instant> = OnceLock::new();
    let baseline = BASELINE.get_or_init(std::time::Instant::now);
    baseline.elapsed().as_nanos() as u64
}

/// Computes throughput in MB/s from byte count and elapsed seconds.
#[no_mangle]
pub extern "C" fn ttzip_rust_bench_calc_throughput_mbs(bytes: usize, elapsed_secs: f64) -> f64 {
    MonotonicStopwatch::calc_throughput_mbs(bytes, elapsed_secs)
}

/// Executes standard 50-point Matrix Gate pass. Returns 0 on success, non-zero on error.
#[no_mangle]
pub extern "C" fn ttzip_rust_bench_run_gate() -> i32 {
    let result = catch_unwind(|| {
        match BenchmarkMatrixRunner::run_gate() {
            Ok(report) if report.passed_gate => 0,
            Ok(_) => -1,
            Err(e) => e as i32,
        }
    });
    result.unwrap_or(-99)
}

/// Executes matrix benchmark for specified corpus and writes JSON string into buffer.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_bench_run_matrix(
    corpus_type: i32,
    out_json: *mut c_char,
    max_len: usize,
) -> i32 {
    if out_json.is_null() || max_len == 0 {
        return -1;
    }

    let result = catch_unwind(|| {
        let ct = BenchmarkCorpusType::from_i32(corpus_type);
        match BenchmarkMatrixRunner::run_matrix(ct, 64 * 1024, 1) {
            Ok(report) => match serde_json::to_string(&report) {
                Ok(json) => {
                    let bytes = json.as_bytes();
                    let copy_len = bytes.len().min(max_len - 1);
                    unsafe {
                        ptr::copy_nonoverlapping(bytes.as_ptr() as *const c_char, out_json, copy_len);
                        *out_json.add(copy_len) = 0;
                    }
                    copy_len as i32
                }
                Err(_) => -2,
            },
            Err(e) => e as i32,
        }
    });

    result.unwrap_or(-99)
}

/// Generates SVG vector scatter plot with Fritsch-Carlson Pareto spline.
/// Caller must free returned string via `ttzip_rust_bench_free_string`.
#[no_mangle]
pub extern "C" fn ttzip_rust_bench_generate_svg_pareto(
    corpus_type: i32,
    width: u32,
    height: u32,
) -> *mut c_char {
    let result = catch_unwind(|| {
        let ct = BenchmarkCorpusType::from_i32(corpus_type);
        match BenchmarkMatrixRunner::run_matrix(ct, 64 * 1024, 1) {
            Ok(report) => {
                let svg = BenchmarkPlotter::generate_svg(&report, width, height);
                CString::new(svg).map(|c| c.into_raw()).unwrap_or(ptr::null_mut())
            }
            Err(_) => ptr::null_mut(),
        }
    });

    result.unwrap_or(ptr::null_mut())
}

/// Generates standalone interactive HTML dashboard for matrix benchmark.
/// Caller must free returned string via `ttzip_rust_bench_free_string`.
#[no_mangle]
pub extern "C" fn ttzip_rust_bench_generate_html_dashboard(corpus_type: i32) -> *mut c_char {
    let result = catch_unwind(|| {
        let ct = BenchmarkCorpusType::from_i32(corpus_type);
        match BenchmarkMatrixRunner::run_matrix(ct, 64 * 1024, 1) {
            Ok(report) => {
                let html = BenchmarkPlotter::generate_html_dashboard(&report);
                CString::new(html).map(|c| c.into_raw()).unwrap_or(ptr::null_mut())
            }
            Err(_) => ptr::null_mut(),
        }
    });

    result.unwrap_or(ptr::null_mut())
}

/// Frees a C-string allocated by benchmark generators.
#[no_mangle]
pub unsafe extern "C" fn ttzip_rust_bench_free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        let _ = unsafe { CString::from_raw(ptr) };
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::ffi::CStr;

    #[test]
    fn test_ffi_matrix_and_gate_functions() {
        let gate_status = ttzip_rust_bench_run_gate();
        assert_eq!(gate_status, 0);

        let mut buf = vec![0 as c_char; 65536];
        let written = unsafe { ttzip_rust_bench_run_matrix(0, buf.as_mut_ptr(), buf.len()) };
        assert!(written > 0);
        let json_str = unsafe { CStr::from_ptr(buf.as_ptr()).to_str().expect("valid utf8") };
        assert!(json_str.contains("points"));
        assert!(json_str.contains("passed_gate"));

        let svg_ptr = ttzip_rust_bench_generate_svg_pareto(1, 800, 450);
        assert!(!svg_ptr.is_null());
        unsafe {
            let svg_str = CStr::from_ptr(svg_ptr).to_str().expect("valid utf8");
            assert!(svg_str.contains("<svg"));
            ttzip_rust_bench_free_string(svg_ptr);
        }

        let html_ptr = ttzip_rust_bench_generate_html_dashboard(2);
        assert!(!html_ptr.is_null());
        unsafe {
            let html_str = CStr::from_ptr(html_ptr).to_str().expect("valid utf8");
            assert!(html_str.contains("<!DOCTYPE html>"));
            ttzip_rust_bench_free_string(html_ptr);
        }
    }
}
