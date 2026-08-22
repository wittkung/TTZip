// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import AppKit
import TTZipCore

extension NativeArchiveOutlineView.Coordinator {
    public func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return parent.nodes.count
        }
        if let node = item as? ArchiveTreeNode {
            return node.children?.count ?? 0
        }
        return 0
    }
    
    public func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            return parent.nodes[index]
        }
        if let node = item as? ArchiveTreeNode, let children = node.children {
            return children[index]
        }
        fatalError("Invalid item index")
    }
    
    public func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let node = item as? ArchiveTreeNode {
            return node.isDirectory
        }
        return false
    }
    
    public func outlineViewItemWillExpand(_ notification: Notification) {
        NSAnimationContext.current.duration = 0.0
    }
    
    public func outlineViewItemWillCollapse(_ notification: Notification) {
        NSAnimationContext.current.duration = 0.18
    }
    
    public func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? ArchiveTreeNode else { return nil }
        let identifier = tableColumn?.identifier.rawValue ?? ""
        
        if identifier == "name" {
            let cellIdentifier = NSUserInterfaceItemIdentifier("ArchiveNodeCell")
            let cell = outlineView.makeView(withIdentifier: cellIdentifier, owner: nil) as? ArchiveNodeTableCellView
                ?? ArchiveNodeTableCellView(frame: .zero)
            cell.identifier = cellIdentifier
            
            let iconName = fileIconName(isDirectory: node.isDirectory, name: node.name)
            cell.configure(name: node.name, isDirectory: node.isDirectory, iconName: iconName)
            
            return cell
        } else if identifier == "size" {
            let tf = NSTextField(labelWithString: node.isDirectory ? "--" : formatBytes(node.uncompressedSize))
            tf.font = .systemFont(ofSize: 12)
            tf.textColor = .secondaryLabelColor
            tf.alignment = .right
            return tf
        } else if identifier == "encoding" {
            let tf = NSTextField(labelWithString: node.detectedEncoding)
            tf.font = .systemFont(ofSize: 11, weight: .medium)
            tf.textColor = .systemBlue
            tf.alignment = .center
            return tf
        }
        
        return nil
    }
    
    public func outlineViewSelectionDidChange(_ notification: Notification) {
        guard let outlineView = notification.object as? NSOutlineView else { return }
        let selectedRow = outlineView.selectedRow
        guard selectedRow >= 0, let node = outlineView.item(atRow: selectedRow) as? ArchiveTreeNode else { return }
        DispatchQueue.main.async {
            self.parent.selectedPath = node.id
            self.parent.onSelectFile(node)
        }
    }
    
    func fileIconName(isDirectory: Bool, name: String) -> String {
        if isDirectory { return "folder.fill" }
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "png", "jpg", "jpeg", "gif", "webp", "heic", "svg", "bmp": return "photo.fill"
        case "mp4", "mov", "m4v", "avi", "mkv": return "film.fill"
        case "mp3", "wav", "m4a", "aac", "flac": return "music.note"
        case "pdf": return "doc.richtext.fill"
        case "swift", "json", "c", "cpp", "h", "md", "py", "sh", "xml", "html", "css": return "doc.text.fill"
        default: return "doc.fill"
        }
    }
    
    func formatBytes(_ bytes: Int64) -> String {
        return ByteCountFormatterCache.string(fromByteCount: bytes)
    }
}
