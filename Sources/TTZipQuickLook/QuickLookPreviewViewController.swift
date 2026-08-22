// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Cocoa
import QuickLookUI
import WebKit
import TTZipCore

/// macOS Native QuickLook Previewing View Controller for all 16 supported archive formats.
@objc(QuickLookPreviewViewController)
public final class QuickLookPreviewViewController: NSViewController, @preconcurrency QLPreviewingController, WKNavigationDelegate {
    
    private var webView: WKWebView!
    private var activityIndicator: NSProgressIndicator!
    private var pendingCompletion: ((Error?) -> Void)?
    
    public override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        container.wantsLayer = true
        
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        
        webView = WKWebView(frame: container.bounds, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.navigationDelegate = self
        webView.setValue(false, forKey: "drawsBackground")
        container.addSubview(webView)
        
        activityIndicator = NSProgressIndicator()
        activityIndicator.style = .spinning
        activityIndicator.controlSize = .regular
        activityIndicator.sizeToFit()
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.isDisplayedWhenStopped = false
        container.addSubview(activityIndicator)
        
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        
        self.view = container
    }
    
    // MARK: - QLPreviewingController
    
    public func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        self.pendingCompletion = handler
        activityIndicator.startAnimation(nil)
        
        Task { @MainActor in
            do {
                let html = try await QuickLookPreviewEngine.generateHTMLPreview(for: url.path)
                self.webView.loadHTMLString(html, baseURL: url.deletingLastPathComponent())
            } catch {
                self.activityIndicator.stopAnimation(nil)
                self.renderErrorFallback(error: error, fileURL: url)
                handler(nil)
            }
        }
    }
    
    private func renderErrorFallback(error: Error, fileURL: URL) {
        let isEncrypted = (error as? ArchiveError) == .passwordRequired
        let title = isEncrypted ? "Encrypted Archive" : "Unable to Preview Archive"
        let subtitle = isEncrypted ? "This archive is protected with a password." : error.localizedDescription
        let icon = isEncrypted ? "🔒" : "⚠️"
        
        let errorHTML = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
            :root { color-scheme: light dark; }
            body {
                font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", sans-serif;
                margin: 0; padding: 40px; display: flex; flex-direction: column;
                align-items: center; justify-content: center; height: 100vh;
                background: transparent; color: #1c1c1e;
            }
            @media (prefers-color-scheme: dark) { body { color: #f2f2f7; } }
            .icon { font-size: 64px; margin-bottom: 16px; }
            .title { font-size: 20px; font-weight: 600; margin-bottom: 8px; }
            .subtitle { font-size: 14px; opacity: 0.7; text-align: center; max-width: 400px; line-height: 1.5; }
            .filename { margin-top: 16px; font-family: ui-monospace, monospace; font-size: 12px; opacity: 0.5; }
        </style>
        </head>
        <body>
            <div class="icon">\(icon)</div>
            <div class="title">\(title)</div>
            <div class="subtitle">\(subtitle)</div>
            <div class="filename">\(fileURL.lastPathComponent)</div>
        </body>
        </html>
        """
        self.webView.loadHTMLString(errorHTML, baseURL: nil)
    }
    
    // MARK: - WKNavigationDelegate
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        activityIndicator.stopAnimation(nil)
        if let completion = pendingCompletion {
            pendingCompletion = nil
            completion(nil)
        }
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        activityIndicator.stopAnimation(nil)
        if let completion = pendingCompletion {
            pendingCompletion = nil
            completion(error)
        }
    }
}
