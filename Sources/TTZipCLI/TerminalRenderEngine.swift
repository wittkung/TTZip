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

/// Terminal color palette capabilities.
public enum TerminalColorMode: Sendable {
    case disabled
    case ansi16
    case ansi256
    case trueColor
}

/// Adaptive ANSI terminal rendering and 60Hz rate-limited progress engine.
///
/// Features:
/// - Real-time monotonic clock throttling (~60Hz / 16.6ms frame budget).
/// - Dynamic terminal width detection (`TIOCGWINSZ`).
/// - Dual stream isolation: routes progress updates to `stderr` when stdout is redirected to a pipeline.
/// - Full NDJSON machine-readable telemetry stream emission.
public final class TerminalRenderEngine: @unchecked Sendable {
    public static let shared = TerminalRenderEngine()
    
    private let lock = NSLock()
    public let isInteractiveTTY: Bool
    public let isStderrTTY: Bool
    public let colorMode: TerminalColorMode
    public var progressRouting: StreamProgressRouting = .inlineTty
    
    private var lastRenderNanos: UInt64 = 0
    private let minRenderIntervalNanos: UInt64 = 16_666_666 // ~60Hz (16.6ms)
    
    private init() {
        #if canImport(Darwin)
        let isTTY = (Darwin.isatty(STDOUT_FILENO) != 0)
        let isErrTTY = (Darwin.isatty(STDERR_FILENO) != 0)
        #elseif canImport(Glibc)
        let isTTY = (Glibc.isatty(STDOUT_FILENO) != 0)
        let isErrTTY = (Glibc.isatty(STDERR_FILENO) != 0)
        #else
        let isTTY = false
        let isErrTTY = false
        #endif
        self.isInteractiveTTY = isTTY
        self.isStderrTTY = isErrTTY
        
        // Inspect NO_COLOR and terminal capabilities
        if ProcessInfo.processInfo.environment["NO_COLOR"] != nil || (!isTTY && !isErrTTY) {
            self.colorMode = .disabled
        } else if let colorTerm = ProcessInfo.processInfo.environment["COLORTERM"],
                  colorTerm == "truecolor" || colorTerm == "24bit" {
            self.colorMode = .trueColor
        } else if ProcessInfo.processInfo.environment["TERM"] == "dumb" {
            self.colorMode = .disabled
        } else {
            self.colorMode = .ansi256
        }
    }
    
    /// Obtains the number of columns in the current terminal window.
    public var terminalColumns: Int {
        var ws = winsize()
        #if canImport(Darwin)
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0 && ws.ws_col > 0 {
            return Int(ws.ws_col)
        }
        if ioctl(STDERR_FILENO, TIOCGWINSZ, &ws) == 0 && ws.ws_col > 0 {
            return Int(ws.ws_col)
        }
        #elseif canImport(Glibc)
        if ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &ws) == 0 && ws.ws_col > 0 {
            return Int(ws.ws_col)
        }
        if ioctl(STDERR_FILENO, UInt(TIOCGWINSZ), &ws) == 0 && ws.ws_col > 0 {
            return Int(ws.ws_col)
        }
        #endif
        if let colStr = ProcessInfo.processInfo.environment["COLUMNS"], let cols = Int(colStr), cols > 0 {
            return cols
        }
        return 80
    }
    
    /// Renders a rate-limited adaptive progress bar on the target stream.
    /// - Parameters:
    ///   - fraction: Completed fraction between 0.0 and 1.0.
    ///   - bytesProcessed: Number of bytes processed so far.
    ///   - totalBytes: Total byte size of payload.
    ///   - speedMBs: Instantaneous processing throughput in MB/s.
    ///   - currentFile: Filename of the item currently being compressed or extracted.
    ///   - operation: Action label (e.g. "Compressing", "Extracting").
    ///   - force: Whether to bypass the 60Hz frame rate throttle.
    public func renderProgress(
        fraction: Double,
        bytesProcessed: Int64,
        totalBytes: Int64,
        speedMBs: Double,
        currentFile: String,
        operation: String = "Processing",
        force: Bool = false
    ) {
        guard progressRouting != .suppressed else { return }
        let targetStream = (progressRouting == .standardError) ? stderr : stdout
        let isTargetTTY = (progressRouting == .standardError) ? isStderrTTY : isInteractiveTTY
        guard isTargetTTY else { return }
        
        let now = DispatchTime.now().uptimeNanoseconds
        lock.lock()
        if !force && (now - lastRenderNanos < minRenderIntervalNanos) {
            lock.unlock()
            return
        }
        lastRenderNanos = now
        lock.unlock()
        
        let cols = terminalColumns
        let clampedFraction = min(max(fraction, 0.0), 1.0)
        let percent = Int(clampedFraction * 100)
        
        let speedStr = String(format: "%.1f MB/s", speedMBs)
        let processedStr = formatSize(bytesProcessed)
        let totalStr = formatSize(totalBytes)
        
        let prefix = "[\(operation)] \(percent)%"
        let stats = "(\(processedStr)/\(totalStr) | \(speedStr))"
        
        let reserved = prefix.count + stats.count + 4
        let barWidth = min(max(cols - reserved, 10), 40)
        
        let filledCount = Int(Double(barWidth) * clampedFraction)
        let emptyCount = max(barWidth - filledCount, 0)
        
        let filledBar = String(repeating: "━", count: filledCount)
        let emptyBar = String(repeating: "─", count: emptyCount)
        
        let bar = "\(filledBar)\(emptyBar)"
        let output = "\r\u{001B}[2K\(prefix) [\(bar)] \(stats)"
        
        fputs(output, targetStream)
        fflush(targetStream)
    }
    
    /// Concludes progress rendering and moves to a clean new line.
    /// - Parameter message: Optional completion message to emit.
    public func completeProgress(message: String? = nil) {
        guard progressRouting != .suppressed else { return }
        let targetStream = (progressRouting == .standardError) ? stderr : stdout
        let isTargetTTY = (progressRouting == .standardError) ? isStderrTTY : isInteractiveTTY
        if isTargetTTY {
            fputs("\r\u{001B}[2K", targetStream)
            if let msg = message {
                fputs("\(msg)\n", targetStream)
            }
            fflush(targetStream)
        }
    }
    
    /// Emits a single machine-readable NDJSON telemetry event line to stdout.
    /// - Parameters:
    ///   - event: Event type identifier.
    ///   - payload: Structured event properties.
    public func emitNDJSON(event: String, payload: [String: Any]) {
        var dict: [String: Any] = [
            "event": event,
            "timestamp": Date().timeIntervalSince1970
        ]
        dict[event] = payload
        
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
           let str = String(data: data, encoding: .utf8) {
            fputs("\(str)\n", stdout)
            fflush(stdout)
        }
    }
    
    /// Logs an error or warning message directly to standard error.
    /// - Parameter message: Error description string.
    public func logError(_ message: String) {
        fputs("\(message)\n", stderr)
        fflush(stderr)
    }
    
    private func formatSize(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        let kb = Double(bytes) / 1024.0
        if kb < 1024 { return String(format: "%.1f KB", kb) }
        let mb = kb / 1024.0
        if mb < 1024 { return String(format: "%.1f MB", mb) }
        let gb = mb / 1024.0
        return String(format: "%.2f GB", gb)
    }
}
