// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! C-ABI FFI exports for hardware MIPS benchmarking, monotonic timing, and Pareto frontier optimization.

use std::panic::catch_unwind;
use std::slice;

use crate::bench::clock::MonotonicStopwatch;
use crate::bench::mips::{MIPSHardwareBenchmarkEngine, MIPSResult};
use crate::bench::pareto::{compute_pareto_frontier_raw, ParetoPointRaw};
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

/// Computes multi-tier Pareto ranks ($O(N \log K)$) and 2D Upper Convex Hull ($O(M \log M)$) in-place.
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_ffi_bench_run_mips() {
        let mut res = TTZipMIPSBenchmarkResult {
            dictionary_size_mb: 0,
            thread_count: 0,
            compress_mips: 0.0,
            decompress_mips: 0.0,
            total_mips: 0.0,
            compress_speed_mbs: 0.0,
            decompress_speed_mbs: 0.0,
            cpu_usage_percent: 0.0,
            rating_per_usage_mips: 0.0,
        };

        let status = unsafe { ttzip_rust_bench_run_mips(1, 1, 1, &mut res) };
        assert_eq!(status, TTZipStatus::Ok);
        assert!(res.total_mips > 0.0);
        assert_eq!(res.dictionary_size_mb, 1);
        assert_eq!(res.thread_count, 1);
    }

    #[test]
    fn test_ffi_bench_pareto() {
        let mut pts = [
            TTZipParetoPointRaw::new(1, 100.0, 50.0),
            TTZipParetoPointRaw::new(2, 200.0, 60.0),
            TTZipParetoPointRaw::new(3, 50.0, 80.0),
        ];

        let status = unsafe { ttzip_rust_bench_compute_pareto_frontier(pts.as_mut_ptr(), pts.len()) };
        assert_eq!(status, TTZipStatus::Ok);

        let p2 = pts.iter().find(|p| p.tag == 2).unwrap();
        assert!(p2.is_pareto_optimal);
    }

    #[test]
    fn test_ffi_bench_timing_and_throughput() {
        let nanos1 = ttzip_rust_bench_monotonic_nanos();
        std::thread::sleep(std::time::Duration::from_millis(2));
        let nanos2 = ttzip_rust_bench_monotonic_nanos();
        assert!(nanos2 > nanos1);
        let speed = ttzip_rust_bench_calc_throughput_mbs(1024 * 1024, 1.0);
        assert!((speed - 1.0).abs() < 1e-6);
    }
}
