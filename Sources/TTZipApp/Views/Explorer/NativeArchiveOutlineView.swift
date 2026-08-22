// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import AppKit
import TTZipCore

extension Notification.Name {
    public static let archiveExplorerMoveUp = Notification.Name("archiveExplorerMoveUp")
    public static let archiveExplorerMoveDown = Notification.Name("archiveExplorerMoveDown")
    public static let archiveExplorerMoveLeft = Notification.Name("archiveExplorerMoveLeft")
    public static let archiveExplorerMoveRight = Notification.Name("archiveExplorerMoveRight")
}

/// Custom table cell view optimized for NSOutlineView.
public final class ArchiveNodeTableCellView: NSTableCellView {
    public let iconView = NSImageView()
    public let nameLabel = NSTextField(labelWithString: "")
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    private func setupViews() {
        iconView.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .systemFont(ofSize: 13)
        nameLabel.lineBreakMode = .byTruncatingMiddle
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let stack = NSStackView(views: [iconView, nameLabel])
        stack.orientation = .horizontal
        stack.spacing = 6
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(stack)
        self.imageView = iconView
        self.textField = nameLabel
        
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    
    public func configure(name: String, isDirectory: Bool, iconName: String) {
        let image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
        iconView.image = image
        iconView.contentTintColor = isDirectory ? NSColor(red: 0.17, green: 0.48, blue: 0.29, alpha: 1.0) : .labelColor
        nameLabel.stringValue = name
    }
}

/// Native macOS NSOutlineView representable matching Finder list view hierarchy.
public struct NativeArchiveOutlineView: NSViewRepresentable {
    let nodes: [ArchiveTreeNode]
    @Binding var selectedPath: String?
    let onSelectFile: (ArchiveTreeNode) -> Void
    
    public init(
        nodes: [ArchiveTreeNode],
        selectedPath: Binding<String?>,
        onSelectFile: @escaping (ArchiveTreeNode) -> Void
    ) {
        self.nodes = nodes
        self._selectedPath = selectedPath
        self.onSelectFile = onSelectFile
    }
    
    public func traverseAllNodesDFS() -> [ArchiveEntry] {
        var results: [ArchiveEntry] = []
        func collect(node: ArchiveTreeNode) {
            if let entry = node.entry {
                results.append(entry)
            }
            if let children = node.children {
                for child in children {
                    collect(node: child)
                }
            }
        }
        for node in nodes {
            collect(node: node)
        }
        return results
    }
    
    public func renderTreePreview(includeSize: Bool = false) -> String {
        let rootComposite = ArchiveCompositeDirectory(name: "Archive", path: "", children: nodes.map { $0.toComponent() })
        let visitor = TreeRendererVisitor(includeSize: includeSize)
        return rootComposite.accept(visitor: visitor)
    }
    
    @MainActor
    public class Coordinator: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
        var parent: NativeArchiveOutlineView
        var lastNodesCount: Int = -1
        var lastRootNodesIDs: [String] = []
        nonisolated(unsafe) var moveUpObserver: NSObjectProtocol?
        nonisolated(unsafe) var moveDownObserver: NSObjectProtocol?
        nonisolated(unsafe) var moveLeftObserver: NSObjectProtocol?
        nonisolated(unsafe) var moveRightObserver: NSObjectProtocol?
        weak var outlineView: NSOutlineView?
        
        init(parent: NativeArchiveOutlineView) {
            self.parent = parent
            super.init()
            
            moveUpObserver = NotificationCenter.default.addObserver(forName: .archiveExplorerMoveUp, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self = self, let outlineView = self.outlineView else { return }
                    let total = outlineView.numberOfRows
                    guard total > 0 else { return }
                    let currentRow = outlineView.selectedRow
                    let targetRow = currentRow < 0 ? total - 1 : max(0, currentRow - 1)
                    outlineView.selectRowIndexes(IndexSet(integer: targetRow), byExtendingSelection: false)
                    outlineView.scrollRowToVisible(targetRow)
                }
            }
            moveDownObserver = NotificationCenter.default.addObserver(forName: .archiveExplorerMoveDown, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self = self, let outlineView = self.outlineView else { return }
                    let total = outlineView.numberOfRows
                    guard total > 0 else { return }
                    let currentRow = outlineView.selectedRow
                    let targetRow = currentRow < 0 ? 0 : min(total - 1, currentRow + 1)
                    outlineView.selectRowIndexes(IndexSet(integer: targetRow), byExtendingSelection: false)
                    outlineView.scrollRowToVisible(targetRow)
                }
            }
            moveRightObserver = NotificationCenter.default.addObserver(forName: .archiveExplorerMoveRight, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self = self, let outlineView = self.outlineView else { return }
                    let selectedRow = outlineView.selectedRow
                    guard selectedRow >= 0, let item = outlineView.item(atRow: selectedRow) else { return }
                    if outlineView.isExpandable(item) {
                        if !outlineView.isItemExpanded(item) {
                            outlineView.expandItem(item)
                        } else {
                            let nextRow = selectedRow + 1
                            if nextRow < outlineView.numberOfRows {
                                outlineView.selectRowIndexes(IndexSet(integer: nextRow), byExtendingSelection: false)
                                outlineView.scrollRowToVisible(nextRow)
                            }
                        }
                    }
                }
            }
            moveLeftObserver = NotificationCenter.default.addObserver(forName: .archiveExplorerMoveLeft, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self = self, let outlineView = self.outlineView else { return }
                    let selectedRow = outlineView.selectedRow
                    guard selectedRow >= 0, let item = outlineView.item(atRow: selectedRow) else { return }
                    if outlineView.isExpandable(item) && outlineView.isItemExpanded(item) {
                        outlineView.collapseItem(item)
                    } else if let parentItem = outlineView.parent(forItem: item) {
                        let parentRow = outlineView.row(forItem: parentItem)
                        if parentRow >= 0 {
                            outlineView.selectRowIndexes(IndexSet(integer: parentRow), byExtendingSelection: false)
                            outlineView.scrollRowToVisible(parentRow)
                        }
                    }
                }
            }
        }
        
        deinit {
            if let obs = moveUpObserver { NotificationCenter.default.removeObserver(obs) }
            if let obs = moveDownObserver { NotificationCenter.default.removeObserver(obs) }
            if let obs = moveLeftObserver { NotificationCenter.default.removeObserver(obs) }
            if let obs = moveRightObserver { NotificationCenter.default.removeObserver(obs) }
        }
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        
        let outlineView = NSOutlineView()
        outlineView.autoresizesOutlineColumn = true
        outlineView.headerView = NSTableHeaderView()
        outlineView.selectionHighlightStyle = .regular
        outlineView.usesAlternatingRowBackgroundColors = false
        outlineView.backgroundColor = .clear
        outlineView.rowHeight = 24
        
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "Name"
        nameColumn.minWidth = 240
        nameColumn.width = 340
        outlineView.addTableColumn(nameColumn)
        outlineView.outlineTableColumn = nameColumn
        
        let sizeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("size"))
        sizeColumn.title = "Size"
        sizeColumn.minWidth = 80
        sizeColumn.width = 100
        outlineView.addTableColumn(sizeColumn)
        
        let encodingColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("encoding"))
        encodingColumn.title = "Encoding"
        encodingColumn.minWidth = 80
        encodingColumn.width = 100
        outlineView.addTableColumn(encodingColumn)
        
        outlineView.dataSource = context.coordinator
        outlineView.delegate = context.coordinator
        context.coordinator.outlineView = outlineView
        
        scrollView.documentView = outlineView
        
        DispatchQueue.main.async {
            scrollView.scrollerStyle = .overlay
            scrollView.autohidesScrollers = true
            scrollView.verticalScroller?.scrollerStyle = .overlay
            scrollView.horizontalScroller?.scrollerStyle = .overlay
            scrollView.verticalScroller?.alphaValue = 0
            scrollView.horizontalScroller?.alphaValue = 0
        }
        return scrollView
    }
    
    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        DispatchQueue.main.async {
            nsView.scrollerStyle = .overlay
            nsView.autohidesScrollers = true
        }
        if let outlineView = nsView.documentView as? NSOutlineView {
            let currentIDs = nodes.map { $0.id }
            if context.coordinator.lastRootNodesIDs != currentIDs {
                context.coordinator.lastRootNodesIDs = currentIDs
                context.coordinator.lastNodesCount = nodes.count
                outlineView.reloadData()
            }
            
            if let selectedPath = selectedPath {
                var foundRow = -1
                for i in 0..<outlineView.numberOfRows {
                    if let node = outlineView.item(atRow: i) as? ArchiveTreeNode, node.id == selectedPath {
                        foundRow = i
                        break
                    }
                }
                if foundRow >= 0, outlineView.selectedRow != foundRow {
                    outlineView.selectRowIndexes(IndexSet(integer: foundRow), byExtendingSelection: false)
                    outlineView.scrollRowToVisible(foundRow)
                }
            } else {
                if outlineView.selectedRow != -1 {
                    outlineView.deselectAll(nil)
                }
            }
        }
    }
}
