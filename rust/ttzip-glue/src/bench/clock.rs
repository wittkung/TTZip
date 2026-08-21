// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Cross-platform high-resolution monotonic stopwatch and telemetry utilities.

use std::time::{Duration, Instant};

/// High-resolution monotonic stopwatch for micro-benchmarking and throughput profiling.
#[derive(Debug, Clone)]
pub struct MonotonicStopwatch {
    start_time: Instant,
    lap_marker: Instant,
}

impl Default for MonotonicStopwatch {
    fn default() -> Self {
        Self::new()
    }
}

impl MonotonicStopwatch {
    /// Creates and starts a new monotonic stopwatch.
    #[inline]
    pub fn new() -> Self {
        let now = Instant::now();
        Self {
            start_time: now,
            lap_marker: now,
        }
    }

    /// Alias for `new()`.
    #[inline]
    pub fn start() -> Self {
        Self::new()
    }

    /// Returns elapsed `Duration` since creation or last `reset`.
    #[inline]
    pub fn elapsed(&self) -> Duration {
        self.start_time.elapsed()
    }

    /// Returns elapsed time in nanoseconds.
    #[inline]
    pub fn elapsed_nanos(&self) -> u64 {
        self.start_time.elapsed().as_nanos() as u64
    }

    /// Returns elapsed time in microseconds as `f64`.
    #[inline]
    pub fn elapsed_micros(&self) -> f64 {
        self.start_time.elapsed().as_secs_f64() * 1_000_000.0
    }

    /// Returns elapsed time in milliseconds as `f64`.
    #[inline]
    pub fn elapsed_millis(&self) -> f64 {
        self.start_time.elapsed().as_secs_f64() * 1_000.0
    }

    /// Returns elapsed time in seconds as `f64`.
    #[inline]
    pub fn elapsed_secs(&self) -> f64 {
        self.start_time.elapsed().as_secs_f64()
    }

    /// Resets the stopwatch to current instant.
    #[inline]
    pub fn reset(&mut self) {
        let now = Instant::now();
        self.start_time = now;
        self.lap_marker = now;
    }

    /// Records a lap time: returns the duration since previous lap/start, and advances marker.
    #[inline]
    pub fn lap(&mut self) -> Duration {
        let now = Instant::now();
        let delta = now.duration_since(self.lap_marker);
        self.lap_marker = now;
        delta
    }

    /// Records lap time in seconds as `f64`.
    #[inline]
    pub fn lap_secs(&mut self) -> f64 {
        self.lap().as_secs_f64()
    }

    /// Calculates throughput in MB/s (1 MB = 1,048,576 bytes).
    #[inline]
    pub fn calc_throughput_mbs(bytes: usize, elapsed_secs: f64) -> f64 {
        if elapsed_secs <= 0.0 || bytes == 0 {
            return 0.0;
        }
        (bytes as f64 / (1024.0 * 1024.0)) / elapsed_secs
    }

    /// Calculates estimated CPU Cycles Per Byte (CPB) at a nominal clock frequency in GHz.
    #[inline]
    pub fn calc_cpb(bytes: usize, elapsed_secs: f64, freq_ghz: f64) -> f64 {
        if bytes == 0 || elapsed_secs <= 0.0 || freq_ghz <= 0.0 {
            return 0.0;
        }
        let total_cycles = elapsed_secs * freq_ghz * 1_000_000_000.0;
        total_cycles / (bytes as f64)
    }

    /// Calculates Instructions Per Cycle (IPC).
    #[inline]
    pub fn calc_ipc(total_instructions: usize, elapsed_secs: f64, freq_ghz: f64) -> f64 {
        if total_instructions == 0 || elapsed_secs <= 0.0 || freq_ghz <= 0.0 {
            return 0.0;
        }
        let total_cycles = elapsed_secs * freq_ghz * 1_000_000_000.0;
        (total_instructions as f64) / total_cycles
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::thread::sleep;

    #[test]
    fn test_monotonic_stopwatch_elapsed_and_reset() {
        let mut sw = MonotonicStopwatch::start();
        sleep(Duration::from_millis(5));
        let nanos = sw.elapsed_nanos();
        assert!(nanos > 0);
        let millis = sw.elapsed_millis();
        assert!(millis >= 4.0);

        sw.reset();
        assert!(sw.elapsed_nanos() < nanos);
    }

    #[test]
    fn test_monotonic_stopwatch_lap() {
        let mut sw = MonotonicStopwatch::new();
        sleep(Duration::from_millis(3));
        let lap1 = sw.lap_secs();
        assert!(lap1 > 0.0);
        sleep(Duration::from_millis(3));
        let lap2 = sw.lap_secs();
        assert!(lap2 > 0.0);
    }

    #[test]
    fn test_throughput_and_hardware_metrics() {
        let bytes = 10 * 1024 * 1024; // 10 MB
        let elapsed = 0.01; // 10ms -> 1000 MB/s
        let throughput = MonotonicStopwatch::calc_throughput_mbs(bytes, elapsed);
        assert!((throughput - 1000.0).abs() < 1e-3);

        let cpb = MonotonicStopwatch::calc_cpb(bytes, elapsed, 3.5);
        assert!(cpb > 0.0);

        let ipc = MonotonicStopwatch::calc_ipc(10_000_000, elapsed, 3.5);
        assert!(ipc > 0.0);
    }
}
