// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - Folder Stats Models

public struct FolderStatsResult: Sendable, Equatable {
    public let totalFiles: Int
    public let totalDirectories: Int
    public let totalSizeBytes: Int64
    public let maxDepth: Int
    public let categoryDistribution: [(category: String, count: Int)]
    
    public init(
        totalFiles: Int,
        totalDirectories: Int,
        totalSizeBytes: Int64,
        maxDepth: Int,
        categoryDistribution: [(category: String, count: Int)] = []
    ) {
        self.totalFiles = totalFiles
        self.totalDirectories = totalDirectories
        self.totalSizeBytes = totalSizeBytes
        self.maxDepth = maxDepth
        self.categoryDistribution = categoryDistribution
    }
    
    public static func == (lhs: FolderStatsResult, rhs: FolderStatsResult) -> Bool {
        return lhs.totalFiles == rhs.totalFiles &&
               lhs.totalDirectories == rhs.totalDirectories &&
               lhs.totalSizeBytes == rhs.totalSizeBytes &&
               lhs.maxDepth == rhs.maxDepth
    }
}

// MARK: - FolderStatsVisitor

/// Recursively aggregates metrics across composite trees (totalFiles, totalDirectories, totalSizeBytes, maxDepth).
public final class FolderStatsVisitor: ArchiveComponentVisitorProtocol, @unchecked Sendable {
    public typealias Result = FolderStatsResult
    
    public init() {}
    
    public func visit(leaf: ArchiveLeafFile) -> FolderStatsResult {
        let cat = categorize(filename: leaf.name)
        return FolderStatsResult(
            totalFiles: 1,
            totalDirectories: 0,
            totalSizeBytes: leaf.sizeBytes,
            maxDepth: 1,
            categoryDistribution: [(category: cat, count: 1)]
        )
    }
    
    public func visit(directory: ArchiveCompositeDirectory) -> FolderStatsResult {
        var files = 0
        var subfolders = 0
        var totalSize: Int64 = 0
        var maxChildDepth = 0
        var catMap: [String: Int] = [:]
        
        for child in directory.getChildren() {
            if child.isDirectory {
                subfolders += 1
            }
            let childStats = child.accept(visitor: self)
            files += childStats.totalFiles
            subfolders += childStats.totalDirectories
            totalSize += childStats.totalSizeBytes
            maxChildDepth = max(maxChildDepth, childStats.maxDepth)
            
            for (cat, count) in childStats.categoryDistribution {
                catMap[cat, default: 0] += count
            }
        }
        
        let sortedDist = catMap.map { (category: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
        
        return FolderStatsResult(
            totalFiles: files,
            totalDirectories: subfolders,
            totalSizeBytes: totalSize,
            maxDepth: 1 + maxChildDepth,
            categoryDistribution: sortedDist
        )
    }
    
    private func categorize(filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        if ["mp4", "mov", "webm", "mkv", "avi", "flv", "m4v", "ts", "3gp"].contains(ext) {
            return "Video"
        } else if ["mp3", "wav", "flac", "m4a", "aac", "ogg", "opus", "aiff"].contains(ext) {
            return "Audio"
        } else if ["png", "jpg", "jpeg", "webp", "gif", "svg", "heic"].contains(ext) {
            return "Image"
        } else if ["srt", "ass", "txt", "swift", "json", "md", "py", "c", "cpp", "vtt", "pdf"].contains(ext) {
            return "Document/Code"
        } else if ["zip", "7z", "rar", "tar", "gz", "zst", "bz2"].contains(ext) {
            return "Archive"
        } else {
            return "Other"
        }
    }
}
