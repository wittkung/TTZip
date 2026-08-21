// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

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
        
        for path in inputPaths {
            guard FileManager.default.fileExists(atPath: path) else { continue }
            
            var config = TTZipScanConfigRaw(
                include_hidden: false,
                skip_mac_junk: skipMacJunk,
                max_depth: 0,
                thread_budget: 0
            )
            
            var pathItems: [ZipFileItemToCompress] = []
            let callback: @convention(c) (UnsafePointer<TTZipScannedItemRaw>?, UnsafeMutableRawPointer?) -> Bool = { rawItemPtr, userData in
                guard let raw = rawItemPtr?.pointee, let userData = userData else { return true }
                let collector = userData.assumingMemoryBound(to: [ZipFileItemToCompress].self)
                let src = raw.src_path != nil ? String(cString: raw.src_path) : ""
                let rel = raw.rel_path != nil ? String(cString: raw.rel_path) : ""
                collector.pointee.append(ZipFileItemToCompress(
                    srcPath: src,
                    relPath: rel,
                    isDirectory: raw.is_directory,
                    fileSize: Int64(raw.file_size)
                ))
                return true
            }
            
            withUnsafeMutablePointer(to: &pathItems) { ptr in
                _ = ttzip_rust_scan_directory_parallel(path, &config, callback, ptr)
            }
            items.append(contentsOf: pathItems)
        }
        return items
    }

    public static func scan(inputPaths: [String], filterOptions: ArchiveFilterOptions) -> [ZipFileItemToCompress] {
        var items: [ZipFileItemToCompress] = []
        items.reserveCapacity(256)
        
        for path in inputPaths {
            guard FileManager.default.fileExists(atPath: path) else { continue }
            
            let url = URL(fileURLWithPath: path).resolvingSymlinksInPath()
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
            
            var config = TTZipScanConfigRaw(
                include_hidden: !filterOptions.noMacMetadata,
                skip_mac_junk: filterOptions.noMacMetadata,
                max_depth: 0,
                thread_budget: 0
            )
            
            var pathItems: [ZipFileItemToCompress] = []
            let callback: @convention(c) (UnsafePointer<TTZipScannedItemRaw>?, UnsafeMutableRawPointer?) -> Bool = { rawItemPtr, userData in
                guard let raw = rawItemPtr?.pointee, let userData = userData else { return true }
                let collector = userData.assumingMemoryBound(to: [ZipFileItemToCompress].self)
                let src = raw.src_path != nil ? String(cString: raw.src_path) : ""
                let rel = raw.rel_path != nil ? String(cString: raw.rel_path) : ""
                collector.pointee.append(ZipFileItemToCompress(
                    srcPath: src,
                    relPath: rel,
                    isDirectory: raw.is_directory,
                    fileSize: Int64(raw.file_size)
                ))
                return true
            }
            
            withUnsafeMutablePointer(to: &pathItems) { ptr in
                _ = ttzip_rust_scan_directory_parallel(path, &config, callback, ptr)
            }
            
            for item in pathItems {
                if PathPatternFilterEngine.shouldExclude(
                    path: item.relPath,
                    excludePatterns: filterOptions.excludePatterns,
                    includePatterns: filterOptions.includePatterns,
                    excludeVCS: filterOptions.excludeVCS,
                    noMacMetadata: filterOptions.noMacMetadata
                ) {
                    continue
                }
                items.append(item)
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
