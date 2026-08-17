// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Weitao Kung (Witt Kung) <kevintungs@163.com>
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
        let isZh = (language == .zhHans || language == .zhHant)
        
        for item in mainMenu.items {
            if let submenu = item.submenu {
                synchronizeSubmenu(submenu, isZh: isZh)
            }
        }
    }
    
    private func synchronizeSubmenu(_ menu: NSMenu, isZh: Bool) {
        for item in menu.items {
            if let action = item.action {
                switch action {
                case #selector(NSApplication.orderFrontStandardAboutPanel(_:)):
                    item.title = isZh ? "关于 TTZip" : "About TTZip"
                case #selector(NSApplication.hide(_:)):
                    item.title = isZh ? "隐藏 TTZip" : "Hide TTZip"
                case #selector(NSApplication.hideOtherApplications(_:)):
                    item.title = isZh ? "隐藏其他" : "Hide Others"
                case #selector(NSApplication.unhideAllApplications(_:)):
                    item.title = isZh ? "显示全部" : "Show All"
                case #selector(NSApplication.terminate(_:)):
                    item.title = isZh ? "退出 TTZip" : "Quit TTZip"
                case #selector(NSWindow.performClose(_:)):
                    item.title = isZh ? "关闭窗口" : "Close Window"
                case #selector(NSWindow.performMiniaturize(_:)):
                    item.title = isZh ? "最小化" : "Minimize"
                case #selector(NSWindow.performZoom(_:)):
                    item.title = isZh ? "缩放" : "Zoom"
                default:
                    break
                }
            }
            if let sub = item.submenu {
                synchronizeSubmenu(sub, isZh: isZh)
            }
        }
    }
}
