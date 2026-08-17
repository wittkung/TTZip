// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Command-line argument parser facade providing unified option parsing and format filtering.
public enum CLIArgumentParser {
    
    /// Parses raw command-line arguments into strongly-typed `CLIOptions`.
    /// - Parameter args: Array of string arguments passed from `CommandLine.arguments`.
    /// - Returns: Fully populated `CLIOptions` structure.
    public static func parse(args: [String]) -> CLIOptions {
        let result = POSIXCLIArgumentParser.parse(args: args)
        return result.options
    }
    
    /// Parses raw command-line arguments into both a target `CLICommand` and its associated `CLIOptions`.
    /// - Parameter args: Array of string arguments.
    /// - Returns: Tuple of parsed command and option configuration.
    public static func parseCommandAndOptions(args: [String]) -> (command: CLICommand, options: CLIOptions) {
        let result = POSIXCLIArgumentParser.parse(args: args)
        return (result.command, result.options)
    }
    
    /// Parses comma-separated format filter string into matching `ArchiveCompressionFormat` cases.
    /// - Parameter filter: Optional raw filter string (e.g. "zip,7z,tar.zst" or "ALL").
    /// - Returns: Array of selected format enums, or nil if no filter or "ALL" was supplied.
    public static func parseFormats(_ filter: String?) -> [ArchiveCompressionFormat]? {
        guard let filter = filter, !filter.isEmpty, filter.uppercased() != "ALL" else {
            return nil
        }
        let items = filter.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        var result: [ArchiveCompressionFormat] = []
        for item in items {
            if let fmt = ArchiveCompressionFormat.from(extensionOrName: item) {
                result.append(fmt)
            } else if item == "zip" {
                result.append(.zip)
            } else if item == "7z" || item == "7zip" {
                result.append(.sevenZip)
            } else if item == "tar.zst" || item == "tzst" || item == "zst" {
                result.append(.zst)
            } else if item == "tar.gz" || item == "tgz" || item == "gz" {
                result.append(.gz)
            } else if item == "tar.bz2" || item == "tbz2" || item == "bz2" {
                result.append(.bz2)
            } else if item == "tar.xz" || item == "txz" || item == "xz" {
                result.append(.xz)
            }
        }
        return result.isEmpty ? nil : result
    }
    
    /// Parses comma-separated compression level integers.
    /// - Parameter raw: Optional string containing level identifiers (e.g. "1,5,9").
    /// - Returns: Array of parsed `ArchiveCompressionLevel` values, or nil if empty.
    public static func parseLevels(_ raw: String?) -> [ArchiveCompressionLevel]? {
        guard let r = raw, !r.isEmpty else { return nil }
        let parts = r.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        guard !parts.isEmpty else { return nil }
        return parts.map { ArchiveCompressionLevel(levelInt: $0) }
    }
}
