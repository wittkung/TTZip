// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Folder and archive component metrics calculator (Composite & Visitor Pattern integration).
public final class FolderStatsCalculator: @unchecked Sendable {
    
    /// Computes recursive metrics for an `ArchiveComponentProtocol` node.
    public static func calculateStats(for component: ArchiveComponentProtocol) -> (size: Int64, subfolders: Int, files: Int, dist: [(category: String, count: Int)]) {
        let visitor = FolderStatsVisitor()
        let res = component.accept(visitor: visitor)
        return (size: res.totalSizeBytes, subfolders: res.totalDirectories, files: res.totalFiles, dist: res.categoryDistribution)
    }
    
    /// Computes recursive metrics for a physical filesystem directory path.
    public static func calculateStats(for targetPath: String) async -> (size: Int64, subfolders: Int, files: Int, dist: [(category: String, count: Int)]) {
        return await Task.detached(priority: .userInitiated) { () -> (size: Int64, subfolders: Int, files: Int, dist: [(category: String, count: Int)]) in
            guard FileManager.default.fileExists(atPath: targetPath) else {
                return (0, 0, 0, [])
            }
            let rootComponent = ArchiveComponentTreeBuilder.buildTree(fromDiskPath: targetPath)
            return calculateStats(for: rootComponent)
        }.value
    }
}
