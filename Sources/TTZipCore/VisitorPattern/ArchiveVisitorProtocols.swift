// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - Visitor Pattern Core Protocols

/// Core visitor protocol for operating across `ArchiveComponentProtocol` composite trees (GoF Visitor Pattern).
/// Encapsulates operations executed across tree nodes without mutating underlying component representations.
public protocol ArchiveComponentVisitorProtocol<Result> {
    associatedtype Result
    
    /// Visits leaf file node.
    func visit(leaf: ArchiveLeafFile) -> Result
    
    /// Visits composite directory node.
    func visit(directory: ArchiveCompositeDirectory) -> Result
}

// MARK: - Closure-based Visitor

public struct ArchiveComponentVisitor<Result>: Sendable {
    public let visitLeafBlock: @Sendable (ArchiveLeafFile) -> Result
    public let visitCompositeBlock: @Sendable (ArchiveCompositeDirectory) -> Result
    
    public init(
        visitLeaf: @escaping @Sendable (ArchiveLeafFile) -> Result,
        visitComposite: @escaping @Sendable (ArchiveCompositeDirectory) -> Result
    ) {
        self.visitLeafBlock = visitLeaf
        self.visitCompositeBlock = visitComposite
    }
}

// MARK: - Default Implementations

extension ArchiveComponentVisitorProtocol {
    public func visit(composite: ArchiveCompositeDirectory) -> Result {
        return visit(directory: composite)
    }
}

// MARK: - Double Dispatch Protocol Extensions

extension ArchiveComponentProtocol {
    /// Strongly-typed double dispatch entrypoint for visitors.
    public func accept<V: ArchiveComponentVisitorProtocol>(visitor: V) -> V.Result {
        if let leaf = self as? ArchiveLeafFile {
            return visitor.visit(leaf: leaf)
        } else if let directory = self as? ArchiveCompositeDirectory {
            return visitor.visit(directory: directory)
        } else {
            fatalError("Unsupported ArchiveComponentProtocol type: \(type(of: self))")
        }
    }
}
