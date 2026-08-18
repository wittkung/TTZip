// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - Archive Iterator Protocol

/// Core abstraction protocol for archive iterators (Iterator Pattern).
///
/// Fully conforms to Swift native `IteratorProtocol` and `Sequence` with peek, reset, and skip capabilities.
public protocol ArchiveIteratorProtocol: IteratorProtocol, Sequence where Element == ArchiveEntry {
    /// Extracts next archive entry.
    mutating func next() -> ArchiveEntry?
    
    /// Peeks at next archive entry without advancing the internal cursor.
    func peek() -> ArchiveEntry?
    
    /// Resets cursor to initial state.
    mutating func reset()
    
    /// Total count of elements managed by the iterator.
    var count: Int { get }
    
    /// Whether iterator has reached the end.
    var isAtEnd: Bool { get }
    
    /// Advances cursor by specified step count, returning actual skipped count.
    @discardableResult
    mutating func skip(count: Int) -> Int
}

// MARK: - Swift Sequence Conformance

extension ArchiveIteratorProtocol {
    public func makeIterator() -> Self {
        return self
    }
    
    public var isAtEnd: Bool {
        return peek() == nil
    }
    
    @discardableResult
    public mutating func skip(count step: Int) -> Int {
        guard step > 0 else { return 0 }
        var skipped = 0
        while skipped < step, next() != nil {
            skipped += 1
        }
        return skipped
    }
}

// MARK: - ArchiveComponentProtocol Conversion

extension ArchiveComponentProtocol {
    /// Safely converts composite component node to standard `ArchiveEntry`.
    public var asArchiveEntry: ArchiveEntry {
        if let leaf = self as? ArchiveLeafFile, let entry = leaf.entry {
            return entry
        } else if let composite = self as? ArchiveCompositeDirectory, let entry = composite.entry {
            return entry
        } else {
            return ArchiveEntry(
                path: path,
                uncompressedSize: sizeBytes,
                isDirectory: isDirectory,
                modificationDate: (self as? ArchiveLeafFile)?.modificationDate ?? (self as? ArchiveCompositeDirectory)?.modificationDate
            )
        }
    }
}
