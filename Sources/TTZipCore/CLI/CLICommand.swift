// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Supported command-line subcommands and flags.
public enum CLICommand: String, Sendable {
    case archive
    case create
    case extract
    case list
    case test
    case bench
    case benchPk = "bench_pk"
    case competitorBench = "competitor_bench"
    case inspect
    case diff
    case recover
    case repair
    case clean
    case cleanCache = "clean-cache"
    case purge
    case customBench = "custom_bench"
    case batch
    case uninstall
    case preset
    case completion
    case man
    case cat
    case tree
    case hash
    case delete
    case update
    case explore
    case version = "--version"
    case shortVersion = "-v"
    case help = "--help"
    case shortHelp = "-h"
    case unknown
    
    /// Parses a raw command string into a typed `CLICommand` enum.
    /// - Parameter commandString: Subcommand name or alias.
    public init(commandString: String) {
        let lower = commandString.lowercased()
        switch lower {
        case "archive", "a":
            self = .archive
        case "create", "c":
            self = .create
        case "extract", "x", "e":
            self = .extract
        case "list", "l", "ls":
            self = .list
        case "test", "t", "verify":
            self = .test
        case "explore", "tui", "browse":
            self = .explore
        case "bench", "b", "benchmark":
            self = .bench
        case "bench_pk", "benchpk", "pk":
            self = .benchPk
        case "competitor_bench", "competitor":
            self = .competitorBench
        case "inspect", "i", "info":
            self = .inspect
        case "diff":
            self = .diff
        case "recover":
            self = .recover
        case "repair":
            self = .repair
        case "clean":
            self = .clean
        case "clean-cache":
            self = .cleanCache
        case "purge":
            self = .purge
        case "custom_bench":
            self = .customBench
        case "batch":
            self = .batch
        case "uninstall":
            self = .uninstall
        case "preset":
            self = .preset
        case "completion":
            self = .completion
        case "man":
            self = .man
        case "cat", "view":
            self = .cat
        case "tree":
            self = .tree
        case "hash", "checksum":
            self = .hash
        case "delete", "remove", "rm", "del", "d":
            self = .delete
        case "update", "u":
            self = .update
        case "--version":
            self = .version
        case "-v", "-V":
            self = .shortVersion
        case "--help":
            self = .help
        case "-h", "help":
            self = .shortHelp
        default:
            self = .unknown
        }
    }
}
