// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Interactive ANSI/VT100 Terminal UI Archive Explorer (`ttzip-cli explore`).
///
/// Features:
/// - In-memory double-buffered single-flush rendering (`\u{001B}[?1049h`).
/// - Virtualized tree viewport supporting 100,000+ archive entries at 60 FPS.
/// - Vim keybindings (`h`/`j`/`k`/`l`), arrow keys, multi-select (`Space`), quick peek modal (`p`), and selective extraction (`e`).
/// - Automatic fallback to tree list rendering in non-interactive / piped environments.
public final class InteractiveTUIExplorer: @unchecked Sendable {
    
    public let archivePath: String
    public let password: String?
    
    public init(archivePath: String, password: String? = nil) {
        self.archivePath = archivePath
        self.password = password
    }
    
    /// Executes the interactive TUI session run loop until the user exits.
    /// - Returns: Process exit code (0 for success).
    @discardableResult
    public func run() async throws -> Int32 {
        // 1. Non-interactive fallback: If STDIN or STDOUT is not a TTY, print tree and exit
        guard isatty(STDIN_FILENO) != 0 && isatty(STDOUT_FILENO) != 0 else {
            let inspection = try await TTZipEngineFacade.shared.inspectArchive(archivePath: archivePath, password: password)
            let treeText = ArchiveVisualTreeRenderer.render(archivePath: archivePath, entries: inspection.entries)
            print(treeText)
            return 0
        }
        
        // 2. Inspect archive structure to build the composite directory tree
        let inspection = try await TTZipEngineFacade.shared.inspectArchive(archivePath: archivePath, password: password)
        let root = inspection.treeNode
        let entries = inspection.entries
        
        // 3. Initialize TUI Session State
        var state = TUISessionState(archivePath: archivePath)
        updateTerminalSize(&state)
        
        // Expand root by default if there are direct child directories
        for child in root.getChildren() where child.isDirectory {
            state.expandedPaths.insert(child.path)
        }
        
        // 4. Enter Raw Mode & Switch to Alternate Screen Buffer
        guard TerminalRawModeManager.shared.enableRawMode() else {
            let treeText = ArchiveVisualTreeRenderer.render(archivePath: archivePath, entries: entries)
            print(treeText)
            return 0
        }
        
        // Alternate Screen Buffer + Hide Cursor
        fputs("\u{001B}[?1049h\u{001B}[?25l", stdout)
        fflush(stdout)
        
        defer {
            // Restore Main Screen Buffer + Show Cursor + Disable Raw Mode
            fputs("\u{001B}[?1049l\u{001B}[?25h", stdout)
            fflush(stdout)
            TerminalRawModeManager.shared.disableRawMode()
        }
        
        // 5. Main Interactive Event Loop
        while !state.isExiting {
            updateTerminalSize(&state)
            rebuildVisibleRows(state: &state, root: root)
            renderFrame(state: state, root: root, entries: entries)
            
            // Read input bytes with timeout
            if let firstByte = TerminalRawModeManager.shared.readByte() {
                var inputBytes: [UInt8] = [firstByte]
                
                // If escape character (0x1B), read trailing sequence bytes if available
                if firstByte == 0x1B {
                    var pollFd = pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)
                    while poll(&pollFd, 1, 25) > 0 && (pollFd.revents & Int16(POLLIN)) != 0 {
                        var nextByte: UInt8 = 0
                        if read(STDIN_FILENO, &nextByte, 1) == 1 {
                            inputBytes.append(nextByte)
                        } else {
                            break
                        }
                        if inputBytes.count >= 8 { break }
                    }
                }
                
                let action = TUIKeyParser.parse(bytes: inputBytes)
                await handleAction(action, state: &state, root: root, entries: entries)
            }
        }
        
        return 0
    }
    
    // MARK: - State & Event Handling
    
    private func handleAction(
        _ action: TUIKeyAction,
        state: inout TUISessionState,
        root: ArchiveCompositeDirectory,
        entries: [ArchiveEntry]
    ) async {
        // When Modal Peek is active, any dismiss key closes the modal
        if state.isPeeking {
            switch action {
            case .peek, .exit, .enter, .space, .left, .right:
                state.isPeeking = false
                state.peekContent = nil
                state.flashMessage = nil
            default:
                break
            }
            return
        }
        
        switch action {
        case .up:
            if state.cursorIndex > 0 {
                state.cursorIndex -= 1
                state.flashMessage = nil
            }
            
        case .down:
            if state.cursorIndex < state.visibleRows.count - 1 {
                state.cursorIndex += 1
                state.flashMessage = nil
            }
            
        case .pageUp:
            let pageSize = max(1, state.terminalRows - 4)
            state.cursorIndex = max(0, state.cursorIndex - pageSize)
            state.flashMessage = nil
            
        case .pageDown:
            let pageSize = max(1, state.terminalRows - 4)
            state.cursorIndex = min(max(0, state.visibleRows.count - 1), state.cursorIndex + pageSize)
            state.flashMessage = nil
            
        case .home:
            state.cursorIndex = 0
            state.flashMessage = nil
            
        case .end:
            state.cursorIndex = max(0, state.visibleRows.count - 1)
            state.flashMessage = nil
            
        case .left:
            if !state.visibleRows.isEmpty && state.cursorIndex < state.visibleRows.count {
                let current = state.visibleRows[state.cursorIndex]
                if current.isDirectory && state.expandedPaths.contains(current.path) {
                    state.expandedPaths.remove(current.path)
                } else {
                    let parentPath = (current.path as NSString).deletingLastPathComponent
                    if let parentIdx = state.visibleRows.firstIndex(where: { $0.path == parentPath }) {
                        state.cursorIndex = parentIdx
                    }
                }
                state.flashMessage = nil
            }
            
        case .right, .enter:
            if !state.visibleRows.isEmpty && state.cursorIndex < state.visibleRows.count {
                let current = state.visibleRows[state.cursorIndex]
                if current.isDirectory {
                    if state.expandedPaths.contains(current.path) {
                        state.expandedPaths.remove(current.path)
                    } else {
                        state.expandedPaths.insert(current.path)
                    }
                    state.flashMessage = nil
                } else {
                    await triggerPeek(for: current, state: &state)
                }
            }
            
        case .space:
            if !state.visibleRows.isEmpty && state.cursorIndex < state.visibleRows.count {
                let current = state.visibleRows[state.cursorIndex]
                if state.selectedPaths.contains(current.path) {
                    state.selectedPaths.remove(current.path)
                    state.flashMessage = "Deselected: \(current.name)"
                } else {
                    state.selectedPaths.insert(current.path)
                    state.flashMessage = "Selected: \(current.name) (\(state.selectedPaths.count) item(s) selected)"
                }
            }
            
        case .peek:
            if !state.visibleRows.isEmpty && state.cursorIndex < state.visibleRows.count {
                let current = state.visibleRows[state.cursorIndex]
                if !current.isDirectory {
                    await triggerPeek(for: current, state: &state)
                } else {
                    state.flashMessage = "Cannot peek a directory. Press Enter to expand."
                }
            }
            
        case .extract:
            await triggerExtract(state: &state, entries: entries)
            
        case .exit:
            state.isExiting = true
            
        case .unknown:
            break
        }
    }
    
    // MARK: - Actions: Peek & Extract
    
    private func triggerPeek(for row: TUIVisibleRow, state: inout TUISessionState) async {
        let tmpDir = NSTemporaryDirectory() + "ttzip_tui_peek_" + UUID().uuidString
        let fm = FileManager.default
        do {
            try fm.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)
            defer {
                try? fm.removeItem(atPath: tmpDir)
            }
            
            try await TTZipEngineFacade.shared.extractSingleEntry(
                archivePath: archivePath,
                entryPath: row.path,
                destinationDir: tmpDir,
                password: password
            )
            
            let extractedFilePath = (tmpDir as NSString).appendingPathComponent(row.path)
            guard fm.fileExists(atPath: extractedFilePath),
                  let data = fm.contents(atPath: extractedFilePath) else {
                state.flashMessage = "Preview unavailable for \(row.name)"
                return
            }
            
            let mime = ArchiveEntryFlyweightFactory.shared.detectMimeType(forPath: row.path)
            let uncompressedSize = row.sizeBytes
            let formattedSize = row.formattedSize
            
            var lines: [String] = []
            var hexDump: String? = nil
            var isTruncated = false
            
            if let utf8Text = String(data: data.prefix(64 * 1024), encoding: .utf8) {
                let allLines = utf8Text.components(separatedBy: .newlines)
                let maxLines = 100
                lines = Array(allLines.prefix(maxLines))
                if allLines.count > maxLines || data.count > 64 * 1024 {
                    isTruncated = true
                }
            } else {
                let prefixData = data.prefix(1024)
                var hexLines: [String] = []
                var offset = 0
                while offset < prefixData.count {
                    let chunk = prefixData[offset..<min(offset + 16, prefixData.count)]
                    let hexString = chunk.map { String(format: "%02x", $0) }.joined(separator: " ")
                    let paddedHex = hexString.padding(toLength: 48, withPad: " ", startingAt: 0)
                    let asciiString = String(chunk.map { (32...126).contains($0) ? Character(UnicodeScalar($0)) : "." })
                    hexLines.append(String(format: "%08x: %@  %@", offset, paddedHex, asciiString))
                    offset += 16
                }
                lines = hexLines
                hexDump = hexLines.joined(separator: "\n")
                if data.count > 1024 {
                    isTruncated = true
                }
            }
            
            state.peekContent = TUIPeekContent(
                filePath: row.path,
                mimeType: mime,
                uncompressedSize: uncompressedSize,
                formattedSize: formattedSize,
                lines: lines,
                hexDump: hexDump,
                metadata: ["Size": formattedSize, "MIME": mime],
                isTruncated: isTruncated
            )
            state.isPeeking = true
            state.flashMessage = nil
        } catch {
            state.flashMessage = "Peek error: \(error.localizedDescription)"
        }
    }
    
    private func triggerExtract(state: inout TUISessionState, entries: [ArchiveEntry]) async {
        let cwd = FileManager.default.currentDirectoryPath
        var pathsToExtract: [String] = []
        
        if !state.selectedPaths.isEmpty {
            pathsToExtract = Array(state.selectedPaths)
        } else if !state.visibleRows.isEmpty && state.cursorIndex < state.visibleRows.count {
            pathsToExtract = [state.visibleRows[state.cursorIndex].path]
        }
        
        guard !pathsToExtract.isEmpty else {
            state.flashMessage = "Nothing selected to extract."
            return
        }
        
        var extractedCount = 0
        var failureCount = 0
        
        for path in pathsToExtract {
            do {
                try await TTZipEngineFacade.shared.extractSingleEntry(
                    archivePath: archivePath,
                    entryPath: path,
                    destinationDir: cwd,
                    password: password
                )
                extractedCount += 1
            } catch {
                failureCount += 1
            }
        }
        
        state.selectedPaths.removeAll()
        if failureCount == 0 {
            state.flashMessage = "Extracted \(extractedCount) item(s) to \(cwd)"
        } else {
            state.flashMessage = "Extracted \(extractedCount) item(s), \(failureCount) failed"
        }
    }
    
    // MARK: - Tree Virtualization
    
    private func rebuildVisibleRows(state: inout TUISessionState, root: ArchiveCompositeDirectory) {
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
    
    private func renderFrame(state: TUISessionState, root: ArchiveCompositeDirectory, entries: [ArchiveEntry]) {
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
    
    private func formatTreeRow(row: TUIVisibleRow, isCursor: Bool, cols: Int) -> String {
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
    
    private func overlayPeekModal(peek: TUIPeekContent, screen: inout [String], rows: Int, cols: Int) {
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
    
    // MARK: - Utilities
    
    private func updateTerminalSize(_ state: inout TUISessionState) {
        var ws = winsize()
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0 && ws.ws_col > 0 && ws.ws_row > 0 {
            state.terminalRows = Int(ws.ws_row)
            state.terminalCols = Int(ws.ws_col)
        } else {
            state.terminalRows = 24
            state.terminalCols = 80
        }
    }
    
    private func iconForFile(path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "zip", "7z", "tar", "gz", "xz", "bz2", "zst", "rar", "iso", "dmg":
            return "📦"
        case "png", "jpg", "jpeg", "gif", "webp", "heic", "svg":
            return "🖼️"
        case "mp4", "mov", "mkv", "avi":
            return "🎬"
        case "mp3", "wav", "flac", "aac", "m4a":
            return "🎵"
        case "swift", "c", "h", "cpp", "py", "js", "ts", "json", "xml", "html", "css", "sh", "md":
            return "📄"
        case "pdf", "doc", "docx":
            return "📑"
        default:
            return "📄"
        }
    }
    
    private func clampString(_ str: String, maxLen: Int) -> String {
        guard maxLen > 0 else { return "" }
        if str.count <= maxLen { return str }
        return String(str.prefix(maxLen))
    }
}
