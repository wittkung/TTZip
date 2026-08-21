// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

extension InteractiveTUIExplorer {
    
    // MARK: - State & Event Handling
    
    func handleAction(
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
    
    func triggerPeek(for row: TUIVisibleRow, state: inout TUISessionState) async {
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
    
    func triggerExtract(state: inout TUISessionState, entries: [ArchiveEntry]) async {
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
}
