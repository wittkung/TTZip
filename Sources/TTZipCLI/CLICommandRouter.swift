// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import TTZipCore
import CTTZipBridge
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Modular, POSIX-compliant command-line router and dispatcher.
///
/// Implements standard UNIX CLI conventions, input/output validation, stream piping,
/// interactive explorer invocation, and returns POSIX standard exit status codes.
@MainActor
public enum CLICommandRouter {
    public static var facade: TTZipEngineFacading = TTZipEngineFacade.shared
    public static var securityProxy: SecurityProtectionProxy = SecurityProtectionProxy.shared
    
    /// Routes and executes a parsed CLI command with the specified options.
    /// - Parameters:
    ///   - command: Parsed subcommand enum identifier.
    ///   - options: Strongly-typed option configuration.
    /// - Returns: POSIX compliant exit code (`EX_OK`, `EX_USAGE`, `EX_DATAERR`, `EX_NOINPUT`, etc.).
    @discardableResult
    public static func route(command: CLICommand, options: CLIOptions) async -> CLIExitCode {
        switch command {
        case .archive, .create:
            var inputPaths: [String] = []
            let outPath: String?
            
            if let filesFrom = options.filesFromPath {
                do {
                    inputPaths = try await FileFilterListLoader.loadPaths(from: filesFrom, nullDelimiter: options.nullDelimiter)
                } catch {
                    TerminalRenderEngine.shared.logError("ttzip-cli: error: failed to load files-from list '\(filesFrom)': \(error.localizedDescription)")
                    return .noInput
                }
                outPath = options.outputPath ?? options.positionals.first
            } else if options.outputPath != nil {
                outPath = options.outputPath
                inputPaths = options.positionals
            } else if options.positionals.count >= 2 {
                outPath = options.positionals.first
                inputPaths = Array(options.positionals.dropFirst())
            } else {
                outPath = options.outputPath ?? options.positionals.first
                inputPaths = []
            }
            
            guard let output = outPath, !inputPaths.isEmpty else {
                TerminalRenderEngine.shared.logError("ttzip-cli: error: archive command requires an output path and at least one input file.")
                TerminalRenderEngine.shared.logError("Try 'ttzip-cli archive --help' for more information.")
                return .usage
            }
            
            return await handleCreateArchive(outputPath: output, inputPaths: inputPaths, options: options)
            
        case .extract:
            guard let archivePath = options.positionals.first else {
                TerminalRenderEngine.shared.logError("ttzip-cli: error: extract command requires an archive path.")
                TerminalRenderEngine.shared.logError("Try 'ttzip-cli extract --help' for more information.")
                return .usage
            }
            let dest = options.outputPath ?? (options.positionals.count >= 2 ? options.positionals[1] : "./")
            return await handleExtractArchive(archivePath: archivePath, destDir: dest, options: options)
            
        case .cat:
            guard let archivePath = options.positionals.first else {
                TerminalRenderEngine.shared.logError("ttzip-cli: error: cat command requires an archive path.")
                TerminalRenderEngine.shared.logError("Try 'ttzip-cli cat <archive> [entry]' for more information.")
                return .usage
            }
            let targetEntry = options.positionals.count >= 2 ? options.positionals[1] : nil
            return await handleCatArchive(archivePath: archivePath, entryPath: targetEntry, options: options)
            
        case .tree:
            guard let path = options.positionals.first else {
                TerminalRenderEngine.shared.logError("ttzip-cli: error: tree command requires an archive path.")
                return .usage
            }
            return await handleTreeArchive(path: path, options: options)
            
        case .explore:
            guard let path = options.positionals.first else {
                TerminalRenderEngine.shared.logError("ttzip-cli: error: explore command requires an archive path.")
                TerminalRenderEngine.shared.logError("Try 'ttzip-cli explore <archive>' for more information.")
                return .usage
            }
            let pwd = SecureCredentialResolver.resolvePassword(
                explicitPassword: options.password,
                passwordFile: options.passwordFile,
                archiveName: path
            )
            let process = Process()
            if let ttzipPath = SystemBinaryResolver.shared.resolve(name: "ttzip") {
                process.executableURL = URL(fileURLWithPath: ttzipPath)
                var args = [path]
                if let pwd = pwd {
                    args.append(contentsOf: ["--password", pwd])
                }
                process.arguments = args
                do {
                    try process.run()
                    process.waitUntilExit()
                    return process.terminationStatus == 0 ? .ok : .software
                } catch {
                    TerminalRenderEngine.shared.logError("ttzip-cli: error executing native TUI explorer: \(error.localizedDescription)")
                    return .software
                }
            } else {
                TerminalRenderEngine.shared.logError("ttzip-cli: interactive TUI explorer is powered by native Rust 'ttzip'. Please ensure 'ttzip' binary is installed in PATH.")
                return .unavailable
            }
            
        case .list, .inspect:
            guard let path = options.positionals.first else {
                TerminalRenderEngine.shared.logError("ttzip-cli: error: missing archive path.")
                return .usage
            }
            let pwd = SecureCredentialResolver.resolvePassword(
                explicitPassword: options.password,
                passwordFile: options.passwordFile,
                archiveName: path
            )
            return await handleInspectArchive(path: path, password: pwd, options: options)
            
        case .hash:
            guard let path = options.positionals.first else {
                TerminalRenderEngine.shared.logError("ttzip-cli: error: hash command requires an archive path.")
                return .usage
            }
            return await handleHashArchive(path: path, options: options)
            
        case .delete:
            guard options.positionals.count >= 2 else {
                TerminalRenderEngine.shared.logError("ttzip-cli: error: delete requires archive path and at least one entry name to delete.")
                return .usage
            }
            let archivePath = options.positionals[0]
            let entriesToDelete = Array(options.positionals.dropFirst())
            return await handleDeleteArchive(archivePath: archivePath, entries: entriesToDelete, options: options)
            
        case .update:
            guard options.positionals.count >= 2 else {
                TerminalRenderEngine.shared.logError("ttzip-cli: error: update requires archive path and source files.")
                return .usage
            }
            let archivePath = options.positionals[0]
            let sourcePaths = Array(options.positionals.dropFirst())
            return await handleUpdateArchive(archivePath: archivePath, sourcePaths: sourcePaths, options: options)
            
        case .test:
            await TestCommand.run(options: options)
            return .ok
            
        case .bench:
            await handleBench(options: options)
            return .ok
            
        case .benchPk, .competitorBench:
            await handleBenchPk(options: options)
            return .ok
            
        case .recover:
            if options.positionals.count >= 2 {
                return await handleRecoverPassword(archivePath: options.positionals[0], dictFilePath: options.positionals[1])
            } else {
                TerminalRenderEngine.shared.logError("ttzip-cli: error: recover requires archive and dictionary file paths.")
                return .usage
            }
            
        case .repair:
            if options.positionals.count >= 2 {
                return await handleRepairArchive(damaged: options.positionals[0], output: options.positionals[1])
            } else {
                TerminalRenderEngine.shared.logError("ttzip-cli: error: repair requires damaged and output paths.")
                return .usage
            }
            
        case .diff:
            if options.positionals.count >= 2 {
                return await handleDiffArchive(pathA: options.positionals[0], pathB: options.positionals[1])
            } else {
                TerminalRenderEngine.shared.logError("ttzip-cli: error: diff requires two paths to compare.")
                return .usage
            }
            
        case .clean, .cleanCache, .purge:
            CLIBenchmarkRunner.cleanBenchmarkCache()
            return .ok
            
        case .customBench:
            await CLIBenchmarkRunner.runCustomBench()
            return .ok
            
        case .batch:
            await handleBatchMacro(options: options)
            return .ok
            
        case .uninstall:
            await handleUninstall(options: options)
            return .ok
            
        case .preset:
            printPresets()
            return .ok
            
        case .completion:
            let shellRaw = options.positionals.first?.lowercased() ?? "zsh"
            let targetShell: ShellTarget
            switch shellRaw {
            case "bash": targetShell = .bash
            case "fish": targetShell = .fish
            case "nushell", "nu": targetShell = .nushell
            default: targetShell = .zsh
            }
            let script = ShellCompletionGenerator.generate(for: targetShell)
            print(script)
            return .ok
            
        case .man:
            print(ManPageGenerator.generateManPage())
            return .ok
            
        case .version, .shortVersion:
            print("ttzip-cli 1.0.0 (Apple Silicon ARM64 & x86_64, Native in-process C static engines)")
            return .ok
            
        case .help, .shortHelp:
            printUsage()
            return .ok
            
        case .unknown:
            TerminalRenderEngine.shared.logError("ttzip-cli: error: unrecognized or missing subcommand.")
            printUsage()
            return .usage
        }
    }
    
    static func printPresets() {
        print("📋 Active Archiving and Compression Presets:")
        for preset in PresetManager.shared.presets {
            print(" - [\(preset.name)] Format: \(preset.format.rawValue) Split: \(preset.splitVolumeDescription)")
        }
    }
    
    public static func printUsage() {
        print("""
        TTZip CLI — High-Performance Native Archiving & Compression Engine (macOS)
        
        Usage:
          ttzip-cli <command> [options] [arguments...]
        
        Commands:
          archive, a, c   Create an archive from source files or directories
          extract, x, e   Extract archive contents to destination directory
          cat, view       Stream decompressed archive entry directly to stdout
          tree            Display Unicode hierarchical tree representation of archive
          list, l, ls     List archive entry hierarchy and metadata
          hash, checksum  Calculate CRC32 / SHA-256 digests of entries inside archive
          test, t         Validate archive integrity and run automated test suites
          bench, b        Execute hardware-accelerated throughput benchmarks
          recover         Recover password using multi-core dictionary attack
          repair          Scan and reconstruct salvageable archive data blocks
          delete, d       Remove specified entry from supported archive
          update, u       Update modified files into existing archive
          completion      Generate Shell auto-completion scripts (zsh, bash, fish, nu)
          man             Output UNIX groff mdoc man page
        
        Global Options:
          -h, --help           Show this help message
          -V, --version        Show version and hardware engine information
          -v, --verbose        Increase verbosity level (-v, -vv)
          -q, --quiet          Quiet mode (suppress progress bars and warnings)
          -y, --yes            Assume yes on all interactive prompts
          -f, --force          Force binary output or bypass safety prompts
          --dry-run            Simulate operations without writing changes to disk
          --no-color           Disable ANSI color output
          --no-pager           Disable automatic terminal paging ($PAGER)
          --json               Output machine-readable NDJSON stream on stdout
          -T, --threads N      Concurrency threads (default: performance cores)
          -p, --password PWD   Passphrase for encryption or decryption
          -P, --password-file  Read password securely from file
          --overwrite POLICY   Collision policy (prompt, always, never, newer, backup)
          -x, --exclude GLOB   Exclude files matching glob pattern
          -i, --include GLOB   Include only files matching glob pattern
          --strip-components N Strip N leading directory components on extract
          --exclude-vcs        Automatically exclude .git, .svn, and VCS metadata
          --no-mac-metadata    Exclude .DS_Store and macOS resource forks
          --files-from FILE    Read newline-separated list of paths to archive
        
        Examples:
          ttzip-cli archive out.tar.zst src/ -l 3 --exclude-vcs
          ttzip-cli cat archive.zip config.json | jq .
          ttzip-cli tree archive.zip --depth 2
          ttzip-cli extract bundle.7z -o dist/ -P secret.key --strip-components 1
          ttzip-cli completion fish > ~/.config/fish/completions/ttzip-cli.fish
        """)
    }
}
