// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import TTZipCore
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, @unchecked Sendable {
    private var pendingURLs: [URL] = []
    private var openURLHandler: (@Sendable (URL) -> Void)?
    private let lock = NSLock()
    
    override init() {
        super.init()
    }
    
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        for filename in filenames {
            let url = URL(fileURLWithPath: filename)
            handleOpenedURL(url)
        }
    }
    
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        let url = URL(fileURLWithPath: filename)
        handleOpenedURL(url)
        return true
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        TempDirectoryCleanUpManager.shared.cleanupAllTemporaryDirectories()
    }
    
    func registerHandler(_ handler: @escaping @Sendable (URL) -> Void) {
        lock.withLock {
            self.openURLHandler = handler
            let urlsToProcess = self.pendingURLs
            self.pendingURLs.removeAll()
            if !urlsToProcess.isEmpty {
                DispatchQueue.main.async {
                    for url in urlsToProcess {
                        handler(url)
                    }
                }
            }
        }
    }
    
    private func handleOpenedURL(_ url: URL) {
        lock.withLock {
            if let handler = openURLHandler {
                DispatchQueue.main.async {
                    handler(url)
                }
            } else {
                pendingURLs.append(url)
            }
        }
    }
}

struct TTZipApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        TTZipEngineFacade.initializeSubsystems()
        
        TempDirectoryCleanUpManager.shared.cleanupAllTemporaryDirectories()
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        
        let possiblePaths = [
            Bundle.main.path(forResource: "TTZip_AppIcon_1024x1024_padded", ofType: "png"),
            Bundle.main.path(forResource: "AppIcon", ofType: "png"),
            Bundle.main.resourcePath.map { ($0 as NSString).appendingPathComponent("TTZip_AppIcon_1024x1024_padded.png") }
        ].compactMap { $0 }
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path), let iconImage = NSImage(contentsOfFile: path) {
                NSApplication.shared.applicationIconImage = iconImage
                break
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 460, minHeight: 380)
                .background(Color.clear)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        
        Settings {
            SettingsView()
                .frame(width: 540, height: 420)
        }
        .commands {
            CommandGroup(after: .appInfo) {
                #if !MAS_BUILD
                Button("Check for Updates...") {
                    UpdateManager.shared.checkForUpdates()
                }
                #endif
            }
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        if url.scheme == "ttzip" {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
            let actionType = components.queryItems?.first(where: { $0.name == "type" })?.value ?? ""
            let pathsStr = components.queryItems?.first(where: { $0.name == "paths" })?.value ?? ""
            let paths = pathsStr.components(separatedBy: "|").filter { !$0.isEmpty }
            guard !paths.isEmpty else { return }
            
            Task { @MainActor in
                switch actionType {
                case "extract_here":
                    for path in paths {
                        let parent = (path as NSString).deletingLastPathComponent
                        _ = try? await TTZipEngineFacade.shared.quickExtract(archivePath: path, destinationDir: parent)
                    }
                case "extract_to_subfolder":
                    for path in paths {
                        let name = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
                        let parent = (path as NSString).deletingLastPathComponent
                        let dest = (parent as NSString).appendingPathComponent(name)
                        _ = try? await TTZipEngineFacade.shared.quickExtract(archivePath: path, destinationDir: dest)
                    }
                case "compress_zip":
                    if let first = paths.first {
                        let outPath = first + ".zip"
                        _ = try? await TTZipEngineFacade.shared.quickCompress(inputs: paths, outputPath: outPath, format: .zip)
                    }
                default:
                    break
                }
            }
        }
    }
}
