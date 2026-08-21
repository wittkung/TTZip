// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Authoritative registry mapping all supported formats to official standards specifications.
public final class ArchiveFormatStandardRegistry: @unchecked Sendable {
    public static let shared = ArchiveFormatStandardRegistry()

    private let lock = NSLock()
    private var specsByFormat: [ArchiveCompressionFormat: ArchiveFormatStandardSpec] = [:]
    private var specsById: [String: ArchiveFormatStandardSpec] = [:]

    public init() {
        registerArchiveSpecs()
        registerStreamSpecs()
        registerDiskImageSpecs()
    }

    /// Retrieve format standard specification by typed enum format.
    public func spec(for format: ArchiveCompressionFormat) -> ArchiveFormatStandardSpec? {
        lock.lock()
        defer { lock.unlock() }
        return specsByFormat[format]
    }

    /// Retrieve format standard specification by identifier string (e.g. "zip", "7z", "tar.zst").
    public func spec(forId id: String) -> ArchiveFormatStandardSpec? {
        lock.lock()
        defer { lock.unlock() }
        return specsById[id.lowercased()]
    }

    /// Retrieve all registered format specifications.
    public func allSpecs() -> [ArchiveFormatStandardSpec] {
        lock.lock()
        defer { lock.unlock() }
        return Array(specsByFormat.values)
    }

    /// Register or overwrite a specification.
    public func register(spec: ArchiveFormatStandardSpec) {
        lock.lock()
        defer { lock.unlock() }
        specsByFormat[spec.format] = spec
        specsById[spec.id.lowercased()] = spec
    }
}
