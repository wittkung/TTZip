// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// In-archive live file editing and filesystem change observer engine.
public final class FileWatcherEngine: @unchecked Sendable {
    public static let shared = FileWatcherEngine()
    
    private var activeSources: [String: DispatchSourceFileSystemObject] = [:]
    private let lock = NSLock()
    
    private init() {}
    
    /// Watches an extracted temporary file for filesystem change events (`.write`, `.extend`, `.attrib`, `.rename`).
    public func watchFileForChanges(
        filePath: String,
        targetArchivePath: String,
        onFileModified: @escaping @Sendable (String, String) -> Void
    ) {
        lock.lock()
        defer { lock.unlock() }
        
        let fd = open(filePath, O_EVTONLY)
        guard fd >= 0 else { return }
        
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .attrib, .rename],
            queue: DispatchQueue.global(qos: .default)
        )
        
        source.setEventHandler { [weak self] in
            onFileModified(filePath, targetArchivePath)
            self?.stopWatching(filePath: filePath)
        }
        
        source.setCancelHandler {
            close(fd)
        }
        
        activeSources[filePath] = source
        source.resume()
    }
    
    /// Stops watching a specific file path.
    public func stopWatching(filePath: String) {
        lock.lock()
        defer { lock.unlock() }
        
        if let source = activeSources.removeValue(forKey: filePath) {
            source.cancel()
        }
    }
    
    /// Cancels all active dispatch sources and closes file descriptors.
    public func stopAllWatching() {
        lock.lock()
        let sources = Array(activeSources.values)
        activeSources.removeAll()
        lock.unlock()
        
        for source in sources {
            source.cancel()
        }
    }
    
    /// Resets watcher engine state.
    public func reset() {
        stopAllWatching()
    }
}
