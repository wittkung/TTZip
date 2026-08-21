// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// High-precision hardware performance & energy efficiency benchmark engine.
///
/// Backed by high-performance Rust core `MIPSHardwareBenchmarkEngine`, implementing 7-Zip standard MIPS
/// rating formulas with 16KB page-aligned buffers, multi-threaded Rayon execution, and monotonic timing.
public final class MIPSHardwareBenchmarkEngine: @unchecked Sendable {
    public static let shared = MIPSHardwareBenchmarkEngine()
    
    private init() {}
    
    /// Executes a standardized multi-core MIPS benchmark pass via native Rust glue.
    public func runMIPSBenchmark(
        dictionarySizeMB: Int = 32,
        threadCount: Int = AppleSiliconTuner.shared.topology.totalCores,
        iterations: Int = 1
    ) async -> HardwareBenchmarkMetric {
        await Task.detached(priority: .userInitiated) {
            var rawResult = TTZipMIPSBenchmarkResult()
            let status = ttzip_rust_bench_run_mips(
                UInt32(max(1, dictionarySizeMB)),
                UInt32(max(1, threadCount)),
                UInt32(max(1, iterations)),
                &rawResult
            )
            
            if status == TTZIP_STATUS_OK {
                return HardwareBenchmarkMetric(
                    dictionarySizeMB: Int(rawResult.dictionary_size_mb),
                    threadCount: Int(rawResult.thread_count),
                    compressMIPS: rawResult.compress_mips,
                    decompressMIPS: rawResult.decompress_mips,
                    totalMIPS: rawResult.total_mips,
                    compressSpeedMBs: rawResult.compress_speed_mbs,
                    decompressSpeedMBs: rawResult.decompress_speed_mbs,
                    cpuUsagePercent: rawResult.cpu_usage_percent,
                    ratingPerUsageMIPS: rawResult.rating_per_usage_mips
                )
            }
            
            return HardwareBenchmarkMetric(
                dictionarySizeMB: dictionarySizeMB,
                threadCount: threadCount,
                compressMIPS: 0,
                decompressMIPS: 0,
                totalMIPS: 0,
                compressSpeedMBs: 0,
                decompressSpeedMBs: 0,
                cpuUsagePercent: 0,
                ratingPerUsageMIPS: 0
            )
        }.value
    }
}
