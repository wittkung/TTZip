// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Weitao Kung (Witt Kung) <kevintungs@163.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import TTZipCore

/// Strongly-typed command line argument parser
public enum CLIArgumentParser {
    
    /// Parse raw command-line string arguments into structured `CLIOptions`
    public static func parse(args: [String]) -> CLIOptions {
        var opts = CLIOptions()
        var idx = 0
        
        while idx < args.count {
            let arg = args[idx]
            
            switch arg {
            case "--all-formats", "--all", "-af":
                opts.allFormats = true
                if opts.format == nil { opts.format = "ALL" }
                
            case "--auto-best-competitor", "--auto-best", "-abc":
                opts.autoBestCompetitor = true
                
            case "--verify-all-dominance", "--verify-dominance", "-vad":
                opts.verifyAllDominance = true
                opts.allFormats = true
                if opts.format == nil { opts.format = "ALL" }
                opts.stopOnLag = true
                
            case "--zero-copy", "--enable-zero-copy", "-zc":
                opts.enableZeroCopy = true
                
            case "--strict", "--stop-on-lag", "--fail-fast", "-soll":
                opts.stopOnLag = true
                
            case "--targeted", "--targeted-only", "--lagging", "--lagging-only":
                opts.filterConfigPath = "Docs/zip_benchmark_lagging_config.json"
                opts.stopOnLag = true
                
            case "--huge-only", "--huge", "-ho", "--last-4", "-l4":
                opts.hugeOnly = true
                
            case "--silesia", "-silesia", "--silesia-corpus":
                opts.silesia = true
                
            case "--filter-config", "-fc", "--config":
                if idx + 1 < args.count {
                    opts.filterConfigPath = args[idx + 1]
                    opts.stopOnLag = true
                    idx += 1
                }
                
            case "-p", "--password":
                if idx + 1 < args.count {
                    opts.password = args[idx + 1]
                    idx += 1
                }
                
            case "-i", "--input", "--file", "-file":
                if idx + 1 < args.count {
                    opts.inputPath = args[idx + 1]
                    idx += 1
                }
                
            case "-f", "--format":
                if idx + 1 < args.count {
                    opts.format = args[idx + 1]
                    idx += 1
                }
                
            case "-s", "--split":
                if idx + 1 < args.count {
                    opts.splitSize = args[idx + 1]
                    idx += 1
                }
                
            case "-l", "--level":
                if idx + 1 < args.count {
                    opts.level = args[idx + 1]
                    idx += 1
                }
                
            case "-t", "--tools", "--pk-tools", "--competitors", "--competitor-tools":
                if idx + 1 < args.count {
                    opts.competitorTools = args[idx + 1]
                    idx += 1
                }
                
            case "-hs", "--huge-size", "--size":
                if idx + 1 < args.count {
                    opts.hugeSize = args[idx + 1]
                    idx += 1
                }
                
            // MARK: - Test-Driven & Diagnostic Arguments
            case "--filter", "-filter":
                if idx + 1 < args.count {
                    opts.filterPattern = args[idx + 1]
                    idx += 1
                }
                
            case "-v", "--verbose":
                opts.verbosity = 1
                
            case "-vv", "--debug":
                opts.verbosity = 2
                
            case "-q", "--quiet":
                opts.verbosity = -1
                
            case "-k", "--keep-temp":
                opts.keepTempFiles = true
                
            case "-d", "--dump-on-failure":
                opts.dumpOnFailure = true
                
            case "--fast":
                opts.fast = true
                
            case "--json-report":
                if idx + 1 < args.count {
                    opts.jsonReportPath = args[idx + 1]
                    idx += 1
                }
                
            case "--markdown-report":
                if idx + 1 < args.count {
                    opts.markdownReportPath = args[idx + 1]
                    idx += 1
                }

            // MARK: - Pure Memory & TurboBench / lzbench Arguments
            case "--in-memory", "--mem", "-im":
                opts.inMemory = true

            case "--compat-turbobench", "--turbobench", "-tb":
                opts.turboBenchCompat = true
                opts.inMemory = true

            case "--min-duration", "--duration", "-dur":
                if idx + 1 < args.count {
                    opts.minDurationMs = Int(args[idx + 1]) ?? 500
                    idx += 1
                }

            case "--warmup", "--warmup-passes":
                if idx + 1 < args.count {
                    opts.warmupPasses = Int(args[idx + 1]) ?? 2
                    idx += 1
                }

            case "--binary-units", "--mib":
                opts.binaryUnits = true
                
            default:
                if !arg.hasPrefix("-") || idx == 0 {
                    opts.positionals.append(arg)
                }
            }
            
            idx += 1
        }
        
        return opts
    }
    
    /// Parse format filter string into an array of `ArchiveCompressionFormat`
    public static func parseFormats(_ raw: String?) -> [ArchiveCompressionFormat]? {
        guard let fRaw = raw, !fRaw.isEmpty else { return nil }
        let lower = fRaw.lowercased()
        if lower == "all" || lower == "all-formats" || lower == "--all-formats" {
            return ArchiveCompressionFormat.allCases
        }
        
        let parts = fRaw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        var parsed: [ArchiveCompressionFormat] = []
        for p in parts {
            if let f = ArchiveCompressionFormat(rawValue: p) {
                parsed.append(f)
            } else if p == "zip" { parsed.append(.zip) }
            else if p == "7z" || p == "7zip" { parsed.append(.sevenZip) }
            else if p == "zst" || p == "zstd" { parsed.append(.zst) }
            else if p == "tar.gz" || p == "tgz" || p == "gz" { parsed.append(.tarGz) }
            else if p == "tar.zst" || p == "tzst" { parsed.append(.tarZst) }
            else if p == "bz2" || p == "bzip2" || p == "tar.bz2" { parsed.append(.bz2) }
            else if p == "xz" || p == "tar.xz" { parsed.append(.xz) }
            else if p == "lzip" || p == "lz" { parsed.append(.lzip) }
            else if p == "lz4" { parsed.append(.lz4) }
            else if p == "brotli" || p == "br" { parsed.append(.brotli) }
            else if p == "lrzip" || p == "lrz" { parsed.append(.lrzip) }
            else if p == "aar" { parsed.append(.aar) }
            else if p == "snappy" || p == "sz" { parsed.append(.snappy) }
            else if p == "wim" { parsed.append(.wim) }
            else if p == "dmg" { parsed.append(.dmg) }
            else if p == "iso" { parsed.append(.iso) }
        }
        return parsed.isEmpty ? nil : parsed
    }
    
    /// Parse compression level filter string into an array of `ArchiveCompressionLevel`
    public static func parseLevels(_ raw: String?) -> [ArchiveCompressionLevel]? {
        guard let lRaw = raw, !lRaw.isEmpty else { return nil }
        let parts = lRaw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        var parsed: [ArchiveCompressionLevel] = []
        for p in parts {
            if let intVal = Int(p) {
                parsed.append(ArchiveCompressionLevel(levelInt: intVal))
            } else if p == "max" || p == "maximum" || p == "ultra" {
                parsed.append(.ultra)
            } else if p == "fast" || p == "fastest" {
                parsed.append(.fastest)
            }
        }
        return parsed.isEmpty ? nil : parsed
    }
}
