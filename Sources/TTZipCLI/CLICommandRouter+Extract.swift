// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import TTZipCore
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

extension CLICommandRouter {
    static func handleExtractArchive(archivePath: String, destDir: String, options: CLIOptions) async -> CLIExitCode {
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
        
        // Direct stdout streaming extraction mode
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
            let res = try await facade.quickExtract(
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
    
    static func handleCatArchive(archivePath: String, entryPath: String?, options: CLIOptions) async -> CLIExitCode {
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
        
        let tempDir = (NSTemporaryDirectory() as NSString).appendingPathComponent("TTZip_Cat_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }
        
        let extractor = ArchiveExtractor()
        do {
            try extractor.extractSync(archivePath: effectivePath, destinationDir: tempDir, password: pwd)
        } catch {
            TerminalRenderEngine.shared.logError("ttzip-cli: error: stream extraction failed: \(error.localizedDescription)")
            return .dataError
        }
        
        let targetFile: String
        if let entry = entryPath {
            targetFile = (tempDir as NSString).appendingPathComponent(entry)
        } else {
            let items = (try? FileManager.default.subpathsOfDirectory(atPath: tempDir)) ?? []
            guard let first = items.first(where: { item in
                var isDir: ObjCBool = false
                let path = (tempDir as NSString).appendingPathComponent(item)
                return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && !isDir.boolValue
            }) else {
                TerminalRenderEngine.shared.logError("ttzip-cli: error: no file entries found in archive")
                return .noInput
            }
            targetFile = (tempDir as NSString).appendingPathComponent(first)
        }
        
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: targetFile)) else {
            TerminalRenderEngine.shared.logError("ttzip-cli: error: entry '\(entryPath ?? "*")' not found in '\(archivePath)'")
            return .noInput
        }
        
        data.withUnsafeBytes { ptr in
            if let base = ptr.baseAddress {
                #if canImport(Darwin)
                _ = Darwin.write(STDOUT_FILENO, base, data.count)
                #elseif canImport(Glibc)
                _ = Glibc.write(STDOUT_FILENO, base, data.count)
                #endif
            }
        }
        return .ok
    }
}
