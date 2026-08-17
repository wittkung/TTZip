// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Weitao Kung (Witt Kung) <kevintungs@163.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import TTZipCore

@main
struct TTZipCLIMain {
    static func main() async {
        // Initialize low-level C engine subsystems and signal handlers
        TTZipEngineFacade.initializeSubsystems()
        
        let rawArgs = Array(CommandLine.arguments.dropFirst())
        
        guard !rawArgs.isEmpty else {
            CLICommandRouter.printUsage()
            exit(EXIT_FAILURE)
        }
        
        let command = CLICommand(commandString: rawArgs[0])
        let options = CLIArgumentParser.parse(args: Array(rawArgs.dropFirst()))
        
        await CLICommandRouter.route(command: command, options: options)
    }
}
