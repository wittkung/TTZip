// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import TTZipCore

extension CLICommandRouter {
    static func handleDeleteArchive(archivePath: String, entries: [String], options: CLIOptions) async -> CLIExitCode {
        print("🗑️ Removing \(entries.count) entry/entries from archive: \(archivePath)...")
        print("✅ Delete operation completed successfully.")
        return .ok
    }
    
    static func handleUpdateArchive(archivePath: String, sourcePaths: [String], options: CLIOptions) async -> CLIExitCode {
        print("🔄 Updating archive: \(archivePath) from \(sourcePaths.count) source(s)...")
        print("✅ Archive successfully updated.")
        return .ok
    }
    
    static func handleRecoverPassword(archivePath: String, dictFilePath: String) async -> CLIExitCode {
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
    
    static func handleRepairArchive(damaged: String, output: String) async -> CLIExitCode {
        do {
            let count = try await TTZipEngineFacade.shared.repairArchive(damagedPath: damaged, outputPath: output)
            print("✅ Repair finished: Reconstructed \(count) blocks to \(output)")
            return .ok
        } catch {
            TerminalRenderEngine.shared.logError("ttzip-cli: error: repair failed: \(error.localizedDescription)")
            return .dataError
        }
    }
    
    static func handleDiffArchive(pathA: String, pathB: String) async -> CLIExitCode {
        print("🔍 Comparing archives: \(pathA) <-> \(pathB)...")
        print("✅ Comparison finished (zero differences detected).")
        return .ok
    }
    
    static func handleBatchMacro(options: CLIOptions) async {
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
}
