// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// Adapter Pattern: POSIX Tar and accelerated posix_spawn adapter.
///
/// Bridges native C-level in-process TAR creation and extraction primitives with
/// Swift high-level archiving contracts.
public final class POSIXTarCAdapter: POSIXTarEngineProtocol, Sendable {
    public static let shared = POSIXTarCAdapter()
    
    private init() {}
    
    /// Spawns a child process using optimized `posix_spawn` routines.
    /// - Parameters:
    ///   - binaryPath: Full path to target executable binary.
    ///   - arguments: Command-line arguments.
    ///   - workingDirectory: Optional directory to execute within.
    /// - Returns: Process termination status code.
    public func spawnProcess(
        binaryPath: String,
        arguments: [String],
        workingDirectory: String? = nil
    ) throws -> Int32 {
        let fullArgs = [binaryPath] + arguments
        return CUnsafeBufferAdapter.withCString(binaryPath) { cBinPath in
            CUnsafeBufferAdapter.withCStringsNullTerminatedArray(fullArgs) { cArgv in
                CUnsafeBufferAdapter.withCString(workingDirectory) { cWorkDir in
                    guard let cBinPath = cBinPath else { return Int32(-1) }
                    return ttzip_core_posix_spawn_fast(cBinPath, cArgv, cWorkDir)
                }
            }
        }
    }
    
    /// Extracts a TAR archive in-process using native C static library bindings.
    /// - Parameters:
    ///   - archivePath: Path to input TAR archive file.
    ///   - destinationDir: Target extraction directory path.
    /// - Returns: `true` if extraction succeeded cleanly, otherwise `false`.
    public func extractTar(
        archivePath: String,
        destinationDir: String
    ) throws -> Bool {
        try FileManager.default.createDirectory(atPath: destinationDir, withIntermediateDirectories: true)
        let status = ttzip_extract_tar_native_c(archivePath, destinationDir, false)
        return status == 0
    }
    
    /// Creates a TAR archive in-process using native C static library bindings.
    /// - Parameters:
    ///   - outputPath: Target output archive path.
    ///   - inputPaths: Array of source file and directory paths.
    ///   - workingDirectory: Optional base path for relative source paths.
    /// - Returns: `true` if creation succeeded cleanly, otherwise `false`.
    public func createTar(
        outputPath: String,
        inputPaths: [String],
        workingDirectory: String? = nil
    ) throws -> Bool {
        let fullInputPaths: [String] = inputPaths.map { p in
            if p.hasPrefix("/") {
                return p
            } else if let wd = workingDirectory {
                return (wd as NSString).appendingPathComponent(p)
            } else {
                return p
            }
        }
        let status = CUnsafeBufferAdapter.withCStringsArray(fullInputPaths) { cInputPaths in
            ttzip_create_tar_native_c(outputPath, "tar", cInputPaths, fullInputPaths.count, false, 1)
        }
        return status == 0
    }
}
