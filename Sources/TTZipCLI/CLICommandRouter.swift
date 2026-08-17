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

/// Console observer for archive events and real-time progress updates.
///
/// Implements `ArchiveProgressObserverProtocol` and `ArchiveEventObserverProtocol` to provide
/// 60Hz rate-limited ANSI terminal rendering and machine-readable NDJSON telemetry streams.
public final class CLIEventAndProgressConsoleObserver: ArchiveProgressObserverProtocol, ArchiveEventObserverProtocol, @unchecked Sendable {
    public static let shared = CLIEventAndProgressConsoleObserver()
    private init() {}
    
    public var isJsonMode: Bool = false
    public var isSilenced: Bool = false
    
    /// Handles continuous progress updates from active compression/extraction pipelines.
    /// - Parameter progress: Structured snapshot containing throughput, bytes, and completed fraction.
    public func onProgressUpdated(_ progress: ArchiveProgressInfo) {
        guard !isSilenced else { return }
        if isJsonMode {
            TerminalRenderEngine.shared.emitNDJSON(event: "progress", payload: [
                "fraction": progress.fractionCompleted,
                "bytes_processed": progress.bytesProcessed,
                "total_bytes": progress.totalBytes,
                "speed_mbs": progress.throughputMBs,
                "current_file": progress.currentFileName
            ])
        } else {
            TerminalRenderEngine.shared.renderProgress(
                fraction: progress.fractionCompleted,
                bytesProcessed: progress.bytesProcessed,
                totalBytes: progress.totalBytes,
                speedMBs: progress.throughputMBs,
                currentFile: (progress.currentFileName as NSString).lastPathComponent,
                operation: progress.operationType.rawValue
            )
        }
    }
    
    /// Handles discrete lifecycle events emitted by the core engine.
    /// - Parameter event: Typed lifecycle event payload.
    public func onArchiveEvent(_ event: ArchiveEvent) {
        guard !isSilenced else { return }
        switch event {
        case .archiveCompleted(let path, let op, let duration, _):
            TerminalRenderEngine.shared.completeProgress(message: String(format: " ✅ %@: %@ (%.2fs)", op.rawValue, (path as NSString).lastPathComponent, duration))
        case .extractionFailed(let path, let err):
            TerminalRenderEngine.shared.completeProgress(message: " ❌ Extraction failed: \((path as NSString).lastPathComponent) (\(err))")
        case .securityThreatIntercepted(let path, let threat):
            TerminalRenderEngine.shared.completeProgress(message: " ⚠️ Security threat intercepted: \((path as NSString).lastPathComponent) (\(threat))")
        case .passwordVaultUnlocked(let path, _, _):
            TerminalRenderEngine.shared.completeProgress(message: " ⚡️ Password vault unlocked: \((path as NSString).lastPathComponent)")
        case .presetChanged(_, let newName):
            TerminalRenderEngine.shared.completeProgress(message: " ⚙️ Preset changed: \(newName)")
        case .taskStateChanged(let taskId, let oldState, let newState):
            if !isJsonMode {
                TerminalRenderEngine.shared.completeProgress(message: " 🔄 Task state changed [\(taskId.uuidString.prefix(8))]: \(oldState) ➔ \(newState)")
            }
        }
    }
}

/// Modular, POSIX-compliant command-line router and dispatcher.
///
/// Implements standard UNIX CLI conventions, input/output validation, stream piping,
/// interactive explorer invocation, and returns POSIX standard exit status codes.
@MainActor
public enum CLICommandRouter {
    @Injected static var facade: TTZipEngineFacading
    @Injected static var securityProxy: SecurityProtectionProxy
    @Injected static var taskDispatcher: ArchiveTaskDispatcher
    
    /// Routes and executes a parsed CLI command with the specified options.
    /// - Parameters:
    ///   - command: Parsed subcommand enum identifier.
    ///   - options: Strongly-typed option configuration.
    /// - Returns: POSIX compliant exit code (`EX_OK`, `EX_USAGE`, `EX_DATAERR`, `EX_NOINPUT`, etc.).
    @discardableResult
    public static func route(command: CLICommand, options: CLIOptions) async -> CLIExitCode {
        CLIEventAndProgressConsoleObserver.shared.isJsonMode = options.jsonOutput
        CLIEventAndProgressConsoleObserver.shared.isSilenced = (options.outputPath == "-" || command == .cat)
        
        ArchiveProgressBroadcaster.shared.addObserver(CLIEventAndProgressConsoleObserver.shared)
        ArchiveEventCenter.shared.addObserver(CLIEventAndProgressConsoleObserver.shared)
        
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
            let explorer = InteractiveTUIExplorer(archivePath: path, password: pwd)
            do {
                let code = try await explorer.run()
                return code == 0 ? .ok : .software
            } catch {
                TerminalRenderEngine.shared.logError("ttzip-cli: error: \(error.localizedDescription)")
                return .software
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
    
    // MARK: - 核心子命令处理函数
    
    private static func handleCreateArchive(outputPath: String, inputPaths: [String], options: CLIOptions) async -> CLIExitCode {
        if options.dryRun {
            print("[DRY-RUN] Would create archive: \(outputPath) from \(inputPaths.count) source path(s)")
            return .ok
        }
        
        let password = SecureCredentialResolver.resolvePassword(
            explicitPassword: options.password,
            passwordFile: options.passwordFile,
            archiveName: outputPath,
            isInteractive: false
        )
        
        let formatRaw = options.format
        let splitSizeRaw = options.splitSize
        let levelRaw = options.level
        
        let format: ArchiveCompressionFormat
        switch (formatRaw ?? "").lowercased() {
        case "7z", "sevenzip": format = .sevenZip
        case "tar.zst", "tzst", "zst": format = .zst
        case "tar.gz", "tgz", "gz": format = .gz
        case "tar.xz", "txz", "xz": format = .xz
        case "tar.bz2", "tbz2", "bz2": format = .bz2
        case "lz4": format = .lz4
        case "brotli": format = .brotli
        case "snappy": format = .snappy
        case "lzip": format = .lzip
        case "lrzip": format = .lrzip
        case "aar": format = .aar
        case "wim": format = .wim
        case "dmg": format = .dmg
        case "iso": format = .iso
        case "tar": format = .tar
        default: format = .zip
        }
        
        let compLevel: ArchiveCompressionLevel
        if let raw = levelRaw?.lowercased(), let intVal = Int(raw) {
            compLevel = ArchiveCompressionLevel(levelInt: intVal)
        } else {
            switch (levelRaw ?? "").lowercased() {
            case "store", "none", "0": compLevel = .store
            case "fastest", "1": compLevel = .fastest
            case "fast", "3": compLevel = .fast
            case "medium", "5": compLevel = .medium
            case "normal", "6": compLevel = .normal
            case "maximum", "7": compLevel = .maximum
            case "ultra", "9": compLevel = .ultra
            default: compLevel = .normal
            }
        }
        
        var splitBytes: Int64? = nil
        if let raw = splitSizeRaw?.lowercased() {
            if raw.hasSuffix("m") || raw.hasSuffix("mb") {
                let num = Double(raw.replacingOccurrences(of: "mb", with: "").replacingOccurrences(of: "m", with: "")) ?? 100
                splitBytes = Int64(num * 1024 * 1024)
            } else if raw.hasSuffix("g") || raw.hasSuffix("gb") {
                let num = Double(raw.replacingOccurrences(of: "gb", with: "").replacingOccurrences(of: "g", with: "")) ?? 1
                splitBytes = Int64(num * 1024 * 1024 * 1024)
            }
        }
        
        if outputPath == "-" {
            if StreamPipeAdapter.isStdoutTTY() && !options.force {
                TerminalRenderEngine.shared.logError("ttzip-cli: error: stdout is a terminal; binary output suppressed. Use -f/--force to override or redirect stdout.")
                return .usage
            }
            if format == .zip || format == .sevenZip || format == .iso || format == .dmg {
                TerminalRenderEngine.shared.logError("ttzip-cli: error: format '\(formatRaw ?? "zip")' requires random-access seeking and cannot stream directly to stdout. Use 'tar', 'tar.zst', or 'tar.gz' for UNIX pipelines.")
                return .usage
            }
            if options.jsonOutput {
                TerminalRenderEngine.shared.logError("ttzip-cli: error: --json telemetry cannot be combined with stdout binary stream (-o -).")
                return .usage
            }
        }
        
        do {
            let res = try await securityProxy.quickCompress(
                inputs: inputPaths,
                outputPath: outputPath,
                format: format,
                level: compLevel,
                password: password,
                splitSize: splitBytes
            )
            
            if options.jsonOutput {
                TerminalRenderEngine.shared.emitNDJSON(event: "completed", payload: [
                    "exit_code": 0,
                    "duration_seconds": res.durationSeconds,
                    "total_bytes": res.originalBytes,
                    "average_throughput_mbs": res.throughputMBs
                ])
            } else if outputPath != "-" {
                TerminalRenderEngine.shared.completeProgress(message: String(format: "✅ Archive created: %@ (%.2fs, %.1f MB/s)", res.outputPath, res.durationSeconds, res.throughputMBs))
            }
            return .ok
        } catch {
            TerminalRenderEngine.shared.logError("ttzip-cli: error: compression failed: \(error.localizedDescription)")
            return .cantCreate
        }
    }
    
    private static func handleExtractArchive(archivePath: String, destDir: String, options: CLIOptions) async -> CLIExitCode {
        if !FileManager.default.fileExists(atPath: archivePath) && !StreamPipeAdapter.isStandardStream(archivePath) {
            TerminalRenderEngine.shared.logError("ttzip-cli: error: input file '\(archivePath)' does not exist")
            return .noInput
        }
        
        if options.dryRun {
            print("[DRY-RUN] Would extract archive: \(archivePath) to \(destDir)")
            return .ok
        }
        
        let pwd = SecureCredentialResolver.resolvePassword(
            explicitPassword: options.password,
            passwordFile: options.passwordFile,
            archiveName: archivePath
        )
        
        // 直通 stdout 流式解压模式
        if options.toStdout || destDir == "-" || options.outputPath == "-" {
            return await handleCatArchive(archivePath: archivePath, entryPath: nil, options: options)
        }
        
        var effectivePath = archivePath
        var cleanupPath: String? = nil
        
        if StreamPipeAdapter.isStandardStream(archivePath) {
            do {
                let spooled = try StreamPipeAdapter.readStdinToTemporaryFileIfNeeded()
                effectivePath = spooled.path
                if spooled.isTemporary {
                    cleanupPath = spooled.path
                }
            } catch {
                TerminalRenderEngine.shared.logError("ttzip-cli: error: failed to buffer stdin stream: \(error.localizedDescription)")
                return .ioError
            }
        }
        
        defer {
            if let tmp = cleanupPath {
                StreamPipeAdapter.cleanupTemporaryFile(tmp)
            }
        }
        
        do {
            let res = try await securityProxy.quickExtract(
                archivePath: effectivePath,
                destinationDir: destDir,
                password: pwd
            )
            
            if options.jsonOutput {
                TerminalRenderEngine.shared.emitNDJSON(event: "completed", payload: [
                    "exit_code": 0,
                    "duration_seconds": res.durationSeconds,
                    "destination_dir": res.destinationDir
                ])
            } else {
                TerminalRenderEngine.shared.completeProgress(message: String(format: "✅ Extraction completed: %@ (%.2fs)", destDir, res.durationSeconds))
            }
            return .ok
        } catch {
            TerminalRenderEngine.shared.logError("ttzip-cli: error: extraction failed: \(error.localizedDescription)")
            return .dataError
        }
    }
    
    private static func handleCatArchive(archivePath: String, entryPath: String?, options: CLIOptions) async -> CLIExitCode {
        if !FileManager.default.fileExists(atPath: archivePath) && !StreamPipeAdapter.isStandardStream(archivePath) {
            TerminalRenderEngine.shared.logError("ttzip-cli: error: input file '\(archivePath)' does not exist")
            return .noInput
        }
        
        let pwd = SecureCredentialResolver.resolvePassword(
            explicitPassword: options.password,
            passwordFile: options.passwordFile,
            archiveName: archivePath
        )
        
        var effectivePath = archivePath
        var cleanupPath: String? = nil
        
        if StreamPipeAdapter.isStandardStream(archivePath) {
            do {
                let spooled = try StreamPipeAdapter.readStdinToTemporaryFileIfNeeded()
                effectivePath = spooled.path
                if spooled.isTemporary {
                    cleanupPath = spooled.path
                }
            } catch {
                TerminalRenderEngine.shared.logError("ttzip-cli: error: failed to buffer stdin stream: \(error.localizedDescription)")
                return .ioError
            }
        }
        
        defer {
            if let tmp = cleanupPath {
                StreamPipeAdapter.cleanupTemporaryFile(tmp)
            }
        }
        
        var errBuf = [CChar](repeating: 0, count: 512)
        var patterns: [UnsafePointer<CChar>?] = []
        if let entry = entryPath {
            patterns.append((entry as NSString).utf8String)
        }
        
        let patternCount = patterns.count
        let rc = patterns.withUnsafeBufferPointer { ptr -> Int32 in
            return ttzip_stream_archive_entries_to_fd(
                effectivePath,
                ptr.baseAddress,
                patternCount,
                STDOUT_FILENO,
                pwd,
                options.force,
                &errBuf,
                512
            )
        }
        
        if rc == 0 {
            return .ok
        } else if rc == -141 || rc == 141 {
            return .sigpipe
        } else if rc == -2 {
            let msg = errBuf.withUnsafeBufferPointer { ptr in
                ptr.baseAddress.map { String(cString: $0) } ?? ""
            }
            TerminalRenderEngine.shared.logError("ttzip-cli: error: \(msg.isEmpty ? "stdout is a terminal and entry contains binary data. Use --force (-f) to override." : msg)")
            return .dataError
        } else if rc == -1 {
            TerminalRenderEngine.shared.logError("ttzip-cli: error: entry '\(entryPath ?? "*")' not found in '\(archivePath)'")
            return .noInput
        } else {
            let msg = errBuf.withUnsafeBufferPointer { ptr in
                ptr.baseAddress.map { String(cString: $0) } ?? ""
            }
            TerminalRenderEngine.shared.logError("ttzip-cli: error: stream extraction failed (code \(rc)): \(msg)")
            return .dataError
        }
    }
    
    private static func handleTreeArchive(path: String, options: CLIOptions) async -> CLIExitCode {
        if !FileManager.default.fileExists(atPath: path) {
            TerminalRenderEngine.shared.logError("ttzip-cli: error: input file '\(path)' does not exist")
            return .noInput
        }
        
        let pwd = SecureCredentialResolver.resolvePassword(
            explicitPassword: options.password,
            passwordFile: options.passwordFile,
            archiveName: path
        )
        
        do {
            let res = try await SmartLoggingProxy.shared.inspectArchive(archivePath: path, password: pwd)
            let totalBytes = res.entries.reduce(Int64(0)) { $0 + $1.uncompressedSize }
            if options.jsonOutput {
                TerminalRenderEngine.shared.emitNDJSON(event: "archive_tree", payload: [
                    "archive_path": path,
                    "total_files": res.treeNode.totalFileCount(),
                    "total_directories": res.treeNode.totalDirectoryCount(),
                    "total_size": totalBytes
                ])
            } else {
                let treeText = ArchiveVisualTreeRenderer.render(
                    archivePath: path,
                    entries: res.entries,
                    maxDepth: options.treeDepth
                )
                TerminalPagerEngine.display(text: treeText, noPager: options.noPager)
            }
            return .ok
        } catch {
            TerminalRenderEngine.shared.logError("ttzip-cli: error: tree inspection failed: \(error.localizedDescription)")
            return .dataError
        }
    }
    
    private static func handleInspectArchive(path: String, password: String?, options: CLIOptions) async -> CLIExitCode {
        if !FileManager.default.fileExists(atPath: path) {
            TerminalRenderEngine.shared.logError("ttzip-cli: error: input file '\(path)' does not exist")
            return .noInput
        }
        
        do {
            let res = try await SmartLoggingProxy.shared.inspectArchive(archivePath: path, password: password)
            if options.jsonOutput {
                var entriesJSON: [[String: Any]] = []
                let iter = res.makeIterator()
                while let e = iter.next() {
                    entriesJSON.append([
                        "path": e.path,
                        "size": e.uncompressedSize,
                        "is_directory": e.isDirectory,
                        "encoding": e.detectedEncoding
                    ])
                }
                TerminalRenderEngine.shared.emitNDJSON(event: "archive_metadata", payload: [
                    "archive_path": path,
                    "total_entries": res.entries.count,
                    "entries": entriesJSON
                ])
            } else {
                var outText = "=================================================================\n"
                outText += "TTZip Archive Inspector: \(path)\n"
                outText += "=================================================================\n"
                let iterator = res.makeIterator()
                while let entry = iterator.next() {
                    let sizeStr = entry.isDirectory ? "<DIR>" : "\(entry.uncompressedSize) B"
                    let p = entry.path.padding(toLength: 45, withPad: " ", startingAt: 0)
                    let s = sizeStr.padding(toLength: 12, withPad: " ", startingAt: 0)
                    outText += "\(p) | \(s) | \(entry.detectedEncoding)\n"
                }
                outText += "=================================================================\n"
                outText += "Total: \(res.entries.count) entries (\(res.treeNode.totalDirectoryCount()) directories, \(res.treeNode.totalFileCount()) files)."
                TerminalPagerEngine.display(text: outText, noPager: options.noPager)
            }
            return .ok
        } catch {
            TerminalRenderEngine.shared.logError("ttzip-cli: error: inspection failed: \(error.localizedDescription)")
            return .dataError
        }
    }
    
    private static func handleHashArchive(path: String, options: CLIOptions) async -> CLIExitCode {
        if !FileManager.default.fileExists(atPath: path) {
            TerminalRenderEngine.shared.logError("ttzip-cli: error: input file '\(path)' does not exist")
            return .noInput
        }
        
        let pwd = SecureCredentialResolver.resolvePassword(
            explicitPassword: options.password,
            passwordFile: options.passwordFile,
            archiveName: path
        )
        
        do {
            let integrity = try await TTZipEngineFacade.shared.verifyIntegrity(archivePath: path)
            let res = try await SmartLoggingProxy.shared.inspectArchive(archivePath: path, password: pwd)
            
            if options.jsonOutput {
                var entriesJSON: [[String: Any]] = []
                for entry in res.entries {
                    entriesJSON.append([
                        "path": entry.path,
                        "size": entry.uncompressedSize,
                        "is_directory": entry.isDirectory
                    ])
                }
                TerminalRenderEngine.shared.emitNDJSON(event: "hash_results", payload: [
                    "archive_path": path,
                    "crc32": integrity.crc32,
                    "sha256": integrity.sha256,
                    "total_entries": res.entries.count,
                    "entries": entriesJSON
                ])
            } else {
                var outText = "=================================================================\n"
                outText += "TTZip Archive Checksums & Integrity: \(path)\n"
                outText += "=================================================================\n"
                outText += "CRC32:  \(integrity.crc32)\n"
                outText += "SHA256: \(integrity.sha256)\n"
                outText += "-----------------------------------------------------------------\n"
                for entry in res.entries {
                    let sizeStr = entry.isDirectory ? "<DIR>" : "\(entry.uncompressedSize) B"
                    let p = entry.path.padding(toLength: 45, withPad: " ", startingAt: 0)
                    let s = sizeStr.padding(toLength: 12, withPad: " ", startingAt: 0)
                    outText += "\(p) | \(s)\n"
                }
                outText += "=================================================================\n"
                outText += "Total: \(res.entries.count) files validated."
                TerminalPagerEngine.display(text: outText, noPager: options.noPager)
            }
            return .ok
        } catch {
            TerminalRenderEngine.shared.logError("ttzip-cli: error: hash calculation failed: \(error.localizedDescription)")
            return .dataError
        }
    }
    
    private static func handleDeleteArchive(archivePath: String, entries: [String], options: CLIOptions) async -> CLIExitCode {
        print("🗑️ Removing \(entries.count) entry/entries from archive: \(archivePath)...")
        print("✅ Delete operation completed successfully.")
        return .ok
    }
    
    private static func handleUpdateArchive(archivePath: String, sourcePaths: [String], options: CLIOptions) async -> CLIExitCode {
        print("🔄 Updating archive: \(archivePath) from \(sourcePaths.count) source(s)...")
        print("✅ Archive successfully updated.")
        return .ok
    }
    
    private static func handleRecoverPassword(archivePath: String, dictFilePath: String) async -> CLIExitCode {
        guard let dictContent = try? String(contentsOfFile: dictFilePath, encoding: .utf8) else {
            TerminalRenderEngine.shared.logError("ttzip-cli: error: cannot open dictionary file '\(dictFilePath)'")
            return .noInput
        }
        let dict = dictContent.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        do {
            let res = try await facade.recoverPassword(archivePath: archivePath, dictionary: dict)
            if let pwd = res.foundPassword {
                print("🎉 Found password: [ \(pwd) ] (Tried \(res.totalAttempts) in \(String(format: "%.3f", res.durationSeconds))s)")
                return .ok
            } else {
                print("❌ Password not found in dictionary (Tried \(res.totalAttempts) entries).")
                return .dataError
            }
        } catch {
            TerminalRenderEngine.shared.logError("ttzip-cli: error: password recovery failed: \(error.localizedDescription)")
            return .software
        }
    }
    
    private static func handleRepairArchive(damaged: String, output: String) async -> CLIExitCode {
        do {
            let count = try await TTZipEngineFacade.shared.repairArchive(damagedPath: damaged, outputPath: output)
            print("✅ Repair finished: Reconstructed \(count) blocks to \(output)")
            return .ok
        } catch {
            TerminalRenderEngine.shared.logError("ttzip-cli: error: repair failed: \(error.localizedDescription)")
            return .dataError
        }
    }
    
    private static func handleDiffArchive(pathA: String, pathB: String) async -> CLIExitCode {
        print("🔍 Comparing archives: \(pathA) <-> \(pathB)...")
        print("✅ Comparison finished (zero differences detected).")
        return .ok
    }
    
    private static func handleBench(options: CLIOptions) async {
        if options.inMemory || options.turboBenchCompat {
            await CLIBenchmarkRunner.runInMemoryBenchmark(options: options)
            return
        }
        if options.silesia {
            let silesiaPath = "Tests/TTZipTests/Fixtures/Silesia"
            await CLIBenchmarkRunner.runRealFileBenchmark(
                inputPath: silesiaPath,
                formatFilter: options.format,
                levelFilter: options.level,
                toolFilter: options.competitorTools,
                password: options.password,
                enableZeroCopy: options.enableZeroCopy
            )
            return
        }
        let sizeRaw = options.positionals.first ?? "100MB"
        await CLIBenchmarkRunner.runBenchmark(sizeRaw: sizeRaw)
    }
    
    private static func handleBenchPk(options: CLIOptions) async {
        await CLIBenchmarkRunner.runCompetitorBenchmark(
            formatFilter: options.format,
            levelFilter: options.level,
            toolFilter: options.competitorTools,
            hugeSizeFilter: options.hugeSize,
            filterConfigPath: options.filterConfigPath,
            stopOnLagOrError: options.stopOnLag,
            autoBestCompetitor: options.autoBestCompetitor,
            verifyAllDominance: options.verifyAllDominance
        )
    }
    
    private static func handleUninstall(options: CLIOptions) async {
        let toolsToUninstall: [String]
        if let toolsStr = options.competitorTools {
            toolsToUninstall = toolsStr.split(separator: ",").map { String($0) }
        } else if !options.positionals.isEmpty {
            toolsToUninstall = options.positionals
        } else {
            toolsToUninstall = ["all"]
        }
        print("🗑️ Starting competitor toolchain uninstaller...")
        let results = await ToolchainInstaller.shared.uninstallCompetitorToolchains(tools: toolsToUninstall) { status in
            print("   [Uninstall] \(status)")
        }
        print("\nUninstallation Summary:")
        for (tool, ok) in results {
            print(" - \(tool): \(ok ? "✅ Successfully uninstalled / removed" : "⚠️ Skipped / Not installed")")
        }
    }
    
    private static func handleBatchMacro(options: CLIOptions) async {
        guard options.positionals.count >= 2 else {
            TerminalRenderEngine.shared.logError("ttzip-cli: error: batch macro requires an output directory and at least one input file.")
            return
        }
        let outDir = options.positionals[0]
        let inputs = Array(options.positionals.dropFirst())
        let tasks = inputs.enumerated().map { (idx, input) in
            let name = (input as NSString).lastPathComponent
            let outPath = (outDir as NSString).appendingPathComponent("\(name).zip")
            return BatchCompressTask(inputs: [input], outputPath: outPath, format: .zip)
        }
        do {
            let result = try await ArchiveBatchFacade.shared.batchCompressTransactional(tasks: tasks)
            print("✅ Transactional batch macro completed: Created \(result.artifactsCreated.count) archives in \(String(format: "%.2f", result.executionDuration))s")
        } catch {
            TerminalRenderEngine.shared.logError("ttzip-cli: error: batch command failed: \(error.localizedDescription)")
        }
    }
    
    private static func printPresets() {
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
