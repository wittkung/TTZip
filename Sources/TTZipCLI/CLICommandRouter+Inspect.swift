// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import TTZipCore

extension CLICommandRouter {
    static func handleTreeArchive(path: String, options: CLIOptions) async -> CLIExitCode {
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
    
    static func handleInspectArchive(path: String, password: String?, options: CLIOptions) async -> CLIExitCode {
        if !FileManager.default.fileExists(atPath: path) {
            TerminalRenderEngine.shared.logError("ttzip-cli: error: input file '\(path)' does not exist")
            return .noInput
        }
        
        do {
            let res = try await SmartLoggingProxy.shared.inspectArchive(archivePath: path, password: password)
            if options.jsonOutput {
                var entriesJSON: [[String: Any]] = []
                for e in res.entries {
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
                for entry in res.entries {
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
    
    static func handleHashArchive(path: String, options: CLIOptions) async -> CLIExitCode {
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
}
