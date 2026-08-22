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

/// Stream pipeline execution topology mode.
public enum StreamExecutionMode: String, Sendable, Equatable, CaseIterable {
    /// Reading and writing physical files on disk.
    case directFile = "directFile"
    /// Reading archive data from stdin, extracting to destination directory.
    case standardInputPipe = "standardInputPipe"
    /// Reading input from disk, streaming archive payload to stdout.
    case standardOutputPipe = "standardOutputPipe"
    /// Reading from stdin and streaming output to stdout.
    case duplexPipe = "duplexPipe"
    /// Extracting a single entry from an archive directly to stdout (zero disk staging).
    case singleEntryStdout = "singleEntryStdout"
}

/// Progress and telemetry event routing policy.
public enum StreamProgressRouting: String, Sendable, Equatable, CaseIterable {
    /// Completely suppress progress bars and interactive logs.
    case suppressed = "suppressed"
    /// Route progress updates to standard error (preserving pure binary output on stdout).
    case standardError = "standardError"
    /// Output inline on standard output (allowed only when stdout is a TTY and not a binary pipe).
    case inlineTty = "inlineTty"
}

/// Target shell for auto-completion generation.
public enum ShellTarget: String, Sendable, Equatable, CaseIterable {
    case zsh = "zsh"
    case bash = "bash"
    case fish = "fish"
    case nushell = "nushell"
}

/// Strongly-typed pipeline streaming configuration.
public struct StreamPipelineConfig: Sendable, Equatable {
    public let mode: StreamExecutionMode
    public let inputPath: String?
    public let outputPath: String?
    public let singleEntryName: String?
    public let forceBinary: Bool
    public let progressRouting: StreamProgressRouting
    public let streamBlockSize: Int
    
    public init(
        mode: StreamExecutionMode,
        inputPath: String? = nil,
        outputPath: String? = nil,
        singleEntryName: String? = nil,
        forceBinary: Bool = false,
        progressRouting: StreamProgressRouting = .standardError,
        streamBlockSize: Int = 65536
    ) {
        self.mode = mode
        self.inputPath = inputPath
        self.outputPath = outputPath
        self.singleEntryName = singleEntryName
        self.forceBinary = forceBinary
        self.progressRouting = progressRouting
        self.streamBlockSize = streamBlockSize
    }
}

/// Standard I/O stream pipe adapter.
///
/// Manages TTY detection, pipe buffer sizing, stdin spooling, and clean error propagation.
public enum StreamPipeAdapter {
    
    /// Checks whether a given path string represents standard I/O (`"-"`).
    @inline(__always)
    public static func isStandardStream(_ path: String?) -> Bool {
        guard let p = path?.trimmingCharacters(in: .whitespaces) else { return false }
        return p == "-"
    }
    
    /// Checks whether stdout is connected to an interactive terminal TTY.
    @inline(__always)
    public static func isStdoutTTY() -> Bool {
        #if canImport(Darwin)
        return Darwin.isatty(STDOUT_FILENO) != 0
        #elseif canImport(Glibc)
        return Glibc.isatty(STDOUT_FILENO) != 0
        #else
        return false
        #endif
    }
    
    /// Checks whether stderr is connected to an interactive terminal TTY.
    @inline(__always)
    public static func isStderrTTY() -> Bool {
        #if canImport(Darwin)
        return Darwin.isatty(STDERR_FILENO) != 0
        #elseif canImport(Glibc)
        return Glibc.isatty(STDERR_FILENO) != 0
        #else
        return false
        #endif
    }
    
    /// Checks whether stdin is connected to an interactive terminal TTY.
    @inline(__always)
    public static func isStdinTTY() -> Bool {
        #if canImport(Darwin)
        return Darwin.isatty(STDIN_FILENO) != 0
        #elseif canImport(Glibc)
        return Glibc.isatty(STDIN_FILENO) != 0
        #else
        return false
        #endif
    }
    
    /// Determines the execution stream topology mode based on input and output parameters.
    public static func determineMode(
        inputPath: String?,
        outputPath: String?,
        isCat: Bool = false,
        entryName: String? = nil
    ) -> StreamExecutionMode {
        if isCat || entryName != nil {
            return .singleEntryStdout
        }
        let inStd = isStandardStream(inputPath)
        let outStd = isStandardStream(outputPath)
        
        if inStd && outStd {
            return .duplexPipe
        } else if inStd {
            return .standardInputPipe
        } else if outStd {
            return .standardOutputPipe
        } else {
            return .directFile
        }
    }
    
    /// Computes the appropriate progress output routing policy.
    public static func determineProgressRouting(
        mode: StreamExecutionMode,
        isQuiet: Bool = false
    ) -> StreamProgressRouting {
        if isQuiet {
            return .suppressed
        }
        switch mode {
        case .standardOutputPipe, .duplexPipe, .singleEntryStdout:
            return isStderrTTY() ? .standardError : .suppressed
        case .standardInputPipe, .directFile:
            return isStdoutTTY() ? .inlineTty : (isStderrTTY() ? .standardError : .suppressed)
        }
    }
    
    /// Reads standard input into an anonymous temporary spool file for random-access archives.
    public static func readStdinToTemporaryFileIfNeeded(suffix: String = ".tmp") throws -> (path: String, isTemporary: Bool) {
        let chunkSize = 64 * 1024 // 64 KB
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: chunkSize)
        defer { buffer.deallocate() }
        
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("ttzip_stdin_\(UUID().uuidString)\(suffix)")
        
        FileManager.default.createFile(atPath: tempFile.path, contents: nil)
        guard let handle = try? FileHandle(forWritingTo: tempFile) else {
            throw NSError(
                domain: "TTZipStreamPipe",
                code: 73,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create temporary stdin spool file"]
            )
        }
        
        defer { try? handle.close() }
        
        var totalRead: Int64 = 0
        while true {
            #if canImport(Darwin)
            let bytesRead = Darwin.read(STDIN_FILENO, buffer, chunkSize)
            #elseif canImport(Glibc)
            let bytesRead = Glibc.read(STDIN_FILENO, buffer, chunkSize)
            #else
            let bytesRead = 0
            #endif
            if bytesRead <= 0 { break }
            
            let data = Data(bytesNoCopy: buffer, count: bytesRead, deallocator: .none)
            handle.write(data)
            totalRead += Int64(bytesRead)
        }
        
        return (tempFile.path, true)
    }
    
    /// Removes temporary stream cache file.
    public static func cleanupTemporaryFile(_ path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }
}
