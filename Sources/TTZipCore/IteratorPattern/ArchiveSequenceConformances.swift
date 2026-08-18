// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - ArchiveCompositeDirectory Sequence Conformance

extension ArchiveCompositeDirectory: Sequence {
    public typealias Element = ArchiveEntry
    
    public func makeIterator() -> DepthFirstTreeIterator {
        return DepthFirstTreeIterator(root: self, order: .preOrder)
    }
    
    public func makeDepthFirstIterator(order: DFSTraversalOrder = .preOrder) -> DepthFirstTreeIterator {
        return DepthFirstTreeIterator(root: self, order: order)
    }
    
    public func makeBreadthFirstIterator() -> BreadthFirstTreeIterator {
        return BreadthFirstTreeIterator(root: self)
    }
}

// MARK: - ArchiveTreeNode Sequence Conformance

extension ArchiveTreeNode: Sequence {
    public typealias Element = ArchiveEntry
    
    public func makeIterator() -> DepthFirstTreeIterator {
        return DepthFirstTreeIterator(root: self.toComponent(), order: .preOrder)
    }
    
    public func makeDepthFirstIterator(order: DFSTraversalOrder = .preOrder) -> DepthFirstTreeIterator {
        return DepthFirstTreeIterator(root: self.toComponent(), order: order)
    }
    
    public func makeBreadthFirstIterator() -> BreadthFirstTreeIterator {
        return BreadthFirstTreeIterator(root: self.toComponent())
    }
}

// MARK: - ArchiveInspectionResult Sequence Conformance

extension ArchiveInspectionResult: Sequence {
    public typealias Element = ArchiveEntry
    
    public func makeIterator() -> ArrayArchiveIterator {
        return ArrayArchiveIterator(entries: entries)
    }
    
    public func makeFilteredIterator(
        extensions: Set<String>? = nil,
        minSize: Int64? = nil,
        maxSize: Int64? = nil,
        namePattern: String? = nil,
        regexPattern: String? = nil,
        sortBy: ArchiveSortKey? = nil,
        sortOrder: ArchiveSortOrder = .ascending
    ) -> ArrayArchiveIterator {
        return ArrayArchiveIterator(
            entries: entries,
            extensions: extensions,
            minSize: minSize,
            maxSize: maxSize,
            namePattern: namePattern,
            regexPattern: regexPattern,
            sortBy: sortBy,
            sortOrder: sortOrder
        )
    }
}

// MARK: - ArchiveReader Sequence Extension

extension ArchiveReader {
    public func makeIterator(
        for archivePath: String,
        password: String? = nil
    ) async throws -> ArrayArchiveIterator {
        let entries = try await inspect(archivePath: archivePath, password: password)
        return ArrayArchiveIterator(entries: entries)
    }
}

// MARK: - ArchiveBatchFacade Sequence Extension

extension ArchiveBatchFacade {
    public func makeIterator(for entries: [ArchiveEntry]) -> ArrayArchiveIterator {
        return ArrayArchiveIterator(entries: entries)
    }
}
