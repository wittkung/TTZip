// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import AppKit

/// Unified helper service for native system open/save dialogs.
@MainActor
public enum SystemDialogHelper {
    /// Presents directory selection panel.
    public static func pickDirectory(prompt: String = "Select Destination Folder", defaultPath: String? = nil) -> String? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = prompt
        if let path = defaultPath, !path.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: path)
        }
        if panel.runModal() == .OK, let url = panel.url {
            return url.path
        }
        return nil
    }

    /// Presents file selection panel.
    public static func pickFiles(
        prompt: String = "Open Files",
        canChooseDirectories: Bool = true,
        allowsMultipleSelection: Bool = true
    ) -> [String] {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = canChooseDirectories
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = allowsMultipleSelection
        panel.prompt = prompt
        if panel.runModal() == .OK {
            return panel.urls.map { $0.path }
        }
        return []
    }
}
