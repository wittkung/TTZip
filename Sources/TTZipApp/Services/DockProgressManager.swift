// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import AppKit
import SwiftUI
import TTZipCore

/// Dynamic macOS Dock Tile progress ring and badge orchestrator.
///
/// Draws a smooth circular progress indicator over the TTZip app icon with 30~60Hz throttling
/// without causing main-thread stuttering during high-speed compression tasks.
@MainActor
public final class DockProgressManager: NSObject {
    public static let shared = DockProgressManager()
    
    private var lastRenderTime: CFAbsoluteTime = 0
    private let minRenderInterval: CFAbsoluteTime = 1.0 / 30.0 // 30Hz throttle
    private var currentFraction: Double = 0.0
    private var activeTasksCount: Int = 0
    
    private override init() {
        super.init()
    }
    
    /// Updates Dock progress and badge label.
    public func updateProgress(fraction: Double, activeCount: Int) {
        self.currentFraction = max(0.0, min(1.0, fraction))
        self.activeTasksCount = activeCount
        
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastRenderTime >= minRenderInterval || fraction >= 1.0 || activeCount == 0 else {
            return
        }
        lastRenderTime = now
        renderDockTile()
    }
    
    /// Clears Dock progress and resets icon to default.
    public func clearProgress() {
        self.currentFraction = 0.0
        self.activeTasksCount = 0
        let dockTile = NSApp.dockTile
        dockTile.contentView = nil
        dockTile.badgeLabel = nil
        dockTile.display()
    }
    
    private func renderDockTile() {
        let dockTile = NSApp.dockTile
        
        if activeTasksCount == 0 {
            dockTile.contentView = nil
            dockTile.badgeLabel = nil
            dockTile.display()
            return
        }
        
        dockTile.badgeLabel = "\(activeTasksCount)"
        
        let tileView = DockProgressTileView(fraction: currentFraction)
        tileView.frame = NSRect(x: 0, y: 0, width: dockTile.size.width, height: dockTile.size.height)
        dockTile.contentView = tileView
        dockTile.display()
    }
}

// MARK: - Custom Dock Tile View

private final class DockProgressTileView: NSView {
    private let fraction: Double
    
    init(fraction: Double) {
        self.fraction = fraction
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        self.fraction = 0.0
        super.init(coder: coder)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Draw app icon base
        if let appIcon = NSApp.applicationIconImage {
            appIcon.draw(in: bounds)
        }
        
        guard fraction > 0.0 else { return }
        
        // Draw circular progress ring
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) * 0.38
        let lineWidth: CGFloat = max(4.0, bounds.width * 0.06)
        
        let trackPath = NSBezierPath()
        trackPath.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
        NSColor.black.withAlphaComponent(0.4).setStroke()
        trackPath.lineWidth = lineWidth
        trackPath.stroke()
        
        let progressPath = NSBezierPath()
        let startAngle: CGFloat = 90.0
        let endAngle: CGFloat = 90.0 - CGFloat(fraction * 360.0)
        progressPath.appendArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        
        NSColor.systemBlue.setStroke()
        progressPath.lineWidth = lineWidth
        progressPath.lineCapStyle = .round
        progressPath.stroke()
    }
}
