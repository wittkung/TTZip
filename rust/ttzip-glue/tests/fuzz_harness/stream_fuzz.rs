// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Task T009: Stream Micro-buffering Fault Injection Fuzzing.

use std::io::{Read, Seek, SeekFrom};
use std::panic::{catch_unwind, AssertUnwindSafe};
use ttzip_glue::archive::stream_adapter::{
    StreamReaderState, DEFAULT_STREAM_BUFFER_SIZE, MAX_RESIDENT_MEMORY_MB, MAX_STREAM_BUFFER_SIZE,
};

use super::common::{fuzz_scale, FuzzRng};

/// Configurable fault-injecting `Read` + `Seek` stream.
struct FaultyStream {
    data: Vec<u8>,
    position: usize,
    inject_eof_after_bytes: usize,
    inject_io_error_at_call: usize,
    inject_interrupted_at_call: usize,
    max_chunk_size: usize,
    call_count: usize,
}

impl Read for FaultyStream {
    fn read(&mut self, buf: &mut [u8]) -> std::io::Result<usize> {
        self.call_count += 1;

        if self.call_count == self.inject_io_error_at_call {
            return Err(std::io::Error::new(
                std::io::ErrorKind::ConnectionReset,
                "Simulated connection reset",
            ));
        }

        if self.call_count == self.inject_interrupted_at_call {
            return Err(std::io::Error::new(
                std::io::ErrorKind::Interrupted,
                "Simulated interrupted call",
            ));
        }

        if self.position >= self.data.len() || self.position >= self.inject_eof_after_bytes {
            return Ok(0);
        }

        let remaining = self.data.len() - self.position;
        let allowed = remaining
            .min(buf.len())
            .min(self.max_chunk_size)
            .min(self.inject_eof_after_bytes.saturating_sub(self.position));

        if allowed == 0 {
            return Ok(0);
        }

        buf[..allowed].copy_from_slice(&self.data[self.position..self.position + allowed]);
        self.position += allowed;
        Ok(allowed)
    }
}

impl Seek for FaultyStream {
    fn seek(&mut self, pos: SeekFrom) -> std::io::Result<u64> {
        let new_pos = match pos {
            SeekFrom::Start(offset) => offset as i64,
            SeekFrom::Current(offset) => (self.position as i64) + offset,
            SeekFrom::End(offset) => (self.data.len() as i64) + offset,
        };

        if new_pos < 0 || new_pos > (self.data.len() as i64) {
            return Err(std::io::Error::new(
                std::io::ErrorKind::InvalidInput,
                "Invalid seek position",
            ));
        }

        self.position = new_pos as usize;
        Ok(self.position as u64)
    }
}

#[test]
fn test_fuzz_stream_fault_injection() {
    let mut rng = FuzzRng::new(0x9999888800000001);
    let total_stream_trials = fuzz_scale(5_000);
    let mut panics_caught = 0u64;

    for _ in 0..total_stream_trials {
        let data_len = 100 + rng.next_usize(128 * 1024);
        let sample_data = vec![0xAAu8; data_len];

        let eof_after = 10 + rng.next_usize(data_len);
        let error_at = 1 + rng.next_usize(20);
        let intr_at = 1 + rng.next_usize(20);
        let chunk_size = 1 + rng.next_usize(1024);

        let stream = FaultyStream {
            data: sample_data,
            position: 0,
            inject_eof_after_bytes: eof_after,
            inject_io_error_at_call: error_at,
            inject_interrupted_at_call: intr_at,
            max_chunk_size: chunk_size,
            call_count: 0,
        };

        let buffer_size = match rng.next_usize(4) {
            0 => 1024,                     // Clamped to DEFAULT_STREAM_BUFFER_SIZE (64KB)
            1 => DEFAULT_STREAM_BUFFER_SIZE, // 64KB
            2 => 1024 * 1024,              // 1MB
            _ => 4 * 1024 * 1024,          // Clamped to MAX_STREAM_BUFFER_SIZE (2MB)
        };

        let res = catch_unwind(AssertUnwindSafe(move || {
            let mut state = StreamReaderState::new(stream, buffer_size);

            // Assert buffer capacity invariant (must be within [64KB, 2MB] and <= 64MB task limit)
            assert!(state.buffer.len() >= DEFAULT_STREAM_BUFFER_SIZE);
            assert!(state.buffer.len() <= MAX_STREAM_BUFFER_SIZE);
            assert!(
                state.buffer.len() <= MAX_RESIDENT_MEMORY_MB * 1024 * 1024,
                "Memory exceeded 64MB RSS bound"
            );

            // Read in loop with loop breaker to detect infinite loops
            let mut steps = 0;
            let max_steps = 10_000;

            loop {
                steps += 1;
                if steps > max_steps {
                    panic!("Dead loop detected in stream reader!");
                }

                match state.read_chunk() {
                    Ok((_ptr, 0)) => break,
                    Ok((_ptr, _n)) => {}
                    Err(_) => break,
                }
            }

            let snapshot = state.snapshot();
            assert!(snapshot.bytes_consumed <= data_len as u64);
        }));

        if res.is_err() {
            panics_caught += 1;
        }
    }

    println!(
        "[FUZZ] Completed {} trials on streamFaultInjection -> 0 dead loops, {} panics, max resident <= 64MB",
        total_stream_trials, panics_caught
    );

    assert_eq!(
        panics_caught, 0,
        "FATAL: Stream fault injection caused a panic or dead loop!"
    );
}
