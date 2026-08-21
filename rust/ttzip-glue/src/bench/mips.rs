// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! 7-Zip aligned MIPS hardware benchmark engine with 16KB page-aligned buffers.

use crate::bench::clock::MonotonicStopwatch;
use crate::codecs::deflate::{DeflateCompressor, DeflateDecompressor};
use crate::fs::apfs::AlignedBuffer;
use crate::types::TTZipStatus;

/// 64-bit deterministic SplitMix64 PRNG for synthetic compressible benchmark stream generation.
#[derive(Debug, Clone)]
pub struct SplitMix64 {
    state: u64,
}

impl SplitMix64 {
    #[inline]
    pub fn new(seed: u64) -> Self {
        Self { state: seed }
    }

    #[inline]
    pub fn next_u64(&mut self) -> u64 {
        self.state = self.state.wrapping_add(0x9e3779b97f4a7c15);
        let mut z = self.state;
        z = (z ^ (z >> 30)).wrapping_mul(0xbf58476d1ce4e5b9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94d049bb133111eb);
        z ^ (z >> 31)
    }
}

/// Standardized 7-Zip aligned MIPS hardware benchmark telemetry and scores.
#[repr(C)]
#[derive(Debug, Clone, PartialEq)]
pub struct MIPSResult {
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

/// Hardware performance benchmark engine based on 7-Zip complexity formulas.
pub struct MIPSHardwareBenchmarkEngine;

impl MIPSHardwareBenchmarkEngine {
    /// Executes a standardized MIPS benchmark pass.
    pub fn run_benchmark(
        dictionary_size_mb: u32,
        thread_count: u32,
        iterations: u32,
    ) -> Result<MIPSResult, TTZipStatus> {
        let dict_mb = if dictionary_size_mb == 0 { 32 } else { dictionary_size_mb };
        let threads = if thread_count == 0 { 1 } else { thread_count };
        let iters = if iterations == 0 { 1 } else { iterations };
        let buffer_size = (dict_mb as usize) * 1024 * 1024;

        if threads == 1 {
            Self::run_single_thread(dict_mb, iters, buffer_size)
        } else {
            Self::run_multi_thread(dict_mb, threads, iters, buffer_size)
        }
    }

    fn run_single_thread(
        dict_mb: u32,
        iters: u32,
        buffer_size: usize,
    ) -> Result<MIPSResult, TTZipStatus> {
        let mut src_buf = AlignedBuffer::new(buffer_size)?;
        let mut comp_buf = AlignedBuffer::new(buffer_size + (64 * 1024))?;
        let mut decomp_buf = AlignedBuffer::new(buffer_size)?;

        let mut prng = SplitMix64::new(0xDEAD_BEEF_CAFE);
        for (i, byte) in src_buf.as_mut_slice()[..buffer_size].iter_mut().enumerate() {
            *byte = ((prng.next_u64() ^ (i as u64 % 256)) & 0xFF) as u8;
        }

        let mut compressor = DeflateCompressor::new(1)?;
        let mut decompressor = DeflateDecompressor::new()?;
        let mut compressed_len = 0;

        // Compression pass
        let comp_sw = MonotonicStopwatch::start();
        for _ in 0..iters {
            compressed_len = compressor.compress(
                &src_buf.as_slice()[..buffer_size],
                comp_buf.as_mut_slice(),
            )?;
        }
        let comp_elapsed = comp_sw.elapsed_secs().max(0.0001);

        // Decompression pass
        let decomp_sw = MonotonicStopwatch::start();
        for _ in 0..iters {
            let _ = decompressor.decompress(
                &comp_buf.as_slice()[..compressed_len],
                &mut decomp_buf.as_mut_slice()[..buffer_size],
            )?;
        }
        let decomp_elapsed = decomp_sw.elapsed_secs().max(0.0001);

        let total_bytes = (buffer_size as f64) * (iters as f64);
        Self::calculate_metric(dict_mb, 1, total_bytes, comp_elapsed, decomp_elapsed)
    }

    fn run_multi_thread(
        dict_mb: u32,
        threads: u32,
        iters: u32,
        buffer_size: usize,
    ) -> Result<MIPSResult, TTZipStatus> {
        use rayon::prelude::*;

        let comp_sw = MonotonicStopwatch::start();
        let thread_results: Result<Vec<(AlignedBuffer, usize)>, TTZipStatus> = (0..threads)
            .into_par_iter()
            .map(|thread_idx| -> Result<(AlignedBuffer, usize), TTZipStatus> {
                let mut src_buf = AlignedBuffer::new(buffer_size)?;
                let mut comp_buf = AlignedBuffer::new(buffer_size + (64 * 1024))?;
                let mut prng = SplitMix64::new(0xDEAD_BEEF_CAFE ^ (thread_idx as u64));
                for (i, byte) in src_buf.as_mut_slice()[..buffer_size].iter_mut().enumerate() {
                    *byte = ((prng.next_u64() ^ (i as u64 % 256)) & 0xFF) as u8;
                }
                let mut compressor = DeflateCompressor::new(1)?;
                let mut compressed_len = 0;
                for _ in 0..iters {
                    compressed_len = compressor.compress(
                        &src_buf.as_slice()[..buffer_size],
                        comp_buf.as_mut_slice(),
                    )?;
                }
                Ok((comp_buf, compressed_len))
            })
            .collect();

        let compressed_items = thread_results?;
        let comp_elapsed = comp_sw.elapsed_secs().max(0.0001);

        let decomp_sw = MonotonicStopwatch::start();
        let decomp_res: Result<(), TTZipStatus> = compressed_items
            .into_par_iter()
            .map(|(comp_buf, compressed_len)| -> Result<(), TTZipStatus> {
                let mut decomp_buf = AlignedBuffer::new(buffer_size)?;
                let mut decompressor = DeflateDecompressor::new()?;
                for _ in 0..iters {
                    let _ = decompressor.decompress(
                        &comp_buf.as_slice()[..compressed_len],
                        &mut decomp_buf.as_mut_slice()[..buffer_size],
                    )?;
                }
                Ok(())
            })
            .collect();
        decomp_res?;
        let decomp_elapsed = decomp_sw.elapsed_secs().max(0.0001);

        let total_bytes = (buffer_size as f64) * (iters as f64) * (threads as f64);
        Self::calculate_metric(dict_mb, threads, total_bytes, comp_elapsed, decomp_elapsed)
    }

    fn calculate_metric(
        dict_mb: u32,
        threads: u32,
        total_bytes: f64,
        comp_elapsed: f64,
        decomp_elapsed: f64,
    ) -> Result<MIPSResult, TTZipStatus> {
        let comp_speed_mbs = (total_bytes / (1024.0 * 1024.0)) / comp_elapsed;
        let decomp_speed_mbs = (total_bytes / (1024.0 * 1024.0)) / decomp_elapsed;

        let enc_complex = 870.0 + (dict_mb as f64) * 2.5;
        let compress_mips = (total_bytes * enc_complex) / (comp_elapsed * 1_000_000.0);

        let dec_complex = 260.0;
        let decompress_mips = (total_bytes * dec_complex) / (decomp_elapsed * 1_000_000.0);

        let total_mips = (compress_mips + decompress_mips) / 2.0;
        let cpu_usage_percent = (threads as f64) * 100.0;
        let rating_per_usage = total_mips / (threads.max(1) as f64);

        Ok(MIPSResult {
            dictionary_size_mb: dict_mb,
            thread_count: threads,
            compress_mips,
            decompress_mips,
            total_mips,
            compress_speed_mbs: comp_speed_mbs,
            decompress_speed_mbs: decomp_speed_mbs,
            cpu_usage_percent,
            rating_per_usage_mips: rating_per_usage,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_mips_hardware_benchmark_single_thread() {
        let res = MIPSHardwareBenchmarkEngine::run_benchmark(1, 1, 1)
            .expect("1MB MIPS benchmark should pass");
        assert!(res.compress_mips > 0.0);
        assert!(res.decompress_mips > 0.0);
        assert!(res.total_mips > 0.0);
        assert!(res.compress_speed_mbs > 0.0);
        assert!(res.decompress_speed_mbs > 0.0);
        assert_eq!(res.thread_count, 1);
    }

    #[test]
    fn test_mips_hardware_benchmark_multi_thread() {
        let res = MIPSHardwareBenchmarkEngine::run_benchmark(1, 2, 1)
            .expect("2-thread 1MB MIPS benchmark should pass");
        assert!(res.total_mips > 0.0);
        assert_eq!(res.thread_count, 2);
    }
}
