import Foundation
import SwiftUI
import AppKit

/// 全局文件剪贴板调度器 (支持 ⌘C 复制 / ⌘X 剪切 / ⌘V 粘贴，自动文件名碰撞避让)
@MainActor
public final class FileClipboardStore: ObservableObject {
    public static let shared = FileClipboardStore()
    
    @Published public var copiedURLs: [URL] = []
    @Published public var isCutOperation: Bool = false
    
    private init() {}
    
    public var canPaste: Bool {
        if !copiedURLs.isEmpty { return true }
        if let items = NSPasteboard.general.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !items.isEmpty {
            return true
        }
        return false
    }
    
    public func copy(urls: [URL]) {
        self.copiedURLs = urls
        self.isCutOperation = false
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects(urls as [NSURL])
    }
    
    public func cut(urls: [URL]) {
        self.copiedURLs = urls
        self.isCutOperation = true
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects(urls as [NSURL])
    }
    
    public func paste(to targetDir: URL) {
        let urlsToPaste: [URL] = {
            if !copiedURLs.isEmpty { return copiedURLs }
            return (NSPasteboard.general.readObjects(forClasses: [NSURL.self], options: nil) as? [URL]) ?? []
        }()
        
        guard !urlsToPaste.isEmpty else { return }
        let isCut = self.isCutOperation
        
        if isCut {
            copiedURLs = []
            isCutOperation = false
        }
        
        for srcURL in urlsToPaste {
            if srcURL.path == targetDir.path || targetDir.path.hasPrefix(srcURL.path + "/") {
                continue
            }
            let destURL = Self.uniqueDestinationURLStatic(for: srcURL, in: targetDir)
            if isCut {
                try? FileManager.default.moveItem(at: srcURL, to: destURL)
            } else {
                try? FileManager.default.copyItem(at: srcURL, to: destURL)
            }
        }
        NotificationCenter.default.post(name: NSNotification.Name("TTZipArchiveUnlockedRefresh"), object: nil)
    }
    
    nonisolated private static func uniqueDestinationURLStatic(for srcURL: URL, in targetDir: URL) -> URL {
        let fm = FileManager.default
        let ext = srcURL.pathExtension
        let baseName = srcURL.deletingPathExtension().lastPathComponent
        
        var candidateName = srcURL.lastPathComponent
        var candidateURL = targetDir.appendingPathComponent(candidateName)
        var counter = 1
        
        while fm.fileExists(atPath: candidateURL.path) {
            if ext.isEmpty {
                candidateName = "\(baseName) \(counter)"
            } else {
                candidateName = "\(baseName) \(counter).\(ext)"
            }
            candidateURL = targetDir.appendingPathComponent(candidateName)
            counter += 1
        }
        return candidateURL
    }
    
    private func uniqueDestinationURL(for srcURL: URL, in targetDir: URL) -> URL {
        let fm = FileManager.default
        let ext = srcURL.pathExtension
        let baseName = srcURL.deletingPathExtension().lastPathComponent
        
        var candidateName = srcURL.lastPathComponent
        var candidateURL = targetDir.appendingPathComponent(candidateName)
        var counter = 1
        
        while fm.fileExists(atPath: candidateURL.path) {
            if ext.isEmpty {
                candidateName = "\(baseName) (\(counter))"
            } else {
                candidateName = "\(baseName) (\(counter)).\(ext)"
            }
            candidateURL = targetDir.appendingPathComponent(candidateName)
            counter += 1
        }
        return candidateURL
    }
}
