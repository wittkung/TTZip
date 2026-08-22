// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import TTZipCore

extension POSIXCLIArgumentParser {
    
    /// Parses POSIX / UNIX short flags and flag clusters starting with single `-`.
    internal static func parseShortOptions(
        token: String,
        args: [String],
        currentIndex: inout Int,
        options: inout CLIOptions,
        detectedCommand: inout CLICommand
    ) {
        let flags = Array(token.dropFirst())
        var flagIdx = 0
        
        while flagIdx < flags.count {
            let char = flags[flagIdx]
            
            switch char {
            case "h":
                detectedCommand = .help
            case "V":
                detectedCommand = .version
            case "v":
                options.verbosity += 1
            case "q":
                options.verbosity = -1
            case "y":
                options.assumeYes = true
            case "k":
                options.keepTempFiles = true
            case "f":
                if detectedCommand == .archive || detectedCommand == .create {
                    let rest = String(flags[(flagIdx + 1)...])
                    if !rest.isEmpty {
                        options.format = rest
                        flagIdx = flags.count
                    } else if currentIndex + 1 < args.count && !args[currentIndex + 1].starts(with: "-") {
                        options.format = args[currentIndex + 1]
                        currentIndex += 1
                    } else {
                        options.force = true
                    }
                } else {
                    options.force = true
                }
            case "j":
                options.flattenPaths = true
            case "0":
                options.nullDelimiter = true
            case "O", "c":
                options.toStdout = true
            case "n":
                options.overwritePolicy = "never"
            case "o":
                let rest = String(flags[(flagIdx + 1)...])
                if !rest.isEmpty {
                    options.outputPath = rest
                    flagIdx = flags.count
                } else if currentIndex + 1 < args.count {
                    options.outputPath = args[currentIndex + 1]
                    currentIndex += 1
                }
            case "p":
                let rest = String(flags[(flagIdx + 1)...])
                if !rest.isEmpty {
                    options.password = rest
                    flagIdx = flags.count
                } else if currentIndex + 1 < args.count {
                    options.password = args[currentIndex + 1]
                    currentIndex += 1
                }
            case "P":
                let rest = String(flags[(flagIdx + 1)...])
                if !rest.isEmpty {
                    options.passwordFile = rest
                    flagIdx = flags.count
                } else if currentIndex + 1 < args.count {
                    options.passwordFile = args[currentIndex + 1]
                    currentIndex += 1
                }
            case "l":
                let rest = String(flags[(flagIdx + 1)...])
                if !rest.isEmpty {
                    options.level = rest
                    flagIdx = flags.count
                } else if currentIndex + 1 < args.count {
                    options.level = args[currentIndex + 1]
                    currentIndex += 1
                }
            case "s":
                let rest = String(flags[(flagIdx + 1)...])
                if !rest.isEmpty {
                    options.splitSize = rest
                    flagIdx = flags.count
                } else if currentIndex + 1 < args.count {
                    options.splitSize = args[currentIndex + 1]
                    currentIndex += 1
                }
            case "x":
                let rest = String(flags[(flagIdx + 1)...])
                if !rest.isEmpty {
                    options.excludePatterns.append(rest)
                    flagIdx = flags.count
                } else if currentIndex + 1 < args.count {
                    options.excludePatterns.append(args[currentIndex + 1])
                    currentIndex += 1
                }
            case "i":
                let rest = String(flags[(flagIdx + 1)...])
                let val = !rest.isEmpty ? rest : (currentIndex + 1 < args.count ? args[currentIndex + 1] : nil)
                if detectedCommand == .extract || detectedCommand == .cat || detectedCommand == .list || detectedCommand == .inspect {
                    if let v = val, v == "-" || (!v.contains("*") && !v.contains("?")) {
                        options.inputPath = v
                        if rest.isEmpty { currentIndex += 1 }
                        flagIdx = flags.count
                        break
                    }
                }
                if !rest.isEmpty {
                    options.includePatterns.append(rest)
                    flagIdx = flags.count
                } else if currentIndex + 1 < args.count {
                    options.includePatterns.append(args[currentIndex + 1])
                    currentIndex += 1
                }
            case "T":
                let rest = String(flags[(flagIdx + 1)...])
                if !rest.isEmpty {
                    options.filesFromPath = rest
                    flagIdx = flags.count
                } else if currentIndex + 1 < args.count {
                    options.filesFromPath = args[currentIndex + 1]
                    currentIndex += 1
                }
            case "d":
                let rest = String(flags[(flagIdx + 1)...])
                if !rest.isEmpty, let num = Int(rest) {
                    options.treeDepth = max(0, num)
                    flagIdx = flags.count
                } else if currentIndex + 1 < args.count, let num = Int(args[currentIndex + 1]) {
                    options.treeDepth = max(0, num)
                    currentIndex += 1
                }
            default:
                break
            }
            flagIdx += 1
        }
    }
}
