// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import QuartzCore
@_exported import CTTZipBridge

/// High-priority subprocess execution manager ensuring memory and pointer lifetime safety.
public enum TTZipProcessExecutor {
    
    @inline(__always)
    @discardableResult
    public static func runCLI(_ executable: String, _ arguments: [String], currentDirectory: String? = nil) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let cd = currentDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: cd)
        }
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    @inline(__always)
    public static func runCLIAsync(_ executable: String, _ arguments: [String], currentDirectory: String? = nil) async -> Bool {
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            if let cd = currentDirectory {
                process.currentDirectoryURL = URL(fileURLWithPath: cd)
            }
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            process.terminationHandler = { proc in
                continuation.resume(returning: proc.terminationStatus == 0)
            }
            do {
                try process.run()
            } catch {
                continuation.resume(returning: false)
            }
        }
    }
}
