// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import TTZipCore
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Main executable entry point for the `ttzip-cli` command-line utility.
///
/// Handles early signal masking (e.g. SIGPIPE protection for UNIX pipelines), initializes
/// low-level static C engine subsystems, parses command-line arguments, and dispatches
/// execution to the appropriate command handler while returning standard POSIX exit codes.
@main
struct TTZipCLIMain {
    
    /// Asynchronous application main entry point.
    static func main() async {
        // Initialize in-process static C engine bindings and signal traps
        TTZipEngineFacade.initializeSubsystems()
        
        let rawArgs = Array(CommandLine.arguments.dropFirst())
        
        guard !rawArgs.isEmpty else {
            CLICommandRouter.printUsage()
            exit(EXIT_FAILURE)
        }
        
        let command = CLICommand(commandString: rawArgs[0])
        let options = CLIArgumentParser.parse(args: Array(rawArgs.dropFirst()))
        
        let exitCode = await CLICommandRouter.route(command: command, options: options)
        exit(exitCode.rawValue)
    }
}
