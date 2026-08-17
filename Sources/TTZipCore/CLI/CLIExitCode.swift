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

/// Strongly-typed command-line exit codes conforming to Darwin / BSD POSIX `<sysexits.h>`.
public enum CLIExitCode: Int32, Sendable {
    /// Successful termination (`EX_OK`).
    case ok = 0
    
    /// Command line syntax or usage error (`EX_USAGE`).
    case usage = 64
    
    /// Data format error, magic signature mismatch, CRC failure, or wrong password (`EX_DATAERR`).
    case dataError = 65
    
    /// Input file or directory missing or unreadable (`EX_NOINPUT`).
    case noInput = 66
    
    /// Service or requested compression engine unavailable (`EX_UNAVAILABLE`).
    case unavailable = 69
    
    /// Internal software exception or invariant assertion failure (`EX_SOFTWARE`).
    case software = 70
    
    /// Cannot create output file or directory (`EX_CANTCREAT`).
    case cantCreate = 73
    
    /// Physical I/O failure or broken pipe `EPIPE` (`EX_IOERR`).
    case ioError = 74
    
    /// Permission denied (`EX_NOPERM`).
    case noPermission = 77
    
    /// Terminated by user interrupt (`SIGINT = 128 + 2`).
    case sigint = 130
    
    /// Broken downstream pipeline (`SIGPIPE = 128 + 13`).
    case sigpipe = 141
    
    /// Terminates the current process with this exit code.
    public func exit() -> Never {
        #if canImport(Darwin)
        Darwin.exit(self.rawValue)
        #elseif canImport(Glibc)
        Glibc.exit(self.rawValue)
        #else
        Foundation.exit(self.rawValue)
        #endif
    }
}
