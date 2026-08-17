// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Intelligent terminal automatic pager dispatcher.
///
/// Automatically inspects terminal viewport dimensions (`TIOCGWINSZ`), line counts,
/// and delegates large outputs to `$PAGER` (or `less -RFX`) while providing transparent
/// fallback to stdout on non-TTY environments.
public enum TerminalPagerEngine: Sendable {
    
    /// Obtains the number of visible rows in the current terminal window.
    public static func getTerminalRows() -> Int {
        var ws = winsize()
        #if canImport(Darwin)
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0 && ws.ws_row > 0 {
            return Int(ws.ws_row)
        }
        #elseif canImport(Glibc)
        if ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &ws) == 0 && ws.ws_row > 0 {
            return Int(ws.ws_row)
        }
        #endif
        if let linesStr = ProcessInfo.processInfo.environment["LINES"], let lines = Int(linesStr), lines > 0 {
            return lines
        }
        return 24 // Standard fallback terminal height
    }
    
    /// Displays text adaptively to stdout or an external pager.
    /// - Parameters:
    ///   - text: Multi-line string content to render.
    ///   - noPager: Whether to bypass the pager (`--no-pager`).
    public static func display(text: String, noPager: Bool = false) {
        #if canImport(Darwin)
        let isTTY = Darwin.isatty(STDOUT_FILENO) != 0
        #elseif canImport(Glibc)
        let isTTY = Glibc.isatty(STDOUT_FILENO) != 0
        #else
        let isTTY = false
        #endif
        let termType = ProcessInfo.processInfo.environment["TERM"] ?? ""
        
        // 1. If not a TTY, TERM is dumb, or user explicitly requested no pager, print directly
        if !isTTY || noPager || termType == "dumb" {
            print(text)
            return
        }
        
        // 2. Count total lines of text
        let lineCount = text.split(separator: "\n", omittingEmptySubsequences: false).count
        let terminalRows = getTerminalRows()
        
        // 3. If line count fits within a single screen, print directly without spawning pager
        if lineCount < terminalRows {
            print(text)
            return
        }
        
        // 4. Dispatch to external pager
        let pagerCmd = ProcessInfo.processInfo.environment["TTZIP_PAGER"] ??
                       ProcessInfo.processInfo.environment["PAGER"] ??
                       "less -RFX"
        
        runWithPager(text: text, pagerCommand: pagerCmd)
    }
    
    private static func runWithPager(text: String, pagerCommand: String) {
        let parts = pagerCommand.split(separator: " ").map { String($0) }
        guard let execName = parts.first else {
            print(text)
            return
        }
        
        let args = Array(parts.dropFirst())
        let process = Process()
        
        if execName.starts(with: "/") {
            process.executableURL = URL(fileURLWithPath: execName)
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/\(execName)")
            if !FileManager.default.fileExists(atPath: process.executableURL?.path ?? "") {
                process.executableURL = URL(fileURLWithPath: "/bin/\(execName)")
            }
        }
        
        process.arguments = args
        let inputPipe = Pipe()
        process.standardInput = inputPipe
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError
        
        // Mask SIGPIPE to prevent crashing if the pager exits early
        #if canImport(Darwin)
        signal(SIGPIPE, SIG_IGN)
        #endif
        
        do {
            try process.run()
            if let data = text.data(using: .utf8) {
                inputPipe.fileHandleForWriting.write(data)
            }
            try? inputPipe.fileHandleForWriting.close()
            process.waitUntilExit()
        } catch {
            // Graceful fallback to stdout if spawning fails
            print(text)
        }
    }
}
