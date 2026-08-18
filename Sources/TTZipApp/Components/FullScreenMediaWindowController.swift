// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import AppKit

/// Immersive full-screen presentation window controller overriding system Dock and menu bar.
@MainActor
public final class FullScreenMediaWindowController {
    public static let shared = FullScreenMediaWindowController()
    
    private var window: NSWindow?
    private var previousPresentationOptions: NSApplication.PresentationOptions = []
    private var onDismissHandler: (() -> Void)? = nil
    
    private init() {}
    
    public func present(view: AnyView, onDismiss: (() -> Void)? = nil) {
        if window != nil {
            dismiss()
        }
        
        self.onDismissHandler = onDismiss
        
        guard let screen = NSScreen.main else { return }
        
        let win = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.level = .screenSaver
        win.isOpaque = true
        win.backgroundColor = .black
        win.hasShadow = false
        win.contentView = NSHostingView(rootView: view)
        win.makeKeyAndOrderFront(nil)
        
        self.previousPresentationOptions = NSApp.presentationOptions
        NSApp.presentationOptions = [.hideDock, .autoHideMenuBar]
        
        self.window = win
    }
    
    public func dismiss() {
        guard let win = window else { return }
        win.orderOut(nil)
        self.window = nil
        NSApp.presentationOptions = previousPresentationOptions
        onDismissHandler?()
        onDismissHandler = nil
    }
    
    public func update(view: AnyView) {
        guard let win = window else { return }
        if let hostingView = win.contentView as? NSHostingView<AnyView> {
            hostingView.rootView = view
        } else {
            win.contentView = NSHostingView(rootView: view)
        }
    }
    
    public var isPresenting: Bool {
        return window != nil
    }
}
