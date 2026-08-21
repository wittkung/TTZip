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
    
    // MARK: - Utilities
    
    func updateTerminalSize(_ state: inout TUISessionState) {
        var ws = winsize()
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0 && ws.ws_col > 0 && ws.ws_row > 0 {
            state.terminalRows = Int(ws.ws_row)
            state.terminalCols = Int(ws.ws_col)
        } else {
            state.terminalRows = 24
            state.terminalCols = 80
        }
    }
    
    func iconForFile(path: String) -> String {
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
    
    func clampString(_ str: String, maxLen: Int) -> String {
        guard maxLen > 0 else { return "" }
        if str.count <= maxLen { return str }
        return String(str.prefix(maxLen))
    }
}
