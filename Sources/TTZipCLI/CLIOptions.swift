// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Weitao Kung (Witt Kung) <kevintungs@163.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import TTZipCore

/// Strongly-typed command line argument and option model
public struct CLIOptions: Sendable {
    /// Positional argument list
    public var positionals: [String] = []
    
    /// Archive encryption or decryption password
    public var password: String? = nil
    
    /// Target compression format (e.g. "zip", "7z", "tar.zst", "ALL")
    public var format: String? = nil
    
    /// Split volume size (e.g. "100m", "1g")
    public var splitSize: String? = nil
    
    /// Compression level (e.g. "store", "fast", "ultra", "1", "9")
    public var level: String? = nil
    
    /// Competitor tool identifiers for benchmarks (e.g. "pigz,7zz")
    public var competitorTools: String? = nil
    
    /// Benchmark dataset size (e.g. "500MB")
    public var hugeSize: String? = nil
    
    /// Flag to test huge payloads only
    public var hugeOnly: Bool = false
    
    /// Input file or directory path
    public var inputPath: String? = nil
    
    /// Flag to enable zero-copy in-memory pipeline
    public var enableZeroCopy: Bool = false
    
    /// Configuration file path for filtering benchmarks
    public var filterConfigPath: String? = nil
    
    /// Flag to terminate immediately upon lag or performance regression
    public var stopOnLag: Bool = false
    
    /// Flag to test across all 16 supported formats
    public var allFormats: Bool = false
    
    /// Flag to automatically compare against the best physical competitor
    public var autoBestCompetitor: Bool = false
    
    /// Flag to verify 100% throughput dominance across test suite
    public var verifyAllDominance: Bool = false
    
    // MARK: - Test-Driven & Diagnostic Options
    
    /// Regex or keyword filter pattern (e.g. --filter "GoldenCorpus")
    public var filterPattern: String? = nil
    
    /// Verbosity level (-1: quiet -q, 0: default, 1: verbose -v, 2: debug -vv)
    public var verbosity: Int = 0
    
    /// Flag to retain temporary sandbox files (-k, --keep-temp)
    public var keepTempFiles: Bool = false
    
    /// Flag to dump failure state on test assertion failure (--dump-on-failure)
    public var dumpOnFailure: Bool = false
    
    /// Flag to execute fast in-process diagnostics only (--fast)
    public var fast: Bool = false
    
    /// File path for JSON structured benchmark/test report (--json-report <path>)
    public var jsonReportPath: String? = nil
    
    /// File path for Markdown benchmark/test report (--markdown-report <path>)
    public var markdownReportPath: String? = nil
    
    /// Flag to run benchmark against the 211MB Silesia corpus (--silesia)
    public var silesia: Bool = false
    
    // MARK: - Pure Memory & TurboBench / lzbench Alignment Options
    
    /// Flag to enable in-memory benchmarking (--in-memory, --mem)
    public var inMemory: Bool = false
    
    /// Flag to format output compatible with TurboBench Markdown tables
    public var turboBenchCompat: Bool = false
    
    /// Minimum measurement window in milliseconds (default: 500ms)
    public var minDurationMs: Int = 500
    
    /// Number of warmup passes prior to measurement (default: 2)
    public var warmupPasses: Int = 2
    
    /// Flag to display binary units (MiB/s) instead of decimal (MB/s)
    public var binaryUnits: Bool = false
    
    public init() {}
}

/// Supported CLI subcommands
public enum CLICommand: String, Sendable {
    case inspect
    case extract
    case create
    case recover
    case bench
    case benchPk = "bench_pk"
    case competitorBench = "competitor_bench"
    case clean
    case cleanCache = "clean-cache"
    case purge
    case customBench = "custom_bench"
    case test
    case repair
    case batch
    case uninstall
    case preset
    case version = "--version"
    case shortVersion = "-v"
    case help = "--help"
    case shortHelp = "-h"
    case unknown
    
    public init(commandString: String) {
        let lower = commandString.lowercased()
        if let val = CLICommand(rawValue: lower) {
            self = val
        } else if lower == "clean-cache" || lower == "purge" {
            self = .clean
        } else if lower == "competitor_bench" {
            self = .benchPk
        } else if lower == "batch" || lower == "macro" {
            self = .batch
        } else {
            self = .unknown
        }
    }
}
