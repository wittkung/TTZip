// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import TTZipCore

public struct CompressFileItem: Identifiable, Hashable {
    public let id = UUID()
    public let path: String
    
    /// Cached component node (Leaf or Composite Directory) built at init to eliminate disk I/O during UI rendering.
    public let component: ArchiveComponentProtocol
    
    public init(path: String) {
        self.path = path
        self.component = ArchiveComponentTreeBuilder.buildTree(fromDiskPath: path)
    }
    
    public var name: String { (path as NSString).lastPathComponent }
    
    /// Reads directory flag from cached component.
    public var isDirectory: Bool {
        return component.isDirectory
    }
    
    /// Calculates aggregate byte size transparently via composite pattern.
    public var size: Int64 {
        return component.sizeBytes
    }
    
    // MARK: - Equatable & Hashable
    
    public static func == (lhs: CompressFileItem, rhs: CompressFileItem) -> Bool {
        return lhs.id == rhs.id && lhs.path == rhs.path
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(path)
    }
}
