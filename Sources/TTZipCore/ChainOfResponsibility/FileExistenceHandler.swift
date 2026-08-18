// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// File existence and accessibility validation handler.
public final class FileExistenceHandler: BaseArchiveValidationHandler, @unchecked Sendable {
    private let fileManager: FileManager
    
    public init(fileManager: FileManager = .default, nextHandler: ArchiveValidationHandlerProtocol? = nil) {
        self.fileManager = fileManager
        super.init(nextHandler: nextHandler)
    }
    
    override public func process(context: ArchiveValidationContext) throws -> ArchiveValidationResult {
        guard !context.sourcePaths.isEmpty else {
            return .failure(.fileNotFound(path: "NO_INPUT_PATHS"))
        }
        
        switch context.operation {
        case .compress:
            for path in context.sourcePaths {
                guard fileManager.fileExists(atPath: path) else {
                    return .failure(.fileNotFound(path: path))
                }
                guard fileManager.isReadableFile(atPath: path) else {
                    return .failure(.fileNotReadable(path: path))
                }
            }
            
        case .extract, .inspect, .repair:
            guard let primaryPath = context.sourcePaths.first else {
                return .failure(.fileNotFound(path: "NO_PRIMARY_ARCHIVE_PATH"))
            }
            guard fileManager.fileExists(atPath: primaryPath) else {
                return .failure(.fileNotFound(path: primaryPath))
            }
            guard fileManager.isReadableFile(atPath: primaryPath) else {
                return .failure(.fileNotReadable(path: primaryPath))
            }
        }
        
        if let dest = context.destinationPath, !dest.isEmpty {
            let parentDir = (dest as NSString).deletingLastPathComponent
            if !parentDir.isEmpty && !fileManager.fileExists(atPath: parentDir) {
                let grandparent = (parentDir as NSString).deletingLastPathComponent
                if !grandparent.isEmpty && fileManager.fileExists(atPath: grandparent) {
                    if !fileManager.isWritableFile(atPath: grandparent) {
                        return .failure(.fileNotReadable(path: dest))
                    }
                }
            }
        }
        
        return .success
    }
}
