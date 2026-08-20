// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import AppKit
import TTZipCore

/// Dynamically updates AppKit system menu bar items when the user switches application language.
@MainActor
public final class AppKitMenuSynchronizer {
    public static let shared = AppKitMenuSynchronizer()
    
    private init() {}
    
    /// Synchronizes top-level and submenu items with the active language catalog.
    public func synchronize(language: AppLanguage) {
        guard let mainMenu = NSApplication.shared.mainMenu else { return }
        let manager = TTZipLocalizationManager.shared
        
        for item in mainMenu.items {
            if let title = item.title as String?, !title.isEmpty {
                switch title {
                case "File", "文件", "檔案":
                    item.title = manager.string(for: L10n.Menu.fileMenu, language: language)
                case "Edit", "编辑", "編輯":
                    item.title = manager.string(for: L10n.Menu.editMenu, language: language)
                case "View", "显示", "顯示", "顯示方式":
                    item.title = manager.string(for: L10n.Menu.viewMenu, language: language)
                case "Window", "窗口", "視窗":
                    item.title = manager.string(for: L10n.Menu.windowMenu, language: language)
                case "Help", "帮助", "輔助說明":
                    item.title = manager.string(for: L10n.Menu.helpMenu, language: language)
                default:
                    break
                }
            }
            if let submenu = item.submenu {
                synchronizeSubmenu(submenu, language: language)
            }
        }
    }
    
    private func synchronizeSubmenu(_ menu: NSMenu, language: AppLanguage) {
        let manager = TTZipLocalizationManager.shared
        for item in menu.items {
            if let action = item.action {
                switch action {
                case #selector(NSApplication.orderFrontStandardAboutPanel(_:)):
                    item.title = manager.string(for: L10n.Menu.about, language: language)
                case #selector(NSApplication.hide(_:)):
                    item.title = manager.string(for: L10n.Menu.hide, language: language)
                case #selector(NSApplication.hideOtherApplications(_:)):
                    item.title = manager.string(for: L10n.Menu.hideOthers, language: language)
                case #selector(NSApplication.unhideAllApplications(_:)):
                    item.title = manager.string(for: L10n.Menu.showAll, language: language)
                case #selector(NSApplication.terminate(_:)):
                    item.title = manager.string(for: L10n.Menu.quit, language: language)
                case #selector(NSWindow.performClose(_:)):
                    item.title = manager.string(for: L10n.Menu.closeWindow, language: language)
                case #selector(NSWindow.performMiniaturize(_:)):
                    item.title = manager.string(for: L10n.Menu.minimize, language: language)
                case #selector(NSWindow.performZoom(_:)):
                    item.title = manager.string(for: L10n.Menu.zoom, language: language)
                case #selector(NSWindow.toggleFullScreen(_:)):
                    item.title = manager.string(for: L10n.Menu.toggleFullScreen, language: language)
                default:
                    break
                }
            }
            if let sub = item.submenu {
                synchronizeSubmenu(sub, language: language)
            }
        }
    }
}
