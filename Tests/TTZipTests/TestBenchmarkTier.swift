// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Centralized helper for adaptive test execution scaling and profiling tiers.
public enum TestBenchmarkTier {
    /// True when full benchmark profiling is explicitly requested via environment variable.
    public static var isBenchmarkMode: Bool {
        return ProcessInfo.processInfo.environment["TTZIP_RUN_BENCHMARKS"] != nil
    }
    
    /// True when deep mutation fuzzing is explicitly requested via environment variable.
    public static var isDeepFuzzEnabled: Bool {
        return ProcessInfo.processInfo.environment["TTZIP_DEEP_FUZZ"] != nil
    }
    
    /// Returns the active iteration count for fuzzing tests based on environment tier.
    public static func fuzzIterations(default defaultCount: Int, deep deepCount: Int = 200) -> Int {
        return isDeepFuzzEnabled ? deepCount : defaultCount
    }
    
    /// Returns the active iteration count for benchmark tests based on environment tier.
    public static func benchmarkIterations(default defaultCount: Int, benchmark benchmarkCount: Int) -> Int {
        return isBenchmarkMode ? benchmarkCount : defaultCount
    }
}
