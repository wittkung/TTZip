// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Value type representing a filesystem entry scheduled for ZIP compression.
public struct ZipFileItemToCompress: Sendable {
    public let srcPath: String
    public let relPath: String
    public let isDirectory: Bool
    public let fileSize: Int64
    
    public init(srcPath: String, relPath: String, isDirectory: Bool, fileSize: Int64) {
        self.srcPath = srcPath
        self.relPath = relPath
        self.isDirectory = isDirectory
        self.fileSize = fileSize
    }
}

/// Zero-cost directory scanner extracting canonical paths and relative hierarchy for ZIP pipelines.
public enum ZipDirectoryScanner {
    public static func scan(inputPaths: [String], skipMacJunk: Bool = true) -> [ZipFileItemToCompress] {
        var items: [ZipFileItemToCompress] = []
        items.reserveCapacity(256)
        let fm = FileManager.default
        
        for path in inputPaths {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: path, isDirectory: &isDir) else { continue }
            
            let url = URL(fileURLWithPath: path).resolvingSymlinksInPath()
            let canonicalPath = url.path
            let baseName = url.lastPathComponent
            
            if skipMacJunk && isMacJunk(baseName) { continue }
            
            if isDir.boolValue {
                items.append(ZipFileItemToCompress(srcPath: canonicalPath, relPath: baseName, isDirectory: true, fileSize: 0))
                if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey], options: [.skipsHiddenFiles]) {
                    for case let fileURL as URL in enumerator {
                        let resolvedURL = fileURL.resolvingSymlinksInPath()
                        let subPath = resolvedURL.path
                        if skipMacJunk && isMacJunk(subPath) { continue }
                        let resValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                        let subIsDir = resValues?.isDirectory ?? false
                        
                        let rel: String
                        if subPath.hasPrefix(canonicalPath) {
                            var suffix = String(subPath.dropFirst(canonicalPath.count))
                            if suffix.hasPrefix("/") { suffix = String(suffix.dropFirst()) }
                            rel = baseName + "/" + suffix
                        } else if fileURL.path.hasPrefix(path) {
                            var suffix = String(fileURL.path.dropFirst(path.count))
                            if suffix.hasPrefix("/") { suffix = String(suffix.dropFirst()) }
                            rel = baseName + "/" + suffix
                        } else {
                            rel = baseName + "/" + fileURL.lastPathComponent
                        }
                        
                        let sz = Int64(resValues?.fileSize ?? 0)
                        items.append(ZipFileItemToCompress(srcPath: subPath, relPath: rel, isDirectory: subIsDir, fileSize: sz))
                    }
                }
            } else {
                var st = stat()
                let sz = (stat(canonicalPath, &st) == 0) ? Int64(st.st_size) : 0
                items.append(ZipFileItemToCompress(srcPath: canonicalPath, relPath: baseName, isDirectory: false, fileSize: sz))
            }
        }
        return items
    }

    public static func scan(inputPaths: [String], filterOptions: ArchiveFilterOptions) -> [ZipFileItemToCompress] {
        var items: [ZipFileItemToCompress] = []
        items.reserveCapacity(256)
        let fm = FileManager.default
        
        for path in inputPaths {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: path, isDirectory: &isDir) else { continue }
            
            let url = URL(fileURLWithPath: path).resolvingSymlinksInPath()
            let canonicalPath = url.path
            let baseName = url.lastPathComponent
            
            if PathPatternFilterEngine.shouldExclude(
                path: baseName,
                excludePatterns: filterOptions.excludePatterns,
                includePatterns: filterOptions.includePatterns,
                excludeVCS: filterOptions.excludeVCS,
                noMacMetadata: filterOptions.noMacMetadata
            ) {
                continue
            }
            
            if isDir.boolValue {
                items.append(ZipFileItemToCompress(srcPath: canonicalPath, relPath: baseName, isDirectory: true, fileSize: 0))
                if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey], options: [.skipsHiddenFiles]) {
                    for case let fileURL as URL in enumerator {
                        let resolvedURL = fileURL.resolvingSymlinksInPath()
                        let subPath = resolvedURL.path
                        
                        let rel: String
                        if subPath.hasPrefix(canonicalPath) {
                            var suffix = String(subPath.dropFirst(canonicalPath.count))
                            if suffix.hasPrefix("/") { suffix = String(suffix.dropFirst()) }
                            rel = baseName + "/" + suffix
                        } else if fileURL.path.hasPrefix(path) {
                            var suffix = String(fileURL.path.dropFirst(path.count))
                            if suffix.hasPrefix("/") { suffix = String(suffix.dropFirst()) }
                            rel = baseName + "/" + suffix
                        } else {
                            rel = baseName + "/" + fileURL.lastPathComponent
                        }
                        
                        if PathPatternFilterEngine.shouldExclude(
                            path: rel,
                            excludePatterns: filterOptions.excludePatterns,
                            includePatterns: filterOptions.includePatterns,
                            excludeVCS: filterOptions.excludeVCS,
                            noMacMetadata: filterOptions.noMacMetadata
                        ) {
                            continue
                        }
                        
                        let resValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                        let subIsDir = resValues?.isDirectory ?? false
                        let sz = Int64(resValues?.fileSize ?? 0)
                        items.append(ZipFileItemToCompress(srcPath: subPath, relPath: rel, isDirectory: subIsDir, fileSize: sz))
                    }
                }
            } else {
                var st = stat()
                let sz = (stat(canonicalPath, &st) == 0) ? Int64(st.st_size) : 0
                items.append(ZipFileItemToCompress(srcPath: canonicalPath, relPath: baseName, isDirectory: false, fileSize: sz))
            }
        }
        return items
    }

    public static func scanComponent(_ component: ArchiveComponentProtocol, baseRelPath: String, skipMacJunk: Bool = true) -> [ZipFileItemToCompress] {
        if skipMacJunk && isMacJunk(component.name) { return [] }
        
        let visitor = ArchiveComponentVisitor<[ZipFileItemToCompress]>(
            visitLeaf: { leaf in
                return [ZipFileItemToCompress(srcPath: leaf.path, relPath: baseRelPath, isDirectory: false, fileSize: leaf.sizeBytes)]
            },
            visitComposite: { composite in
                var results = [ZipFileItemToCompress(srcPath: composite.path, relPath: baseRelPath, isDirectory: true, fileSize: 0)]
                for child in composite.getChildren() {
                    let childRelPath = baseRelPath + "/" + child.name
                    results.append(contentsOf: scanComponent(child, baseRelPath: childRelPath, skipMacJunk: skipMacJunk))
                }
                return results
            }
        )
        return component.accept(visitor: visitor)
    }
    
    public static func isMacJunk(_ path: String) -> Bool {
        let last = (path as NSString).lastPathComponent
        return last == ".DS_Store" || last.hasPrefix("._") || last == "__MACOSX" || last == ".Trashes"
    }
}
