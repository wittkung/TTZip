// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Fluent builder constructing `CompressCommand` instances.
public struct CompressCommandBuilder: Sendable {
    public var commandId: String = UUID().uuidString
    public var description: String? = nil
    public var inputs: [String] = []
    public var outputPath: String = ""
    public var format: ArchiveCompressionFormat = .zip
    public var level: ArchiveCompressionLevel = .normal
    public var password: String? = nil
    public var splitSize: Int64? = nil
    public var filterOptions: ArchiveFilterOptions = ArchiveFilterOptions()
    public var advancedOptions: ArchiveAdvancedOptions? = nil
    public var progress: (@Sendable (ArchiveProgress) -> Void)? = nil
    public var engineFacade: TTZipEngineFacading = TTZipEngineFacade.shared

    public init() {}

    public func withInputs(_ inputs: [String]) -> CompressCommandBuilder {
        var copy = self
        copy.inputs = inputs
        return copy
    }

    public func withOutputPath(_ path: String) -> CompressCommandBuilder {
        var copy = self
        copy.outputPath = path
        return copy
    }

    public func withFormat(_ format: ArchiveCompressionFormat) -> CompressCommandBuilder {
        var copy = self
        copy.format = format
        return copy
    }

    public func withLevel(_ level: ArchiveCompressionLevel) -> CompressCommandBuilder {
        var copy = self
        copy.level = level
        return copy
    }

    public func withPassword(_ pwd: String?) -> CompressCommandBuilder {
        var copy = self
        copy.password = pwd
        return copy
    }

    public func withSplitSize(_ size: Int64?) -> CompressCommandBuilder {
        var copy = self
        copy.splitSize = size
        return copy
    }

    public func withFilterOptions(_ options: ArchiveFilterOptions) -> CompressCommandBuilder {
        var copy = self
        copy.filterOptions = options
        return copy
    }

    public func withAdvancedOptions(_ options: ArchiveAdvancedOptions?) -> CompressCommandBuilder {
        var copy = self
        copy.advancedOptions = options
        return copy
    }

    public func withProgress(_ progress: (@Sendable (ArchiveProgress) -> Void)?) -> CompressCommandBuilder {
        var copy = self
        copy.progress = progress
        return copy
    }

    public func build() -> CompressCommand {
        return CompressCommand(
            commandId: commandId,
            description: description,
            inputs: inputs,
            outputPath: outputPath,
            format: format,
            level: level,
            password: password,
            splitSize: splitSize,
            filterOptions: filterOptions,
            advancedOptions: advancedOptions,
            progress: progress,
            engineFacade: engineFacade
        )
    }
}

public extension CompressCommand {
    static func builder() -> CompressCommandBuilder {
        return CompressCommandBuilder()
    }
}
