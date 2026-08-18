// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Disk space and volume pre-flight validation handler.
public final class DiskSpaceHandler: BaseArchiveValidationHandler, @unchecked Sendable {
    private let fileManager: FileManager
    
    public init(fileManager: FileManager = .default, nextHandler: ArchiveValidationHandlerProtocol? = nil) {
        self.fileManager = fileManager
        super.init(nextHandler: nextHandler)
    }
    
    override public func process(context: ArchiveValidationContext) throws -> ArchiveValidationResult {
        let targetDir: String
        if let dest = context.destinationPath, !dest.isEmpty {
            if fileManager.fileExists(atPath: dest) {
                targetDir = dest
            } else {
                targetDir = (dest as NSString).deletingLastPathComponent
            }
        } else if let firstSource = context.sourcePaths.first, fileManager.fileExists(atPath: firstSource) {
            targetDir = (firstSource as NSString).deletingLastPathComponent
        } else {
            targetDir = NSTemporaryDirectory()
        }
        
        let checkedDir = targetDir.isEmpty ? "." : targetDir
        let availableFreeBytes = fetchFreeDiskSpaceBytes(at: checkedDir)
        
        var requiredBytes: UInt64 = 0
        if let estimated = context.estimatedUncompressedSize, estimated > 0 {
            requiredBytes = estimated
        } else if context.operation == .compress {
            var inputBytes: UInt64 = 0
            for path in context.sourcePaths {
                inputBytes += calculatePathSize(at: path)
            }
            requiredBytes = inputBytes
        }
        
        if requiredBytes == 0 {
            requiredBytes = 1024 * 1024
        }
        
        if availableFreeBytes < requiredBytes {
            return .failure(.insufficientDiskSpace(requiredBytes: requiredBytes, availableBytes: availableFreeBytes))
        }
        
        return .success
    }
    
    private func fetchFreeDiskSpaceBytes(at path: String) -> UInt64 {
        let existingDir = findExistingAncestorPath(for: path)
        guard let attrs = try? fileManager.attributesOfFileSystem(forPath: existingDir),
              let freeSizeNum = attrs[.systemFreeSize] as? NSNumber else {
            return UInt64.max
        }
        return freeSizeNum.uint64Value
    }
    
    private func findExistingAncestorPath(for path: String) -> String {
        var currentPath = (path as NSString).standardizingPath
        if currentPath.isEmpty { return "." }
        
        while !currentPath.isEmpty && currentPath != "/" {
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: currentPath, isDirectory: &isDir) {
                return currentPath
            }
            let parent = (currentPath as NSString).deletingLastPathComponent
            if parent == currentPath { break }
            currentPath = parent
        }
        
        if currentPath == "/" && fileManager.fileExists(atPath: "/") {
            return "/"
        }
        if fileManager.fileExists(atPath: ".") {
            return "."
        }
        return NSTemporaryDirectory()
    }
    
    private func calculatePathSize(at path: String) -> UInt64 {
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDir) else { return 0 }
        if isDir.boolValue {
            var total: UInt64 = 0
            if let subpaths = try? fileManager.subpathsOfDirectory(atPath: path) {
                for sub in subpaths {
                    let subPath = (path as NSString).appendingPathComponent(sub)
                    if let subAttrs = try? fileManager.attributesOfItem(atPath: subPath),
                       (subAttrs[.type] as? FileAttributeType) == .typeRegular {
                        total += (subAttrs[.size] as? UInt64) ?? 0
                    }
                }
            }
            return total
        } else {
            guard let attrs = try? fileManager.attributesOfItem(atPath: path) else { return 0 }
            return (attrs[.size] as? UInt64) ?? 0
        }
    }
}
