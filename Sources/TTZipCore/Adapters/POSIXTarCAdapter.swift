// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import Darwin
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
        var actions: posix_spawn_file_actions_t? = nil
        posix_spawn_file_actions_init(&actions)
        defer { posix_spawn_file_actions_destroy(&actions) }
        
        let devNull = open("/dev/null", O_RDWR)
        defer {
            if devNull >= 0 {
                close(devNull)
            }
        }
        if devNull >= 0 {
            posix_spawn_file_actions_adddup2(&actions, devNull, STDIN_FILENO)
            posix_spawn_file_actions_adddup2(&actions, devNull, STDOUT_FILENO)
            posix_spawn_file_actions_adddup2(&actions, devNull, STDERR_FILENO)
        }
        
        if let wd = workingDirectory, !wd.isEmpty {
            posix_spawn_file_actions_addchdir_np(&actions, wd)
        }
        
        var attr: posix_spawnattr_t? = nil
        posix_spawnattr_init(&attr)
        defer { posix_spawnattr_destroy(&attr) }
        posix_spawnattr_setflags(&attr, Int16(POSIX_SPAWN_CLOEXEC_DEFAULT))
        
        let fullArgs = [binaryPath] + arguments
        var cArgs: [UnsafeMutablePointer<CChar>?] = fullArgs.map { strdup($0) }
        cArgs.append(nil)
        defer {
            for ptr in cArgs where ptr != nil {
                free(ptr)
            }
        }
        
        var pid: pid_t = 0
        let spawnStatus = posix_spawn(&pid, binaryPath, &actions, &attr, cArgs, nil)
        if spawnStatus != 0 {
            return spawnStatus
        }
        
        var status: Int32 = 0
        while waitpid(pid, &status, 0) < 0 {
            if errno != EINTR {
                return -1
            }
        }
        
        if (status & 0x7F) == 0 {
            return (status >> 8) & 0xFF
        } else if ((status & 0x7F) + 1) >> 1 > 0 {
            return 128 + (status & 0x7F)
        }
        return -1
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
        return CUnsafeBufferAdapter.withCString(archivePath) { cArchivePath in
            CUnsafeBufferAdapter.withCString(destinationDir) { cDestDir in
                guard let cArchivePath = cArchivePath, let cDestDir = cDestDir else { return false }
                var opt = TTZipExtractOptions(
                    destination_path: cDestDir,
                    password: nil,
                    thread_budget: 0,
                    overwrite_existing: true,
                    preserve_permissions: true,
                    dry_run: false,
                    progress_callback: nil,
                    user_data: nil
                )
                let status = ttzip_rust_extract_archive(cArchivePath, cDestDir, &opt)
                return status == TTZIP_STATUS_OK
            }
        }
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
        return CUnsafeBufferAdapter.withCString(outputPath) { cOutputPath in
            CUnsafeBufferAdapter.withCStringsArray(fullInputPaths) { cInputPaths in
                guard let cOutputPath = cOutputPath else { return false }
                var opt = TTZipCreateOptions(
                    format: TTZIP_ARCHIVE_FORMAT_TAR,
                    level: TTZIP_COMPRESSION_LEVEL_STORE,
                    encryption: TTZIP_ENCRYPTION_NONE,
                    password: nil,
                    thread_budget: 0,
                    solid_block_size_mb: 0,
                    progress_callback: nil,
                    user_data: nil
                )
                let status = ttzip_rust_create_archive(cInputPaths, fullInputPaths.count, cOutputPath, &opt)
                return status == TTZIP_STATUS_OK
            }
        }
    }
}
