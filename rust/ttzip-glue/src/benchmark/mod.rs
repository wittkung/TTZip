// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Benchmarking, MIPS rating, monotonic timing, Pareto frontier, and Matrix Gate suite.

pub mod clock;
pub mod codecs_driver;
pub mod corpus;
pub mod delta;
pub mod mips;
pub mod pareto;
pub mod plotter;
pub mod runner;
pub mod spline;

#[cfg(test)]
mod tests;

pub use clock::MonotonicStopwatch;
pub use codecs_driver::{MatrixCodecConfig, MatrixCodecDriver};
pub use corpus::{BenchmarkCorpusGenerator, BenchmarkCorpusType};
pub use delta::{BinaryDeltaAuditor, BinaryDeltaReport, SegmentDeltaAudit};
pub use mips::{MIPSHardwareBenchmarkEngine, MIPSResult, SplitMix64};
pub use pareto::{
    calculate_pareto_frontier, compute_codec_pareto_frontier_raw, compute_pareto_frontier_raw,
    ParetoCodecPoint, ParetoPointRaw, TTZipParetoCodecPointRaw,
};
pub use plotter::BenchmarkPlotter;
pub use runner::{BenchmarkMatrixReport, BenchmarkMatrixRunner, BenchmarkPointResult};
pub use spline::{FritschCarlsonSpline, SplinePoint};
