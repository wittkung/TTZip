// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import AppKit
import TTZipCore

/// Unified helper service for native system open/save dialogs.
@MainActor
public enum SystemDialogHelper {
    /// Presents directory selection panel.
    public static func pickDirectory(prompt: String? = nil, defaultPath: String? = nil) -> String? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = prompt ?? TTZipLocalizationManager.shared.string(for: L10n.Common.selectDestination)
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
        prompt: String? = nil,
        canChooseDirectories: Bool = true,
        allowsMultipleSelection: Bool = true
    ) -> [String] {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = canChooseDirectories
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = allowsMultipleSelection
        panel.prompt = prompt ?? TTZipLocalizationManager.shared.string(for: L10n.Common.openFiles)
        if panel.runModal() == .OK {
            return panel.urls.map { $0.path }
        }
        return []
    }
    
    /// Displays a localized confirmation alert for deleting an item.
    public static func confirmDeletion(itemName: String) -> Bool {
        let alert = NSAlert()
        let manager = TTZipLocalizationManager.shared
        alert.messageText = manager.string(for: L10n.Dialogs.confirmDeleteTitle)
        let msgTemplate = manager.string(for: L10n.Dialogs.confirmDeleteMessage)
        alert.informativeText = String(format: msgTemplate, itemName)
        alert.addButton(withTitle: manager.string(for: L10n.Common.delete))
        alert.addButton(withTitle: manager.string(for: L10n.Common.cancel))
        alert.alertStyle = .critical
        return alert.runModal() == .alertFirstButtonReturn
    }
    
    /// Displays a localized confirmation alert for overwriting an existing destination file.
    public static func confirmOverwrite(itemName: String) -> Bool {
        let alert = NSAlert()
        let manager = TTZipLocalizationManager.shared
        alert.messageText = manager.string(for: L10n.Dialogs.overwriteTitle)
        let msgTemplate = manager.string(for: L10n.Dialogs.overwriteMessage)
        alert.informativeText = String(format: msgTemplate, itemName)
        alert.addButton(withTitle: manager.string(for: L10n.Dialogs.alertOverwrite))
        alert.addButton(withTitle: manager.string(for: L10n.Dialogs.alertSkip))
        alert.alertStyle = .warning
        return alert.runModal() == .alertFirstButtonReturn
    }
}
