// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import TTZipCore

extension CLICommandRouter {
    static func handleCreateArchive(outputPath: String, inputPaths: [String], options: CLIOptions) async -> CLIExitCode {
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
}
