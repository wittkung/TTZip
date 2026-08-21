// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

extension InteractiveTUIExplorer {
    
    // MARK: - Tree Virtualization
    
    func rebuildVisibleRows(state: inout TUISessionState, root: ArchiveCompositeDirectory) {
        var rows: [TUIVisibleRow] = []
        
        func traverse(node: ArchiveComponentProtocol, depth: Int, prefix: String) {
            let isDir = node.isDirectory
            let isExpanded = state.expandedPaths.contains(node.path)
            let isSelected = state.selectedPaths.contains(node.path)
            let formattedSize = ByteSizeFormatter.format(bytes: node.sizeBytes, style: .metricSI, language: .en)
            let icon = isDir ? (isExpanded ? "📂" : "📁") : iconForFile(path: node.path)
            
            let row = TUIVisibleRow(
                name: node.name,
                path: node.path,
                isDirectory: isDir,
                depth: depth,
                isExpanded: isExpanded,
                sizeBytes: node.sizeBytes,
                formattedSize: formattedSize,
                isSelected: isSelected,
                indentationPrefix: prefix,
                iconEmoji: icon
            )
            rows.append(row)
            
            if isDir && isExpanded {
                let children = node.getChildren()
                for (idx, child) in children.enumerated() {
                    let isLast = (idx == children.count - 1)
                    let childIndent = prefix + (isLast ? "    " : "│   ")
                    traverse(node: child, depth: depth + 1, prefix: childIndent)
                }
            }
        }
        
        for child in root.getChildren() {
            traverse(node: child, depth: 0, prefix: "")
        }
        
        state.visibleRows = rows
        
        if rows.isEmpty {
            state.cursorIndex = 0
            state.scrollOffset = 0
        } else {
            state.cursorIndex = min(max(0, state.cursorIndex), rows.count - 1)
        }
    }
    
    // MARK: - Frame Rendering
    
    func renderFrame(state: TUISessionState, root: ArchiveCompositeDirectory, entries: [ArchiveEntry]) {
        let rows = state.terminalRows
        let cols = state.terminalCols
        guard rows >= 4 && cols >= 20 else { return }
        
        var screen = Array(repeating: "", count: rows)
        
        // Line 0: Header & Metadata Badge
        let baseName = (archivePath as NSString).lastPathComponent
        let totalSize = root.sizeBytes
        let totalSizeStr = ByteSizeFormatter.format(bytes: totalSize, style: .metricSI, language: .en)
        let headerTitle = "[TTZip Explorer] \(baseName) (\(totalSizeStr), \(entries.count) items)"
        screen[0] = "\u{001B}[1m\u{001B}[36m" + clampString(headerTitle, maxLen: cols) + "\u{001B}[0m"
        
        // Line 1: Top Separator
        screen[1] = String(repeating: "─", count: cols)
        
        // Lines 2 ..< (rows - 2): Virtualized Tree Viewport
        let viewportHeight = max(1, rows - 4)
        var scrollOffset = state.scrollOffset
        if state.cursorIndex < scrollOffset {
            scrollOffset = state.cursorIndex
        } else if state.cursorIndex >= scrollOffset + viewportHeight {
            scrollOffset = state.cursorIndex - viewportHeight + 1
        }
        scrollOffset = max(0, min(scrollOffset, max(0, state.visibleRows.count - viewportHeight)))
        
        for lineIdx in 0..<viewportHeight {
            let screenRow = 2 + lineIdx
            let itemIdx = scrollOffset + lineIdx
            if itemIdx < state.visibleRows.count {
                let row = state.visibleRows[itemIdx]
                let isCursor = (itemIdx == state.cursorIndex)
                screen[screenRow] = formatTreeRow(row: row, isCursor: isCursor, cols: cols)
            } else {
                screen[screenRow] = ""
            }
        }
        
        // Line (rows - 2): Bottom Separator
        screen[rows - 2] = String(repeating: "─", count: cols)
        
        // Line (rows - 1): Footer Status Bar / Keybinding Hints
        if let flash = state.flashMessage, !flash.isEmpty {
            screen[rows - 1] = "\u{001B}[1m\u{001B}[33m▶ \(clampString(flash, maxLen: cols - 3))\u{001B}[0m"
        } else {
            let hints = "↑/k: Up  ↓/j: Down  Enter/l: Open  Space: Select  e: Extract  p: Peek  q: Quit"
            screen[rows - 1] = "\u{001B}[90m" + clampString(hints, maxLen: cols) + "\u{001B}[0m"
        }
        
        // Overlay Peek Modal if active
        if state.isPeeking, let peek = state.peekContent {
            overlayPeekModal(peek: peek, screen: &screen, rows: rows, cols: cols)
        }
        
        // Single flush to terminal
        let frameBuffer = "\u{001B}[H" + screen.map { "\u{001B}[2K" + $0 }.joined(separator: "\r\n")
        fputs(frameBuffer, stdout)
        fflush(stdout)
    }
    
    func formatTreeRow(row: TUIVisibleRow, isCursor: Bool, cols: Int) -> String {
        let sel = row.isSelected ? "[x] " : "[ ] "
        let indent = row.indentationPrefix
        let dirArrow = row.isDirectory ? (row.isExpanded ? "▼ " : "▶ ") : "  "
        let icon = "\(row.iconEmoji) "
        let sizeStr = row.formattedSize
        
        let leftPart = sel + indent + dirArrow + icon + row.name
        let availableForLeft = max(0, cols - sizeStr.count - 2)
        let truncatedLeft = clampString(leftPart, maxLen: availableForLeft)
        let padCount = max(1, cols - truncatedLeft.count - sizeStr.count)
        let fullLine = truncatedLeft + String(repeating: " ", count: padCount) + sizeStr
        
        if isCursor {
            return "\u{001B}[7m\u{001B}[1m" + fullLine + "\u{001B}[0m"
        } else if row.isSelected {
            return "\u{001B}[32m" + fullLine + "\u{001B}[0m"
        } else {
            return fullLine
        }
    }
    
    func overlayPeekModal(peek: TUIPeekContent, screen: inout [String], rows: Int, cols: Int) {
        let modalWidth = min(max(cols - 4, 30), 80)
        let modalHeight = min(max(rows - 4, 8), 20)
        let startCol = (cols - modalWidth) / 2
        let startRow = (rows - modalHeight) / 2
        let innerWidth = modalWidth - 2
        
        let title = " Peek: \((peek.filePath as NSString).lastPathComponent) (\(peek.formattedSize)) "
        let clampedTitle = clampString(title, maxLen: max(0, innerWidth - 4))
        let topBorder = "┌─\(clampedTitle)" + String(repeating: "─", count: max(0, innerWidth - clampedTitle.count - 1)) + "┐"
        
        var modalLines: [String] = [topBorder]
        let contentAreaHeight = modalHeight - 2
        let peekLines = peek.lines
        
        for lineIdx in 0..<contentAreaHeight {
            if lineIdx < peekLines.count {
                let rawLine = peekLines[lineIdx]
                let truncated = clampString(rawLine, maxLen: innerWidth)
                let padded = truncated.padding(toLength: innerWidth, withPad: " ", startingAt: 0)
                modalLines.append("│\(padded)│")
            } else if lineIdx == contentAreaHeight - 1 && peek.isTruncated {
                let notice = " ... [Truncated preview] ..."
                let padded = notice.padding(toLength: innerWidth, withPad: " ", startingAt: 0)
                modalLines.append("│\(padded)│")
            } else {
                modalLines.append("│" + String(repeating: " ", count: innerWidth) + "│")
            }
        }
        
        let hint = " [Press 'p' / 'q' / ESC to close] "
        let clampedHint = clampString(hint, maxLen: max(0, innerWidth - 4))
        let bottomBorder = "└─\(clampedHint)" + String(repeating: "─", count: max(0, innerWidth - clampedHint.count - 1)) + "┘"
        modalLines.append(bottomBorder)
        
        let leftPad = String(repeating: " ", count: max(0, startCol))
        let rightPad = String(repeating: " ", count: max(0, cols - startCol - modalWidth))
        
        for (offset, line) in modalLines.enumerated() {
            let targetRow = startRow + offset
            if targetRow >= 0 && targetRow < rows {
                screen[targetRow] = leftPad + "\u{001B}[1m\u{001B}[33m" + line + "\u{001B}[0m" + rightPad
            }
        }
    }
}
