// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Weitao Kung (Witt Kung) <kevintungs@163.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import TTZipCore

/// Command line progress and event observer
public final class CLIEventAndProgressConsoleObserver: ArchiveProgressObserverProtocol, ArchiveEventObserverProtocol, @unchecked Sendable {
    public static let shared = CLIEventAndProgressConsoleObserver()
    private init() {}
    
    public func onProgressUpdated(_ progress: ArchiveProgressInfo) {
        let pct = Int(progress.fractionCompleted * 100)
        let rate = String(format: "%.1f MB/s", progress.throughputMBs)
        print(" [CLI-Progress] \(progress.operationType.rawValue): \(pct)% | \(rate) | \((progress.currentFileName as NSString).lastPathComponent)")
    }
    
    public func onArchiveEvent(_ event: ArchiveEvent) {
        switch event {
        case .archiveCompleted(let path, let op, let duration, _):
            print(String(format: " [CLI-Event] ✅ %@ completed: %@ (elapsed %.2fs)", op.rawValue, (path as NSString).lastPathComponent, duration))
        case .extractionFailed(let path, let err):
            print(" [CLI-Event] ❌ Extraction failed: \((path as NSString).lastPathComponent) (\(err))")
        case .securityThreatIntercepted(let path, let threat):
            print(" [CLI-Event] ⚠️ Security threat intercepted: \((path as NSString).lastPathComponent) (\(threat))")
        case .passwordVaultUnlocked(let path, _, _):
            print(" [CLI-Event] ⚡️ Vault password unlocked: \((path as NSString).lastPathComponent)")
        case .presetChanged(_, let newName):
            print(" [CLI-Event] ⚙️ Preset changed: \(newName)")
        case .taskStateChanged(let taskId, let oldState, let newState):
            print(" [CLI-Event] 🔄 Task state changed [\(taskId.uuidString.prefix(8))]: \(oldState) ➔ \(newState)")
        }
    }
}

/// Modular CLI command router
@MainActor
public enum CLICommandRouter {
    // MARK: - Dependency Injection Pattern: Core service injection
    @Injected static var facade: TTZipEngineFacading
    @Injected static var securityProxy: SecurityProtectionProxy
    @Injected static var taskDispatcher: ArchiveTaskDispatcher
    
    /// Route and execute parsed CLI command
    public static func route(command: CLICommand, options: CLIOptions) async {
        ArchiveProgressBroadcaster.shared.addObserver(CLIEventAndProgressConsoleObserver.shared)
        ArchiveEventCenter.shared.addObserver(CLIEventAndProgressConsoleObserver.shared)
        
        switch command {
        case .inspect:
            if let path = options.positionals.first {
                await inspectArchive(path: path, password: options.password)
            } else {
                print("Error: Please provide archive path. Example: ttzip-cli inspect demo.zip [-p password]")
            }
            
        case .extract:
            if options.positionals.count >= 2 {
                let archive = options.positionals[0]
                let dest = options.positionals[1]
                await extractArchive(archivePath: archive, destDir: dest, password: options.password)
            } else {
                print("Error: Please provide archive and destination directory. Example: ttzip-cli extract demo.zip /path/to/out [-p password]")
            }
            
        case .create:
            if options.positionals.count >= 2 {
                let outputPath = options.positionals[0]
                let inputPaths = Array(options.positionals.dropFirst())
                await createArchive(
                    outputPath: outputPath,
                    inputPaths: inputPaths,
                    options: options
                )
            } else {
                print("Error: Insufficient arguments. Example: ttzip-cli create archive.zip file1.txt file2.pdf [-f 7z] [-s 100m] [-l store] [-p pwd]")
            }
            
        case .recover:
            if options.positionals.count >= 2 {
                let archive = options.positionals[0]
                let dictFile = options.positionals[1]
                await recoverPassword(archivePath: archive, dictFilePath: dictFile)
            } else {
                print("Error: Please provide archive and dictionary file path. Example: ttzip-cli recover protected.7z dict.txt")
            }
            
        case .bench:
            await handleBench(options: options)
            
        case .benchPk, .competitorBench:
            await handleBenchPk(options: options)
            
        case .clean, .cleanCache, .purge:
            CLIBenchmarkRunner.cleanBenchmarkCache()
            
        case .customBench:
            await CLIBenchmarkRunner.runCustomBench()
            
        case .test:
            await TestCommand.run(options: options)

        case .repair:
            if options.positionals.count >= 2 {
                await repairArchive(damaged: options.positionals[0], output: options.positionals[1])
            } else {
                print("Error: Please provide damaged archive and target output path. Example: ttzip-cli repair damaged.zip fixed.zip")
            }
            
        case .batch:
            await handleBatchMacro(options: options)
            
        case .uninstall:
            await handleUninstall(options: options)
            
        case .preset:
            printPresets()
            
        case .version, .shortVersion:
            print("ttzip-cli version 1.0.0 (Apple Silicon M-Series & x86_64)")
            
        case .help, .shortHelp, .unknown:
            printUsage()
        }
    }
    
    // MARK: - Subcommand Dispatch Handlers
    
    private static func handleBench(options: CLIOptions) async {
        let fm = FileManager.default
        
        if options.inMemory || options.turboBenchCompat {
            await CLIBenchmarkRunner.runInMemoryBenchmark(options: options)
            return
        }
        
        if options.silesia {
            let silesiaPath: String
            if let envPath = ProcessInfo.processInfo.environment["TTZIP_SILESIA_PATH"], !envPath.isEmpty, fm.fileExists(atPath: envPath) {
                silesiaPath = envPath
            } else if fm.fileExists(atPath: "Tests/TTZipTests/Fixtures/Silesia") {
                silesiaPath = "Tests/TTZipTests/Fixtures/Silesia"
            } else {
                silesiaPath = NSString(string: "~/Documents/dev/TTZip/Tests/TTZipTests/Fixtures/Silesia").expandingTildeInPath
            }
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
        
        let realPathCandidate = options.inputPath ?? options.positionals.first(where: { fm.fileExists(atPath: NSString(string: $0).expandingTildeInPath) })
        let isCompetitor = options.positionals.contains { $0.lowercased() == "--competitor" || $0.lowercased() == "-c" || $0.lowercased() == "competitor" || $0.lowercased() == "--pk" || $0.lowercased() == "-pk" || $0.lowercased() == "pk" } || options.competitorTools != nil
        
        if isCompetitor {
            await handleBenchPk(options: options)
        } else if let realPath = realPathCandidate {
            await CLIBenchmarkRunner.runRealFileBenchmark(
                inputPath: realPath,
                formatFilter: options.format,
                levelFilter: options.level,
                toolFilter: options.competitorTools,
                password: options.password,
                enableZeroCopy: options.enableZeroCopy
            )
        } else {
            let sizeRaw = options.positionals.first ?? "100MB"
            let isExhaustive = options.positionals.contains { $0.lowercased() == "--exhaustive" || $0.lowercased() == "-e" || $0.lowercased() == "exhaustive" } || options.format != nil
            if isExhaustive {
                await CLIBenchmarkRunner.runExhaustiveBenchmark(formatFilter: options.format, levelFilter: options.level)
            } else {
                await CLIBenchmarkRunner.runBenchmark(sizeRaw: sizeRaw)
            }
        }
    }
    
    private static func handleBenchPk(options: CLIOptions) async {
        let fm = FileManager.default
        let customPaths = options.positionals.filter { fm.fileExists(atPath: NSString(string: $0).expandingTildeInPath) }
        
        let config = BenchmarkRunConfig(
            selectedFormats: CLIArgumentParser.parseFormats(options.format != nil ? options.format : (options.allFormats ? "ALL" : nil)),
            selectedLevels: CLIArgumentParser.parseLevels(options.level),
            selectedTools: options.competitorTools?.split(separator: ",").map { String($0) },
            hugeSizeFilter: options.hugeSize,
            customFilePaths: customPaths.isEmpty ? nil : customPaths,
            stopOnLagOrError: options.stopOnLag,
            autoBestCompetitor: options.autoBestCompetitor || (options.competitorTools == nil),
            verifyAllDominance: options.verifyAllDominance,
            filterConfigPath: options.filterConfigPath,
            hugeOnly: options.hugeOnly
        )
        
        await CLIBenchmarkRunner.runCompetitorBenchmark(config: config)
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
        print("🗑️ Launching competitor toolchain uninstaller...")
        let results = await ToolchainInstaller.shared.uninstallCompetitorToolchains(tools: toolsToUninstall) { status in
            print("   [Uninstall] \(status)")
        }
        print("\nUninstallation Summary:")
        for (tool, ok) in results {
            print(" - \(tool): \(ok ? "✅ Successfully uninstalled" : "⚠️ Skipped / Not installed")")
        }
    }
    
    private static func handleBatchMacro(options: CLIOptions) async {
        print("🔗 Launching Command Pattern Transactional Macro Batch Operation...")
        guard options.positionals.count >= 2 else {
            print("Error: Batch operation requires output directory and at least one input. Example: ttzip-cli batch /path/to/out file1.txt file2.txt")
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
            print("✅ Transactional batch operation succeeded! Created \(result.artifactsCreated.count) artifacts in \(String(format: "%.2f", result.executionDuration))s")
        } catch let CommandError.macroExecutionFailed(idx, err, rollbacks) {
            print("❌ Macro command failed at step [\(idx + 1)]: \(err)")
            print("↩️ Triggered rollback to clean intermediate files. Result: \(rollbacks.isEmpty ? "All intermediate files cleaned" : rollbacks.joined(separator: "; "))")
        } catch {
            print("❌ Batch execution error: \(error.localizedDescription)")
        }
    }
    
    public static func printUsage() {
        print("""
        ================================================================
        TTZip CLI v1.0.0 — Native Archiving & Compression Engine (macOS)
        ================================================================
        Usage:
          ttzip-cli inspect <archive-path> [-p pwd]         Inspect archive hierarchy & metadata
          ttzip-cli extract <archive> <dest-dir> [-p pwd]   Extract archive safely to target folder
          ttzip-cli create <out> <files...> [-f 7z|zip] [-s 100m] [-p pwd] Compress archive
          ttzip-cli recover <archive> <dict.txt>           Parallel dictionary password recovery
          ttzip-cli bench [50MB|100MB|500MB|1GB]           Full-core hardware peak benchmark
          ttzip-cli bench_pk --all-formats --stop-on-lag    Full 16-format 1v1 competitor benchmark
          ttzip-cli clean / purge                           Purge test datasets & temporary caches
          ttzip-cli test <archive-path>                    Verify CRC32/SHA256 checksums
          ttzip-cli repair <damaged> <repaired>            Scan and repair corrupted archive chunks
          ttzip-cli batch <outDir> <files...>              Transactional batch compression
          ttzip-cli preset                                Display active compression presets
          ttzip-cli --version                              Display version information
        """)
    }
    
    private static func inspectArchive(path: String, password: String?) async {
        print("🔍 Inspecting archive metadata: \(path)...")
        do {
            let res = try await SmartLoggingProxy.shared.inspectArchive(archivePath: path, password: password)
            print("=================================================================")
            // Stream print entries using Iterator Pattern
            let iterator = res.makeIterator()
            while let entry = iterator.next() {
                let sizeStr = entry.isDirectory ? "<DIR>" : "\(entry.uncompressedSize) B"
                let p = entry.path.padding(toLength: 45, withPad: " ", startingAt: 0)
                let s = sizeStr.padding(toLength: 12, withPad: " ", startingAt: 0)
                print("\(p) | \(s) | \(entry.detectedEncoding)")
            }
            print("=================================================================")
            print("🌲 Composite Pattern Directory Hierarchy (DFS):")
            print(res.treeNode.renderTree())
            print("=================================================================")
            print("Total: \(res.entries.count) entries (\(res.treeNode.totalDirectoryCount()) directories, \(res.treeNode.totalFileCount()) files).")
            print(res.securityReport.detailMessage)
        } catch {
            print("❌ Inspection failed: \(error.localizedDescription)")
        }
    }
    
    private static func extractArchive(archivePath: String, destDir: String, password: String?) async {
        print("📦 Extracting archive safely: \(archivePath) -> \(destDir)...")
        do {
            let res = try await securityProxy.quickExtract(
                archivePath: archivePath,
                destinationDir: destDir,
                password: password
            )
            print(String(format: "✅ Extraction succeeded! Elapsed time: %.2fs", res.durationSeconds))
        } catch {
            print("❌ Extraction failed: \(error.localizedDescription)")
        }
    }
    
    private static func createArchive(
        outputPath: String,
        inputPaths: [String],
        options: CLIOptions
    ) async {
        print("⚡️ Compressing archive via Apple Silicon engine...")
        
        let formatRaw = options.format
        let splitSizeRaw = options.splitSize
        let levelRaw = options.level
        let password = options.password
        
        let format: ArchiveCompressionFormat
        switch (formatRaw ?? "").lowercased() {
        case "7z", "sevenzip": format = .sevenZip
        case "tar.zst", "tzst": format = .tarZst
        case "tar.gz", "tgz": format = .tarGz
        default: format = .zip
        }
        
        let compLevel: ArchiveCompressionLevel
        if let raw = levelRaw?.lowercased(), let intVal = Int(raw) {
            compLevel = ArchiveCompressionLevel(levelInt: intVal)
        } else {
            switch (levelRaw ?? "").lowercased() {
            case "store", "none", "copy": compLevel = .store
            case "fastest": compLevel = .fastest
            case "fast": compLevel = .fast
            case "medium": compLevel = .medium
            case "normal": compLevel = .normal
            case "maximum", "max": compLevel = .maximum
            case "ultra": compLevel = .ultra
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
        
        do {
            let res = try await securityProxy.quickCompress(
                inputs: inputPaths,
                outputPath: outputPath,
                format: format,
                level: compLevel,
                password: password,
                splitSize: splitBytes
            )
            print(String(format: "✅ Compression succeeded: \(res.outputPath) (elapsed: %.2fs, throughput: %.1f MB/s)", res.durationSeconds, res.throughputMBs))
        } catch {
            print("❌ Compression failed: \(error.localizedDescription)")
        }
    }
    
    private static func recoverPassword(archivePath: String, dictFilePath: String) async {
        print("🔑 Recovering password via full-core parallel dictionary attack: \(archivePath)...")
        guard let dictContent = try? String(contentsOfFile: dictFilePath, encoding: .utf8) else {
            print("❌ Could not read dictionary file: \(dictFilePath)")
            return
        }
        
        let dict = dictContent.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        print("📖 Loaded \(dict.count) dictionary entries")
        
        do {
            let res = try await facade.recoverPassword(archivePath: archivePath, dictionary: dict)
            if let pwd = res.foundPassword {
                print("🎉 Password recovery succeeded! Found valid password: [ \(pwd) ]")
                print("⏱️ Elapsed time: \(String(format: "%.3f", res.durationSeconds))s · Total attempts: \(res.totalAttempts) · Rate: \(String(format: "%.0f", res.attemptsPerSecond)) pwd/s")
            } else {
                print("❌ No matching password found in dictionary (attempted \(res.totalAttempts) candidates).")
            }
        } catch {
            print("❌ Recovery engine error: \(error.localizedDescription)")
        }
    }
    
    private static func testIntegrity(path: String) async {
        print("🛡️ Verifying 16MB page-aligned hardware hash and integrity: \(path)...")
        do {
            let res = try await TTZipEngineFacade.shared.verifyIntegrity(archivePath: path)
            print("CRC32 : \(res.crc32)")
            print("SHA256: \(res.sha256)")
            print("✅ Hash verification succeeded. No corruption detected!")
        } catch {
            print("❌ Hash verification failed: \(error.localizedDescription)")
        }
    }
    
    private static func repairArchive(damaged: String, output: String) async {
        print("🛠️ Scanning and repairing corrupted archive: \(damaged) -> \(output)...")
        do {
            let count = try await TTZipEngineFacade.shared.repairArchive(damagedPath: damaged, outputPath: output)
            print("✅ Repair complete! Successfully recovered \(count) valid file chunks to \(output)")
        } catch {
            print("❌ Repair failed: \(error.localizedDescription)")
        }
    }
    
    private static func printPresets() {
        print("📋 Active Compression Presets:")
        for preset in PresetManager.shared.presets {
            print(" - [\(preset.name)] Format: \(preset.format.rawValue) Split: \(preset.splitVolumeDescription)")
        }
    }
}
