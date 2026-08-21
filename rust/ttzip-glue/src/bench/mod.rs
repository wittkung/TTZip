// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Benchmarking, MIPS rating, monotonic timing, and Pareto frontier modules.

pub mod clock;
pub mod mips;
pub mod pareto;

pub use clock::MonotonicStopwatch;
pub use mips::{MIPSHardwareBenchmarkEngine, MIPSResult, SplitMix64};
pub use pareto::{compute_pareto_frontier_raw, ParetoPointRaw};
