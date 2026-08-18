// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import AppKit

public enum FileDragDropHelper {
    public static func performMove(sources: [URL], to destinationDir: URL) {
        let fm = FileManager.default
        for src in sources {
            let dest = destinationDir.appendingPathComponent(src.lastPathComponent)
            if src.path == dest.path { continue }
            
            var finalDest = dest
            var counter = 2
            while fm.fileExists(atPath: finalDest.path) {
                let nameWithoutExt = (src.lastPathComponent as NSString).deletingPathExtension
                let ext = src.pathExtension
                let newName = ext.isEmpty ? "\(nameWithoutExt) \(counter)" : "\(nameWithoutExt) \(counter).\(ext)"
                finalDest = destinationDir.appendingPathComponent(newName)
                counter += 1
            }
            
            try? fm.moveItem(at: src, to: finalDest)
        }
    }
}
