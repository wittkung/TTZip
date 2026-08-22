// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import TTZipCore

extension POSIXCLIArgumentParser {
    
    /// Parses GNU-style long options starting with `--`.
    internal static func parseLongOption(
        token: String,
        args: [String],
        currentIndex: inout Int,
        options: inout CLIOptions,
        detectedCommand: inout CLICommand
    ) {
        let stripped = String(token.dropFirst(2))
        let key: String
        let inlineValue: String?
        
        if let eqIndex = stripped.firstIndex(of: "=") {
            key = String(stripped[..<eqIndex])
            inlineValue = String(stripped[stripped.index(after: eqIndex)...])
        } else {
            key = stripped
            inlineValue = nil
        }
        
        switch key {
        case "help":
            detectedCommand = .help
        case "version":
            detectedCommand = .version
        case "dry-run":
            options.dryRun = true
        case "json":
            options.jsonOutput = true
        case "no-color":
            options.noColor = true
        case "yes", "assume-yes":
            options.assumeYes = true
        case "verbose":
            options.verbosity = 1
        case "quiet":
            options.verbosity = -1
        case "all-formats", "all":
            options.allFormats = true
            if options.format == nil { options.format = "ALL" }
        case "strict", "stop-on-lag":
            options.stopOnLag = true
        case "zero-copy", "enable-zero-copy":
            options.enableZeroCopy = true
        case "silesia", "silesia-corpus":
            options.silesia = true
        case "in-memory", "mem":
            options.inMemory = true
        case "turbobench", "compat-turbobench":
            options.turboBenchCompat = true
        case "pareto":
            options.pareto = true
        case "plot":
            options.plot = true
        case "svg-out", "svg":
            if let v = inlineValue ?? (currentIndex + 1 < args.count ? args[currentIndex + 1] : nil) {
                options.svgOutPath = v
                if inlineValue == nil { currentIndex += 1 }
            }
        case "png-out", "png", "image-out", "image", "img":
            if let v = inlineValue ?? (currentIndex + 1 < args.count ? args[currentIndex + 1] : nil) {
                options.pngOutPath = v
                if inlineValue == nil { currentIndex += 1 }
            }
        case "thermal-guard", "thermal":
            options.thermalGuard = true
        case "transfer-sheet", "transfer":
            options.transferSheet = true
        case "recommend":
            options.recommend = true
        case "scenario":
            if let v = inlineValue ?? (currentIndex + 1 < args.count ? args[currentIndex + 1] : nil) {
                options.scenario = v
                if inlineValue == nil { currentIndex += 1 }
            }
        case "keep", "keep-temp":
            options.keepTempFiles = true
        case "dump-on-failure":
            options.dumpOnFailure = true
        case "fast":
            options.fast = true
        case "exclude":
            if let v = inlineValue ?? (currentIndex + 1 < args.count ? args[currentIndex + 1] : nil) {
                options.excludePatterns.append(v)
                if inlineValue == nil { currentIndex += 1 }
            }
        case "include":
            if let v = inlineValue ?? (currentIndex + 1 < args.count ? args[currentIndex + 1] : nil) {
                options.includePatterns.append(v)
                if inlineValue == nil { currentIndex += 1 }
            }
        case "strip-components":
            if let v = inlineValue ?? (currentIndex + 1 < args.count ? args[currentIndex + 1] : nil), let num = Int(v) {
                options.stripComponents = max(0, num)
                if inlineValue == nil { currentIndex += 1 }
            }
        case "exclude-vcs":
            options.excludeVCS = true
        case "no-mac-metadata":
            options.noMacMetadata = true
        case "mac-metadata":
            options.noMacMetadata = false
        case "flatten", "junk-paths":
            options.flattenPaths = true
        case "to-stdout", "stdout":
            options.toStdout = true
        case "files-from":
            if let v = inlineValue ?? (currentIndex + 1 < args.count ? args[currentIndex + 1] : nil) {
                options.filesFromPath = v
                if inlineValue == nil { currentIndex += 1 }
            }
        case "null":
            options.nullDelimiter = true
        case "password-file":
            if let v = inlineValue ?? (currentIndex + 1 < args.count ? args[currentIndex + 1] : nil) {
                options.passwordFile = v
                if inlineValue == nil { currentIndex += 1 }
            }
        case "overwrite":
            if let v = inlineValue ?? (currentIndex + 1 < args.count ? args[currentIndex + 1] : nil) {
                options.overwritePolicy = v
                if inlineValue == nil { currentIndex += 1 }
            }
        case "no-clobber":
            options.overwritePolicy = "never"
        case "depth":
            if let v = inlineValue ?? (currentIndex + 1 < args.count ? args[currentIndex + 1] : nil), let num = Int(v) {
                options.treeDepth = max(0, num)
                if inlineValue == nil { currentIndex += 1 }
            }
        case "force":
            options.force = true
        case "no-pager":
            options.noPager = true
        case "format":
            if let v = inlineValue ?? (currentIndex + 1 < args.count ? args[currentIndex + 1] : nil) {
                options.format = v
                if inlineValue == nil { currentIndex += 1 }
            }
        case "level":
            if let v = inlineValue ?? (currentIndex + 1 < args.count ? args[currentIndex + 1] : nil) {
                options.level = v
                if inlineValue == nil { currentIndex += 1 }
            }
        case "password":
            if let v = inlineValue ?? (currentIndex + 1 < args.count ? args[currentIndex + 1] : nil) {
                options.password = v
                if inlineValue == nil { currentIndex += 1 }
            }
        case "output":
            if let v = inlineValue ?? (currentIndex + 1 < args.count ? args[currentIndex + 1] : nil) {
                options.outputPath = v
                if inlineValue == nil { currentIndex += 1 }
            }
        case "input", "file":
            if let v = inlineValue ?? (currentIndex + 1 < args.count ? args[currentIndex + 1] : nil) {
                options.inputPath = v
                if inlineValue == nil { currentIndex += 1 }
            }
        case "split":
            if let v = inlineValue ?? (currentIndex + 1 < args.count ? args[currentIndex + 1] : nil) {
                options.splitSize = v
                if inlineValue == nil { currentIndex += 1 }
            }
        case "threads":
            if let v = inlineValue ?? (currentIndex + 1 < args.count ? args[currentIndex + 1] : nil), let num = Int(v) {
                options.threads = num
                if inlineValue == nil { currentIndex += 1 }
            }
        case "lang", "language":
            if let v = inlineValue ?? (currentIndex + 1 < args.count ? args[currentIndex + 1] : nil) {
                options.language = v
                if inlineValue == nil { currentIndex += 1 }
            }
        case "standard":
            if let v = inlineValue ?? (currentIndex + 1 < args.count ? args[currentIndex + 1] : nil) {
                options.standardFormat = v
                if inlineValue == nil { currentIndex += 1 }
            }
        case "differential", "oracle":
            if let v = inlineValue ?? (currentIndex + 1 < args.count ? args[currentIndex + 1] : nil) {
                options.differentialOracle = v
                if inlineValue == nil { currentIndex += 1 }
            }
        case "fuzz", "mutation-fuzz":
            options.fuzz = true
        case "tier":
            if let v = inlineValue ?? (currentIndex + 1 < args.count ? args[currentIndex + 1] : nil) {
                options.tier = v
                if inlineValue == nil { currentIndex += 1 }
            }
        case "filter":
            if let v = inlineValue ?? (currentIndex + 1 < args.count ? args[currentIndex + 1] : nil) {
                options.filterPattern = v
                if inlineValue == nil { currentIndex += 1 }
            }
        case "report-junit":
            if let v = inlineValue ?? (currentIndex + 1 < args.count ? args[currentIndex + 1] : nil) {
                options.junitReportPath = v
                if inlineValue == nil { currentIndex += 1 }
            }
        case "report-json", "json-report":
            if let v = inlineValue ?? (currentIndex + 1 < args.count ? args[currentIndex + 1] : nil) {
                options.jsonReportPath = v
                if inlineValue == nil { currentIndex += 1 }
            }
        case "markdown-report", "report-md":
            if let v = inlineValue ?? (currentIndex + 1 < args.count ? args[currentIndex + 1] : nil) {
                options.markdownReportPath = v
                if inlineValue == nil { currentIndex += 1 }
            }
        case "config", "filter-config":
            if let v = inlineValue ?? (currentIndex + 1 < args.count ? args[currentIndex + 1] : nil) {
                options.filterConfigPath = v
                options.stopOnLag = true
                if inlineValue == nil { currentIndex += 1 }
            }
        case "tools", "pk-tools", "competitors":
            if let v = inlineValue ?? (currentIndex + 1 < args.count ? args[currentIndex + 1] : nil) {
                options.competitorTools = v
                if inlineValue == nil { currentIndex += 1 }
            }
        case "size", "huge-size":
            if let v = inlineValue ?? (currentIndex + 1 < args.count ? args[currentIndex + 1] : nil) {
                options.hugeSize = v
                if inlineValue == nil { currentIndex += 1 }
            }
        default:
            break
        }
    }
}
