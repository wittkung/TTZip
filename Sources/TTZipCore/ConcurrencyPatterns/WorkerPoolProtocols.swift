// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Priority tiers for concurrent worker tasks.
public enum TaskPriorityLevel: Int, Comparable, Sendable, CaseIterable, Hashable, Codable {
    case background = 1
    case utility = 2
    case userInitiated = 3
    case critical = 4

    public static func < (lhs: TaskPriorityLevel, rhs: TaskPriorityLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

/// Interface protocol for executable concurrent work items.
public protocol ArchiveWorkItemProtocol: Sendable {
    /// Unique work item identifier.
    var itemID: String { get }
    
    /// Priority classification.
    var priority: TaskPriorityLevel { get }
    
    /// Executes the unit of work.
    func execute() async throws -> any Sendable
}

/// Standard concrete implementation of `ArchiveWorkItemProtocol`.
public struct ArchiveWorkItem: ArchiveWorkItemProtocol {
    public let itemID: String
    public let priority: TaskPriorityLevel
    private let taskBlock: @Sendable () async throws -> any Sendable

    public init(
        itemID: String = UUID().uuidString,
        priority: TaskPriorityLevel = .userInitiated,
        block: @escaping @Sendable () async throws -> any Sendable
    ) {
        self.itemID = itemID
        self.priority = priority
        self.taskBlock = block
    }

    public func execute() async throws -> any Sendable {
        return try await taskBlock()
    }
}

/// Lifecycle states for worker pools and schedulers.
public enum WorkerPoolState: String, Sendable, Equatable, Hashable, Codable {
    case idle
    case running
    case paused
    case draining
    case shutdown
}
