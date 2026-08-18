// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import AppKit

final class FlippedClipView: NSClipView {
    override var isFlipped: Bool { true }
}

final class FlippedContainerView: NSView {
    override var isFlipped: Bool { true }
}

/// AppKit native autohiding overlay scroll view.
public struct AppKitMillerColumnScrollView<Content: View>: NSViewRepresentable {
    let content: Content
    
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    public func makeNSView(context: Context) -> AutoHidingOverlayScrollView {
        let scrollView = AutoHidingOverlayScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        
        let clipView = FlippedClipView()
        clipView.drawsBackground = false
        scrollView.contentView = clipView
        
        let container = FlippedContainerView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hostingView)
        
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: container.topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        scrollView.documentView = container
        
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: clipView.topAnchor),
            container.leadingAnchor.constraint(equalTo: clipView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: clipView.trailingAnchor)
        ])
        
        return scrollView
    }
    
    public func updateNSView(_ nsView: AutoHidingOverlayScrollView, context: Context) {
        if let container = nsView.documentView as? FlippedContainerView,
           let hostingView = container.subviews.first as? NSHostingView<Content> {
            hostingView.rootView = content
        }
        if nsView.scrollerStyle != .overlay {
            nsView.scrollerStyle = .overlay
        }
        if !nsView.autohidesScrollers {
            nsView.autohidesScrollers = true
        }
    }
}

@MainActor
public final class AutoHidingOverlayScrollView: NSScrollView {
    private var hideTimer: Timer?
    private var isUserScrolling = false
    
    public override func tile() {
        super.tile()
        self.scrollerStyle = .overlay
        self.autohidesScrollers = true
        if let vScroller = self.verticalScroller {
            vScroller.scrollerStyle = .overlay
            if !isUserScrolling {
                vScroller.isHidden = true
                vScroller.alphaValue = 0
            }
        }
    }
    
    public override func scrollWheel(with event: NSEvent) {
        super.scrollWheel(with: event)
        handleScroll()
    }
    
    private func handleScroll() {
        isUserScrolling = true
        if let vScroller = self.verticalScroller {
            vScroller.scrollerStyle = .overlay
            vScroller.isHidden = false
            vScroller.alphaValue = 1.0
        }
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isUserScrolling = false
                if let vScroller = self.verticalScroller {
                    NSAnimationContext.runAnimationGroup({ context in
                        context.duration = 0.2
                        vScroller.animator().alphaValue = 0.0
                    }, completionHandler: {
                        Task { @MainActor in
                            vScroller.isHidden = true
                        }
                    })
                }
            }
        }
    }
}

/// Smart autohiding AppKit NSScrollView configurator.
public struct ConfigureNSScrollView: NSViewRepresentable {
    public init() {}
    
    public func makeNSView(context: Context) -> SmartScrollerConfiguratorView {
        return SmartScrollerConfiguratorView()
    }
    
    public func updateNSView(_ nsView: SmartScrollerConfiguratorView, context: Context) {
        nsView.configureEnclosingScrollView()
    }
}

@MainActor
public final class SmartScrollerConfiguratorView: NSView {
    private var hideTimer: Timer?
    private var boundsObserver: (any NSObjectProtocol)?
    private var liveScrollWillStartObserver: (any NSObjectProtocol)?
    private var liveScrollDidEndObserver: (any NSObjectProtocol)?
    
    private func findTargetScrollView() -> NSScrollView? {
        if let scrollView = enclosingScrollView {
            return scrollView
        }
        var current: NSView? = self
        for _ in 0..<6 {
            guard let parent = current?.superview else { break }
            if let sv = parent as? NSScrollView { return sv }
            for sub in parent.subviews {
                if let sv = sub as? NSScrollView { return sv }
                if let sv = sub.subviews.first(where: { $0 is NSScrollView }) as? NSScrollView { return sv }
            }
            current = parent
        }
        return nil
    }
    
    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureEnclosingScrollView()
        setupObservers()
    }
    
    public func configureEnclosingScrollView() {
        guard let scrollView = findTargetScrollView() else { return }
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true
        
        if window != nil {
            setupObservers()
        } else {
            removeObservers()
        }
    }
    
    private func removeObservers() {
        if let b = boundsObserver { NotificationCenter.default.removeObserver(b) }
        if let w = liveScrollWillStartObserver { NotificationCenter.default.removeObserver(w) }
        if let d = liveScrollDidEndObserver { NotificationCenter.default.removeObserver(d) }
        boundsObserver = nil
        liveScrollWillStartObserver = nil
        liveScrollDidEndObserver = nil
        hideTimer?.invalidate()
        hideTimer = nil
    }
    
    private func setupObservers() {
        removeObservers()
        guard let scrollView = findTargetScrollView() else { return }
        let clipView = scrollView.contentView
        clipView.postsBoundsChangedNotifications = true
        
        let center = NotificationCenter.default
        boundsObserver = center.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: clipView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleScrollEvent()
            }
        }
        
        liveScrollWillStartObserver = center.addObserver(
            forName: NSScrollView.willStartLiveScrollNotification,
            object: scrollView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleScrollEvent()
            }
        }
        
        liveScrollDidEndObserver = center.addObserver(
            forName: NSScrollView.didEndLiveScrollNotification,
            object: scrollView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleHide()
            }
        }
    }
    
    @MainActor
    private func handleScrollEvent() {
        guard let scrollView = findTargetScrollView() else { return }
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true
        
        hideTimer?.invalidate()
        hideTimer = nil
        
        if let vScroller = scrollView.verticalScroller {
            vScroller.scrollerStyle = .overlay
            vScroller.isHidden = false
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                vScroller.animator().alphaValue = 1.0
            }
        }
        
        scheduleHide()
    }
    
    @MainActor
    private func scheduleHide() {
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let scrollView = self.findTargetScrollView() else { return }
                if let vScroller = scrollView.verticalScroller {
                    NSAnimationContext.runAnimationGroup({ context in
                        context.duration = 0.25
                        vScroller.animator().alphaValue = 0.0
                    }, completionHandler: {
                        Task { @MainActor in
                            vScroller.isHidden = true
                        }
                    })
                }
            }
        }
    }
    
    public override func removeFromSuperview() {
        cleanup()
        super.removeFromSuperview()
    }
    
    private func cleanup() {
        if let b = boundsObserver { NotificationCenter.default.removeObserver(b) }
        if let w = liveScrollWillStartObserver { NotificationCenter.default.removeObserver(w) }
        if let d = liveScrollDidEndObserver { NotificationCenter.default.removeObserver(d) }
        boundsObserver = nil
        liveScrollWillStartObserver = nil
        liveScrollDidEndObserver = nil
        hideTimer?.invalidate()
        hideTimer = nil
    }
}
