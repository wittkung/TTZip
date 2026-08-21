// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - Validation & Volume Pattern Helpers

extension CompressCommand {
    internal func isSplitVolumeMatch(fileName: String, baseName: String, baseStem: String) -> Bool {
        if fileName.hasPrefix(baseName + ".") { return true }
        if fileName.hasPrefix(baseStem + ".") {
            let ext = (fileName as NSString).pathExtension.lowercased()
            if ext.hasPrefix("z") && ext.dropFirst().allSatisfy({ $0.isNumber }) { return true }
            if ext.allSatisfy({ $0.isNumber }) && !ext.isEmpty { return true }
            if ext.hasPrefix("part") { return true }
        }
        return false
    }
    
    internal func scanDirectorySet(dirPath: String) -> Set<String> {
        let fm = FileManager.default
        guard fm.fileExists(atPath: dirPath) else { return [] }
        var result = Set<String>()
        if let enumerator = fm.enumerator(atPath: dirPath) {
            while let relativePath = enumerator.nextObject() as? String {
                let fullPath = (dirPath as NSString).appendingPathComponent(relativePath)
                result.insert(fullPath)
            }
        }
        return result
    }
}
