// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// 声明式命令行选项规范模型
public struct CLIOptionSpec: Sendable {
    public let shortName: String?
    public let longName: String
    public let description: String
    public let takesValue: Bool
    public let valueName: String?
    public let valueChoices: [String]
    public let isFilePath: Bool
    
    public init(
        shortName: String? = nil,
        longName: String,
        description: String,
        takesValue: Bool = false,
        valueName: String? = nil,
        valueChoices: [String] = [],
        isFilePath: Bool = false
    ) {
        self.shortName = shortName
        self.longName = longName
        self.description = description
        self.takesValue = takesValue
        self.valueName = valueName
        self.valueChoices = valueChoices
        self.isFilePath = isFilePath
    }
}

/// 声明式命令行子命令规范模型
public struct CLICommandMetadata: Sendable {
    public let name: String
    public let aliases: [String]
    public let summary: String
    public let usage: String
    public let options: [CLIOptionSpec]
    
    public init(name: String, aliases: [String] = [], summary: String, usage: String, options: [CLIOptionSpec] = []) {
        self.name = name
        self.aliases = aliases
        self.summary = summary
        self.usage = usage
        self.options = options
    }
}

/// 声明式命令元数据与 Shell 自动补全 / Man Page 规范定义
public enum CLICommandSpec {
    
    public static let globalOptions: [CLIOptionSpec] = [
        CLIOptionSpec(shortName: "h", longName: "help", description: "Show help information"),
        CLIOptionSpec(shortName: "V", longName: "version", description: "Show version and architecture information"),
        CLIOptionSpec(shortName: "v", longName: "verbose", description: "Increase verbosity level (-v, -vv)"),
        CLIOptionSpec(shortName: "q", longName: "quiet", description: "Quiet mode, suppress progress and non-fatal warnings"),
        CLIOptionSpec(shortName: "y", longName: "yes", description: "Assume yes on all prompts (e.g. overwrite)"),
        CLIOptionSpec(longName: "dry-run", description: "Simulate operations without writing changes to disk"),
        CLIOptionSpec(longName: "no-color", description: "Disable ANSI color output"),
        CLIOptionSpec(longName: "json", description: "Output machine-readable NDJSON stream on stdout"),
        CLIOptionSpec(shortName: "T", longName: "threads", description: "Set maximum concurrency threads (0 for auto)", takesValue: true, valueName: "NUM"),
        CLIOptionSpec(longName: "lang", description: "Set language (en, zh-Hans, zh-Hant, ja, de, fr, es)", takesValue: true, valueName: "LANG"),
        CLIOptionSpec(shortName: "P", longName: "password-file", description: "Read password from file", takesValue: true, valueName: "PATH"),
        CLIOptionSpec(longName: "overwrite", description: "File collision overwrite policy (prompt, always, never, newer, backup)", takesValue: true, valueName: "POLICY"),
        CLIOptionSpec(shortName: "x", longName: "exclude", description: "Exclude files matching glob pattern", takesValue: true, valueName: "GLOB"),
        CLIOptionSpec(shortName: "i", longName: "include", description: "Include only files matching glob pattern", takesValue: true, valueName: "GLOB"),
        CLIOptionSpec(longName: "strip-components", description: "Strip leading path components on extraction", takesValue: true, valueName: "N"),
        CLIOptionSpec(longName: "exclude-vcs", description: "Exclude version control system directories (.git, .svn, .hg)"),
        CLIOptionSpec(longName: "no-mac-metadata", description: "Exclude macOS metadata files (.DS_Store, __MACOSX, ._*)"),
        CLIOptionSpec(shortName: "f", longName: "force", description: "Force binary output to terminal or bypass safety checks")
    ]
    
    public static let subcommands: [CLICommandMetadata] = [
        CLICommandMetadata(
            name: "archive",
            aliases: ["a", "create", "c"],
            summary: "Create an archive from source files or directories",
            usage: "ttzip-cli archive <output_archive> <inputs...> [options]",
            options: [
                CLIOptionSpec(shortName: "f", longName: "format", description: "Archive format (zip, 7z, tar.zst, tar.gz, tar.xz, lz4, etc.)", takesValue: true, valueName: "FORMAT"),
                CLIOptionSpec(shortName: "l", longName: "level", description: "Compression level (0-9, store, fast, ultra)", takesValue: true, valueName: "LEVEL"),
                CLIOptionSpec(shortName: "p", longName: "password", description: "Encrypt archive with password", takesValue: true, valueName: "PWD"),
                CLIOptionSpec(shortName: "P", longName: "password-file", description: "Read encryption password from file", takesValue: true, valueName: "PATH"),
                CLIOptionSpec(shortName: "s", longName: "split", description: "Split archive into multi-part volumes (e.g. 100M, 1G)", takesValue: true, valueName: "SIZE"),
                CLIOptionSpec(shortName: "x", longName: "exclude", description: "Exclude files matching glob pattern", takesValue: true, valueName: "GLOB"),
                CLIOptionSpec(shortName: "i", longName: "include", description: "Include only files matching glob pattern", takesValue: true, valueName: "GLOB"),
                CLIOptionSpec(longName: "exclude-vcs", description: "Exclude version control system directories (.git, .svn, .hg)"),
                CLIOptionSpec(longName: "no-mac-metadata", description: "Exclude macOS metadata files (.DS_Store, __MACOSX, ._*)"),
                CLIOptionSpec(longName: "files-from", description: "Read input file list from manifest file or '-' for stdin", takesValue: true, valueName: "PATH")
            ]
        ),
        CLICommandMetadata(
            name: "extract",
            aliases: ["x", "e"],
            summary: "Extract files from an archive",
            usage: "ttzip-cli extract <archive> [options]",
            options: [
                CLIOptionSpec(shortName: "o", longName: "output", description: "Destination directory (or '-' for stdout)", takesValue: true, valueName: "DIR"),
                CLIOptionSpec(shortName: "p", longName: "password", description: "Decryption password", takesValue: true, valueName: "PWD"),
                CLIOptionSpec(shortName: "P", longName: "password-file", description: "Read decryption password from file", takesValue: true, valueName: "PATH"),
                CLIOptionSpec(shortName: "k", longName: "keep", description: "Keep damaged or partially extracted files"),
                CLIOptionSpec(shortName: "x", longName: "exclude", description: "Exclude files matching glob pattern", takesValue: true, valueName: "GLOB"),
                CLIOptionSpec(shortName: "i", longName: "include", description: "Include only files matching glob pattern", takesValue: true, valueName: "GLOB"),
                CLIOptionSpec(longName: "strip-components", description: "Strip leading path components on extraction", takesValue: true, valueName: "N"),
                CLIOptionSpec(longName: "overwrite", description: "File collision overwrite policy (prompt, always, never, newer, backup)", takesValue: true, valueName: "POLICY"),
                CLIOptionSpec(shortName: "f", longName: "force", description: "Force overwrite or bypass terminal binary output checks")
            ]
        ),
        CLICommandMetadata(
            name: "list",
            aliases: ["l", "ls"],
            summary: "List contents of an archive",
            usage: "ttzip-cli list <archive> [options]",
            options: [
                CLIOptionSpec(shortName: "p", longName: "password", description: "Decryption password", takesValue: true, valueName: "PWD"),
                CLIOptionSpec(shortName: "P", longName: "password-file", description: "Read decryption password from file", takesValue: true, valueName: "PATH"),
                CLIOptionSpec(shortName: "x", longName: "exclude", description: "Exclude files matching glob pattern", takesValue: true, valueName: "GLOB"),
                CLIOptionSpec(shortName: "i", longName: "include", description: "Include only files matching glob pattern", takesValue: true, valueName: "GLOB")
            ]
        ),
        CLICommandMetadata(
            name: "cat",
            aliases: ["view"],
            summary: "Print decompressed contents of archive entry directly to stdout",
            usage: "ttzip-cli cat <archive> <entry> [options]",
            options: [
                CLIOptionSpec(shortName: "p", longName: "password", description: "Decryption password", takesValue: true, valueName: "PWD"),
                CLIOptionSpec(shortName: "P", longName: "password-file", description: "Read decryption password from file", takesValue: true, valueName: "PATH"),
                CLIOptionSpec(shortName: "f", longName: "force", description: "Force binary data output to interactive terminal")
            ]
        ),
        CLICommandMetadata(
            name: "tree",
            aliases: [],
            summary: "Display archive contents as a visual tree hierarchy",
            usage: "ttzip-cli tree <archive> [options]",
            options: [
                CLIOptionSpec(shortName: "d", longName: "depth", description: "Maximum recursion depth for tree rendering", takesValue: true, valueName: "N"),
                CLIOptionSpec(shortName: "p", longName: "password", description: "Decryption password", takesValue: true, valueName: "PWD"),
                CLIOptionSpec(shortName: "P", longName: "password-file", description: "Read decryption password from file", takesValue: true, valueName: "PATH"),
                CLIOptionSpec(shortName: "x", longName: "exclude", description: "Exclude files matching glob pattern", takesValue: true, valueName: "GLOB"),
                CLIOptionSpec(shortName: "i", longName: "include", description: "Include only files matching glob pattern", takesValue: true, valueName: "GLOB")
            ]
        ),
        CLICommandMetadata(
            name: "hash",
            aliases: ["checksum"],
            summary: "Compute and display CRC32 and SHA-256 checksums of archive entries",
            usage: "ttzip-cli hash <archive> [options]",
            options: [
                CLIOptionSpec(shortName: "p", longName: "password", description: "Decryption password", takesValue: true, valueName: "PWD"),
                CLIOptionSpec(shortName: "P", longName: "password-file", description: "Read decryption password from file", takesValue: true, valueName: "PATH"),
                CLIOptionSpec(longName: "sha256", description: "Calculate full SHA-256 digest in addition to CRC32"),
                CLIOptionSpec(shortName: "x", longName: "exclude", description: "Exclude files matching glob pattern", takesValue: true, valueName: "GLOB"),
                CLIOptionSpec(shortName: "i", longName: "include", description: "Include only files matching glob pattern", takesValue: true, valueName: "GLOB")
            ]
        ),
        CLICommandMetadata(
            name: "delete",
            aliases: ["d"],
            summary: "Delete specified files or patterns from an archive",
            usage: "ttzip-cli delete <archive> <patterns...> [options]",
            options: [
                CLIOptionSpec(shortName: "p", longName: "password", description: "Decryption/encryption password", takesValue: true, valueName: "PWD"),
                CLIOptionSpec(shortName: "P", longName: "password-file", description: "Read password from file", takesValue: true, valueName: "PATH")
            ]
        ),
        CLICommandMetadata(
            name: "update",
            aliases: ["u"],
            summary: "Update newer files or add new files into an existing archive",
            usage: "ttzip-cli update <archive> <inputs...> [options]",
            options: [
                CLIOptionSpec(shortName: "p", longName: "password", description: "Decryption/encryption password", takesValue: true, valueName: "PWD"),
                CLIOptionSpec(shortName: "P", longName: "password-file", description: "Read password from file", takesValue: true, valueName: "PATH"),
                CLIOptionSpec(shortName: "l", longName: "level", description: "Compression level (0-9, store, fast, ultra)", takesValue: true, valueName: "LEVEL"),
                CLIOptionSpec(shortName: "x", longName: "exclude", description: "Exclude files matching glob pattern", takesValue: true, valueName: "GLOB"),
                CLIOptionSpec(shortName: "i", longName: "include", description: "Include only files matching glob pattern", takesValue: true, valueName: "GLOB"),
                CLIOptionSpec(longName: "exclude-vcs", description: "Exclude version control system directories"),
                CLIOptionSpec(longName: "no-mac-metadata", description: "Exclude macOS metadata files")
            ]
        ),
        CLICommandMetadata(
            name: "test",
            aliases: ["t", "verify"],
            summary: "Test archive integrity or run automated test suites",
            usage: "ttzip-cli test [archive] [options]",
            options: [
                CLIOptionSpec(shortName: "p", longName: "password", description: "Decryption password", takesValue: true, valueName: "PWD"),
                CLIOptionSpec(shortName: "P", longName: "password-file", description: "Read decryption password from file", takesValue: true, valueName: "PATH"),
                CLIOptionSpec(longName: "standard", description: "Run standards compliance validation (e.g. zip, tar, zst, all)", takesValue: true, valueName: "FORMAT"),
                CLIOptionSpec(longName: "differential", description: "Run differential oracle test against external tool (e.g. bsdtar, 7zz)", takesValue: true, valueName: "ORACLE"),
                CLIOptionSpec(longName: "fuzz", description: "Run deterministic in-process mutation fuzzing test suite"),
                CLIOptionSpec(longName: "tier", description: "Filter test tiers (e.g. 0,1,2)", takesValue: true, valueName: "TIERS"),
                CLIOptionSpec(longName: "report-junit", description: "Export JUnit XML test report", takesValue: true, valueName: "FILE"),
                CLIOptionSpec(longName: "report-json", description: "Export JSON test report", takesValue: true, valueName: "FILE")
            ]
        ),
        CLICommandMetadata(
            name: "bench",
            aliases: ["b", "benchmark"],
            summary: "Run high-precision CPU/memory codec throughput benchmarks",
            usage: "ttzip-cli bench [options]",
            options: [
                CLIOptionSpec(shortName: "f", longName: "format", description: "Benchmark target format", takesValue: true, valueName: "FORMAT"),
                CLIOptionSpec(longName: "all-formats", description: "Run all 16 formats benchmark matrix")
            ]
        ),
        CLICommandMetadata(
            name: "explore",
            aliases: ["tui", "browse"],
            summary: "Launch interactive terminal TUI explorer for archive inspection and selective extraction",
            usage: "ttzip-cli explore <archive> [options]",
            options: [
                CLIOptionSpec(shortName: "p", longName: "password", description: "Decryption password for encrypted archive", takesValue: true, valueName: "PWD"),
                CLIOptionSpec(shortName: "P", longName: "password-file", description: "Read decryption password from file", takesValue: true, valueName: "PATH")
            ]
        ),
        CLICommandMetadata(
            name: "completion",
            aliases: [],
            summary: "Generate shell auto-completion scripts (zsh, bash, fish, nushell)",
            usage: "ttzip-cli completion <zsh|bash|fish|nushell>"
        ),
        CLICommandMetadata(
            name: "man",
            aliases: [],
            summary: "Output UNIX groff mdoc man page",
            usage: "ttzip-cli man"
        )
    ]
}
