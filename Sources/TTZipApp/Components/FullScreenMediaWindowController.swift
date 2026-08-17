import SwiftUI
import AppKit

/// macOS 真正真全屏沉浸显示控制器 (超越 Window / 遮罩 Dock 与菜单栏)
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
        win.level = .screenSaver // 最高级全屏视效，覆盖系统的 Menu Bar 和 Dock
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
