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
