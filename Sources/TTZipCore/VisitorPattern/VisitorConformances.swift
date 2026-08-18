// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - Visitor Pattern Traversal Helpers

extension ArchiveComponentProtocol {
    /// Dispatches visitor across current component.
    public func dispatchVisitor<V: ArchiveComponentVisitorProtocol>(_ visitor: V) -> V.Result {
        return self.accept(visitor: visitor)
    }
}

extension ArchiveCompositeDirectory {
    /// Recursively dispatches visitor across all child nodes.
    public func acceptChildren<V: ArchiveComponentVisitorProtocol>(visitor: V) -> [V.Result] {
        return getChildren().map { $0.accept(visitor: visitor) }
    }
}
