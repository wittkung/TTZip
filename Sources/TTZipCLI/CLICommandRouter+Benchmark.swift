// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import TTZipCore

extension CLICommandRouter {
    static func handleBench(options: CLIOptions) async {
        if options.inMemory || options.turboBenchCompat || options.recommend || options.pareto || options.plot || options.svgOutPath != nil || options.transferSheet || options.thermalGuard {
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
    
    static func handleBenchPk(options: CLIOptions) async {
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
    
    static func handleUninstall(options: CLIOptions) async {
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
}
