// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Target file collision and overwrite resolution policy.
public enum FileCollisionPolicy: String, Sendable, CaseIterable {
    /// Interactively prompt the user on standard input.
    case prompt
    /// Always overwrite existing destination files.
    case always
    /// Never overwrite existing destination files (skip).
    case never
    /// Overwrite only if the source entry is newer than the existing file.
    case newer
    /// Rename the existing file with a backup suffix before extracting.
    case backup
}

/// Strongly-typed command-line option configuration model conforming to POSIX / GNU utility standards.
public struct CLIOptions: Sendable {
    /// Positional arguments passed to the subcommand.
    public var positionals: [String] = []
    
    /// Target output file or destination directory path (`-o`, `--output`).
    public var outputPath: String? = nil
    
    /// Passphrase for encryption or decryption (`-p`, `--password`).
    public var password: String? = nil
    
    /// Path to file containing passphrase (`-P`, `--password-file`).
    public var passwordFile: String? = nil
    
    /// Target compression format identifier (e.g. "zip", "7z", "tar.zst", "ALL") (`-f`, `--format`).
    public var format: String? = nil
    
    /// Multi-volume split size (e.g. "100m", "1g", "650mb") (`-s`, `--split`).
    public var splitSize: String? = nil
    
    /// Compression level identifier (e.g. "store", "fast", "ultra", "1", "9") (`-l`, `--level`).
    public var level: String? = nil
    
    /// Dry run mode: Simulate operations without writing changes to disk (`--dry-run`).
    public var dryRun: Bool = false
    
    /// Emit machine-readable NDJSON telemetry stream on stdout (`--json`).
    public var jsonOutput: Bool = false
    
    /// Disable ANSI escape color sequences in terminal output (`--no-color`).
    public var noColor: Bool = false
    
    /// Assume yes on all interactive prompts (`-y`, `--yes`, `--assume-yes`).
    public var assumeYes: Bool = false
    
    /// Force execution or bypass terminal stdout safety checks (`-f`, `--force`).
    public var force: Bool = false
    
    /// File collision policy string (`"prompt"`, `"always"`, `"never"`, `"newer"`, `"backup"`) (`--overwrite`).
    public var overwritePolicy: String = "prompt"
    
    /// Glob patterns for excluding matching archive entries (`-x`, `--exclude`).
    public var excludePatterns: [String] = []
    
    /// Glob patterns for including only matching archive entries (`-i`, `--include`).
    public var includePatterns: [String] = []
    
    /// Number of leading directory components to strip on extraction (`--strip-components`).
    public var stripComponents: Int = 0
    
    /// Automatically exclude version control directories like `.git` and `.svn` (`--exclude-vcs`).
    public var excludeVCS: Bool = false
    
    /// Exclude macOS resource forks and `.DS_Store` files (`--no-mac-metadata`).
    public var noMacMetadata: Bool = false
    
    /// Flatten directory hierarchy during compression or extraction (`-j`, `--flatten`, `--junk-paths`).
    public var flattenPaths: Bool = false
    
    /// Stream decompressed entry content directly to standard output (`-O`, `-c`, `--to-stdout`).
    public var toStdout: Bool = false
    
    /// Path to newline-delimited list of source file paths (`-T`, `--files-from`).
    public var filesFromPath: String? = nil
    
    /// Interpret file list as NUL (`\0`) delimited (`-0`, `--null`).
    public var nullDelimiter: Bool = false
    
    /// Maximum depth for visual directory tree expansion (`-d`, `--depth`).
    public var treeDepth: Int? = nil
    
    /// Disable automatic terminal paging via `$PAGER` (`--no-pager`).
    public var noPager: Bool = false
    
    /// Worker thread concurrency count (`-T`, `--threads`).
    public var threads: Int = 0
    
    /// Application interaction language code (`--lang`).
    public var language: String? = nil
    
    /// Comma-separated competitor tool identifiers for benchmarking (`--competitor`, `-c`).
    public var competitorTools: String? = nil
    
    /// Benchmark dataset size string (e.g. "500MB") (`--huge`).
    public var hugeSize: String? = nil
    
    /// Restrict benchmark execution to 500MB+ large payloads only (`--huge-only`).
    public var hugeOnly: Bool = false
    
    /// Explicit input path override (`-i`, `--input`).
    public var inputPath: String? = nil
    
    /// Enable zero-copy memory mapping for store-only workflows (`--zero-copy`).
    public var enableZeroCopy: Bool = false
    
    /// Path to benchmark filter JSON configuration file (`--filter-config`).
    public var filterConfigPath: String? = nil
    
    /// Abort execution if throughput drops below performance floor (`--strict`, `--stop-on-lag`).
    public var stopOnLag: Bool = false
    
    /// Include all 16 supported formats in benchmarking (`--all-formats`).
    public var allFormats: Bool = false
    
    /// Automatically resolve and benchmark against the best available competitor tool (`--auto-best`).
    public var autoBestCompetitor: Bool = false
    
    /// Verify performance dominance across all matrix dimensions (`--verify-dominance`).
    public var verifyAllDominance: Bool = false
    
    // MARK: - Test Harness & Diagnostic Options
    
    /// Comma-separated test tier filter (`--tier "0,1,2"`).
    public var tier: String? = nil
    
    /// Test case filter regex or substring pattern (`--filter`).
    public var filterPattern: String? = nil
    
    /// Logging verbosity level (-1: quiet, 0: default, 1: verbose, 2: debug).
    public var verbosity: Int = 0
    
    /// Preserve intermediate sandboxes and temporary test files (`-k`, `--keep`).
    public var keepTempFiles: Bool = false
    
    /// Dump memory/disk diagnostics upon test assertion failure (`--dump-on-failure`).
    public var dumpOnFailure: Bool = false
    
    /// Execute fast in-process format diagnostic tests only (`--fast`).
    public var fast: Bool = false
    
    /// Target path for JUnit XML test report output (`--report-junit`).
    public var junitReportPath: String? = nil
    
    /// Target path for JSON structured test report output (`--report-json`, `--json-report`).
    public var jsonReportPath: String? = nil
    
    /// Target path for Markdown summary test report output (`--markdown-report`).
    public var markdownReportPath: String? = nil
    
    /// Target format for official standards compliance testing (`--standard <format>`).
    public var standardFormat: String? = nil
    
    /// Target external oracle engine for differential testing (`--differential <oracle>`).
    public var differentialOracle: String? = nil
    
    /// Enable malformed stream mutation fuzzing test mode (`--fuzz`).
    public var fuzz: Bool = false
    
    /// Benchmark against the standard 211MB Silesia compression corpus (`--silesia`).
    public var silesia: Bool = false
    
    // MARK: - In-Memory & TurboBench Alignment Options
    
    /// Enable pure in-memory RAM benchmark execution (`--in-memory`, `--mem`).
    public var inMemory: Bool = false
    
    /// Emit benchmark results in TurboBench/lzbench compatible Markdown format (`--compat-turbobench`, `--turbobench`).
    public var turboBenchCompat: Bool = false
    
    /// Minimum run duration window per benchmark test case in milliseconds (default: 500ms).
    public var minDurationMs: Int = 500
    
    /// Warmup execution iterations before taking monotonic measurements (default: 2).
    public var warmupPasses: Int = 2
    
    /// Use binary units (`MiB/s`, `GiB/s`) instead of decimal units (`MB/s`, `GB/s`).
    public var binaryUnits: Bool = false
    
    // MARK: - 4D Evolution & Pareto Analytics Options
    
    /// Calculate 2D Pareto frontier skyline and convex envelope (`--pareto`).
    public var pareto: Bool = false
    
    /// Render 2D terminal Unicode Braille scatter plot (`--plot`).
    public var plot: Bool = false
    
    /// Output path for standalone SVG vector graphic chart (`--svg-out`).
    public var svgOutPath: String? = nil
    
    /// Output path for high-resolution raster PNG image chart (`--png-out`, `--image-out`).
    public var pngOutPath: String? = nil
    
    /// Enable CPU thermal state monitoring and DVFS cooldown pauses (`--thermal-guard`).
    public var thermalGuard: Bool = false
    
    /// Generate physical media turnaround time matrix (`--transfer-sheet`).
    public var transferSheet: Bool = false
    
    /// Execute Smart Codec Scenario Selector and entropy probe (`--recommend`).
    public var recommend: Bool = false
    
    /// Target scenario for smart recommendation (`--scenario "airdrop"|"daily"|"cold"`).
    public var scenario: String? = nil
    
    // MARK: - Domain Property Conversion
    
    /// Strong enum representation of `overwritePolicy`.
    public var collisionPolicy: FileCollisionPolicy {
        get {
            FileCollisionPolicy(rawValue: overwritePolicy) ?? .prompt
        }
        set {
            overwritePolicy = newValue.rawValue
        }
    }
    
    /// Creates a default `CLIOptions` instance with standard option defaults.
    public init() {}
}
