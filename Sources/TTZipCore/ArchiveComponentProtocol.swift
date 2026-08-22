// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - Composite Pattern Component Protocol

/// Composite Pattern Core Interface: Unifies leaf files and composite directory containers.
public protocol ArchiveComponentProtocol: Sendable {
    /// Item name (e.g. "document.txt" or "Photos").
    var name: String { get }
    
    /// Item relative or absolute filesystem path.
    var path: String { get }
    
    /// Whether this component represents a directory container.
    var isDirectory: Bool { get }
    
    /// Total aggregate uncompressed byte size of component and all nested children.
    var sizeBytes: Int64 { get }
    
    /// Obtains direct child components (empty array for leaf files).
    func getChildren() -> [ArchiveComponentProtocol]
}

// MARK: - Leaf Node: Single File

/// Represents a single file entry in the composite tree structure.
public final class ArchiveLeafFile: ArchiveComponentProtocol, Identifiable, Equatable, @unchecked Sendable {
    public var id: String { path }
    public let name: String
    public let path: String
    public let sizeBytes: Int64
    public let isDirectory: Bool = false
    public let entry: ArchiveEntry?
    public let modificationDate: Date?
    public let compressedSizeBytes: Int64?
    public let crc32: UInt32?
    
    public init(
        name: String,
        path: String,
        sizeBytes: Int64,
        entry: ArchiveEntry? = nil,
        modificationDate: Date? = nil,
        compressedSizeBytes: Int64? = nil,
        crc32: UInt32? = nil
    ) {
        let factory = ArchiveEntryFlyweightFactory.shared
        self.name = factory.internPath(name)
        self.path = factory.internPath(path)
        self.sizeBytes = sizeBytes
        self.entry = entry
        self.modificationDate = modificationDate
        self.compressedSizeBytes = compressedSizeBytes
        self.crc32 = crc32
    }
    
    public func getChildren() -> [ArchiveComponentProtocol] {
        return []
    }
    
    public static func == (lhs: ArchiveLeafFile, rhs: ArchiveLeafFile) -> Bool {
        return lhs.path == rhs.path && lhs.sizeBytes == rhs.sizeBytes
    }
}

// MARK: - Composite Container Node: Directory

/// Represents a directory container holding child files and subdirectories.
public final class ArchiveCompositeDirectory: ArchiveComponentProtocol, Identifiable, Equatable, @unchecked Sendable {
    public var id: String { path }
    public let name: String
    public let path: String
    public let isDirectory: Bool = true
    public let entry: ArchiveEntry?
    public let modificationDate: Date?
    
    private var childrenMap: [String: ArchiveComponentProtocol] = [:]
    private let lock = NSLock()
    
    public init(
        name: String,
        path: String,
        entry: ArchiveEntry? = nil,
        modificationDate: Date? = nil,
        children: [ArchiveComponentProtocol] = []
    ) {
        let factory = ArchiveEntryFlyweightFactory.shared
        self.name = factory.internPath(name)
        self.path = factory.internPath(path)
        self.entry = entry
        self.modificationDate = modificationDate
        for child in children {
            self.childrenMap[child.name] = child
        }
    }
    
    /// Aggregate byte size computed recursively across all children.
    public var sizeBytes: Int64 {
        lock.lock()
        defer { lock.unlock() }
        return childrenMap.values.reduce(0) { $0 + $1.sizeBytes }
    }
    
    /// Obtains unsorted child items in O(1) time (bypasses locale sorting for sampling).
    public func getChildrenUnsorted() -> [ArchiveComponentProtocol] {
        lock.lock()
        defer { lock.unlock() }
        return Array(childrenMap.values)
    }
    
    /// Obtains child items sorted with directories first and alphabetical name order.
    public func getChildren() -> [ArchiveComponentProtocol] {
        lock.lock()
        let items = Array(childrenMap.values)
        lock.unlock()
        
        return items.sorted { a, b in
            if a.isDirectory != b.isDirectory {
                return a.isDirectory && !b.isDirectory
            }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }
    
    /// Internal direct child insertion without locking (used during single-threaded initialization).
    internal func addDirect(component: ArchiveComponentProtocol) {
        childrenMap[component.name] = component
    }

    /// Internal direct child lookup without locking (used during single-threaded initialization).
    internal func findChildDirect(named name: String) -> ArchiveComponentProtocol? {
        return childrenMap[name]
    }

    /// Thread-safely adds a child component.
    public func add(component: ArchiveComponentProtocol) {
        lock.lock()
        defer { lock.unlock() }
        childrenMap[component.name] = component
    }
    
    /// Thread-safely removes a child component by name.
    public func remove(componentNamed name: String) {
        lock.lock()
        defer { lock.unlock() }
        childrenMap.removeValue(forKey: name)
    }
    
    /// Thread-safely clears all child components.
    public func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        childrenMap.removeAll()
    }
    
    /// Thread-safely finds a direct child component by name.
    public func findChild(named name: String) -> ArchiveComponentProtocol? {
        lock.lock()
        defer { lock.unlock() }
        return childrenMap[name]
    }
    
    public static func == (lhs: ArchiveCompositeDirectory, rhs: ArchiveCompositeDirectory) -> Bool {
        return lhs.path == rhs.path && lhs.getChildren().count == rhs.getChildren().count
    }
}
