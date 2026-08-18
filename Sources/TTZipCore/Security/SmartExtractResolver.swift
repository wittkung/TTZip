// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Resolution decision mode for smart extraction.
public enum SmartExtractResolutionMode: String, Sendable, Equatable {
    /// The archive has a single top-level directory or file. Extract directly into destination parent folder without extra wrapping.
    case directExtract
    /// The archive contains multiple loose root files/directories. Wrap all contents inside a folder named after the archive stem.
    case wrapInFolder
    /// The archive has no valid user files.
    case emptyArchive
}

/// Collision handling policy when destination path already exists.
public enum SmartExtractCollisionPolicy: String, Sendable, Equatable {
    case autoRenameNumbered
    case overwriteExisting
    case skipExisting
    case abortWithError
}

/// Result of smart extraction resolution.
public struct SmartExtractResolutionResult: Sendable, Equatable {
    public let resolutionMode: SmartExtractResolutionMode
    public let effectiveRootCount: Int
    public let singleRootName: String?
    public let finalExtractionURL: URL
    
    public init(
        resolutionMode: SmartExtractResolutionMode,
        effectiveRootCount: Int,
        singleRootName: String?,
        finalExtractionURL: URL
    ) {
        self.resolutionMode = resolutionMode
        self.effectiveRootCount = effectiveRootCount
        self.singleRootName = singleRootName
        self.finalExtractionURL = finalExtractionURL
    }
}

/// High-performance smart extraction resolver (analyzes root entries and eliminates folder-in-folder nesting).
public enum SmartExtractResolver: Sendable {
    
    /// Evaluates the archive entry paths and determines the optimal extraction destination folder.
    ///
    /// - Parameters:
    ///   - entryPaths: List of relative entry paths in the archive.
    ///   - destinationParentURL: Target parent directory where extraction is triggered.
    ///   - archiveStemName: File stem of the archive (e.g. "MyProject" for "MyProject.zip").
    ///   - collisionPolicy: Strategy when destination item already exists.
    /// - Returns: Computed `SmartExtractResolutionResult`.
    public static func resolve(
        entryPaths: [String],
        destinationParentURL: URL,
        archiveStemName: String,
        collisionPolicy: SmartExtractCollisionPolicy = .autoRenameNumbered
    ) -> SmartExtractResolutionResult {
        var effectiveRoots = Set<String>()
        
        for rawPath in entryPaths {
            // 1. Skip system metadata & AppleDouble junk
            if ArchiveFilterOptions.isSystemMetadata(path: rawPath) {
                continue
            }
            
            var normalized = rawPath.replacingOccurrences(of: "\\", with: "/")
            while normalized.hasPrefix("./") {
                normalized.removeFirst(2)
            }
            normalized = normalized.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            
            guard !normalized.isEmpty else { continue }
            
            let components = normalized.split(separator: "/")
            if let first = components.first {
                effectiveRoots.insert(String(first))
            }
        }

        
        let rootCount = effectiveRoots.count
        let mode: SmartExtractResolutionMode
        let singleRoot: String?
        var targetURL: URL
        
        if rootCount == 0 {
            mode = .emptyArchive
            singleRoot = nil
            targetURL = destinationParentURL
        } else if rootCount == 1 {
            mode = .directExtract
            singleRoot = effectiveRoots.first
            targetURL = destinationParentURL
        } else {
            mode = .wrapInFolder
            singleRoot = nil
            targetURL = destinationParentURL.appendingPathComponent(archiveStemName, isDirectory: true)
        }
        
        // 2. Handle path collision if required and wrapping in folder
        if mode == .wrapInFolder && collisionPolicy == .autoRenameNumbered {
            targetURL = resolveNumberedCollision(initialURL: targetURL)
        }
        
        return SmartExtractResolutionResult(
            resolutionMode: mode,
            effectiveRootCount: rootCount,
            singleRootName: singleRoot,
            finalExtractionURL: targetURL
        )
    }
    
    /// Generates a non-colliding directory URL (e.g., "Folder 2", "Folder 3").
    private static func resolveNumberedCollision(initialURL: URL) -> URL {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: initialURL.path) else {
            return initialURL
        }
        
        let parentURL = initialURL.deletingLastPathComponent()
        let baseName = initialURL.lastPathComponent
        var counter = 2
        
        while counter < 1000 {
            let candidateURL = parentURL.appendingPathComponent("\(baseName) \(counter)", isDirectory: true)
            if !fileManager.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }
            counter += 1
        }
        
        return parentURL.appendingPathComponent("\(baseName)_\(UUID().uuidString.prefix(6))", isDirectory: true)
    }
}
