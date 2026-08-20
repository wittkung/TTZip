// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Safe asynchronous subprocess execution and pipe draining service.
public final class SubprocessExecutor: Sendable {
    public static let shared = SubprocessExecutor()
    private init() {}
    
    /// Synchronously executes a subprocess streaming stdout/stderr line-by-line.
    public func executeProcess(
        executablePath: String,
        arguments: [String],
        currentDirectory: String? = nil,
        progressRegexPattern: String? = nil,
        onOutput: (@Sendable (String) -> Void)? = nil
    ) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        if let dir = currentDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: dir)
        }
        
        let pipe = Pipe()
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = pipe
        process.standardError = pipe
        
        let fileHandle = pipe.fileHandleForReading
        defer { try? fileHandle.close() }
        
        fileHandle.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            onOutput?(text)
        }
        
        try process.run()
        process.waitUntilExit()
        fileHandle.readabilityHandler = nil
        
        return process.terminationStatus
    }
    
    /// Asynchronously executes a subprocess and returns exit code and captured text output.
    public func executeAsync(
        executablePath: String,
        arguments: [String],
        currentDirectory: String? = nil
    ) async throws -> (exitCode: Int32, output: String) {
        return try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments
            if let dir = currentDirectory {
                process.currentDirectoryURL = URL(fileURLWithPath: dir)
            }
            let pipe = Pipe()
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = pipe
            process.standardError = pipe

            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let text = String(data: data, encoding: .utf8) ?? ""
            return (process.terminationStatus, text)
        }.value
    }
}
