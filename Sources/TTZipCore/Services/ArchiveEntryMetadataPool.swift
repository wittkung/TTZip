// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import os

/// Shared intrinsic string and metadata interning pool for archive entries.
///
/// Reduces memory footprint when browsing massive archives by canonicalizing shared path prefixes, extensions,
/// and MIME types.
public final class ArchiveEntryMetadataPool: @unchecked Sendable {
    public static let shared = ArchiveEntryMetadataPool()

    private var unfairLock = os_unfair_lock_s()

    private var pathPool: [String: String] = [:]
    private var extensionPool: [String: String] = [:]
    private var mimeTypePool: [String: String] = [:]
    private var directoryPrefixPool: [String: String] = [:]

    private static let predefinedMimeTypes: [String: String] = [
        "swift": "text/x-swift",
        "js": "application/javascript",
        "json": "application/json",
        "html": "text/html",
        "css": "text/css",
        "png": "image/png",
        "jpg": "image/jpeg",
        "jpeg": "image/jpeg",
        "gif": "image/gif",
        "svg": "image/svg+xml",
        "pdf": "application/pdf",
        "zip": "application/zip",
        "7z": "application/x-7z-compressed",
        "tar": "application/x-tar",
        "gz": "application/gzip",
        "zst": "application/zstd",
        "txt": "text/plain",
        "md": "text/markdown",
        "c": "text/x-c",
        "cpp": "text/x-c++",
        "h": "text/x-chdr",
        "py": "text/x-python",
        "rs": "text/x-rust",
        "go": "text/x-go",
        "xml": "application/xml",
        "mp3": "audio/mpeg",
        "mp4": "video/mp4",
        "mov": "video/quicktime"
    ]

    public var maxPathPoolCapacity: Int = 50_000

    private init() {
        for (ext, mime) in Self.predefinedMimeTypes {
            extensionPool[ext] = ext
            mimeTypePool[mime] = mime
        }
        setupMemoryPressureObserver()
    }

    private func setupMemoryPressureObserver() {
        #if canImport(AppKit)
        _ = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NSApplicationWillTerminateNotification"),
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.clearPool()
        }
        #endif

        #if os(macOS) || os(iOS)
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .global(qos: .utility))
        source.setEventHandler { [weak self] in
            self?.clearPool()
        }
        source.resume()
        #endif
    }

    // MARK: - Interning API

    public func internPath(_ path: String) -> String {
        guard !path.isEmpty else { return "" }
        os_unfair_lock_lock(&unfairLock)
        defer { os_unfair_lock_unlock(&unfairLock) }
        if let existing = pathPool[path] {
            return existing
        }
        if pathPool.count >= maxPathPoolCapacity {
            pathPool.removeAll(keepingCapacity: false)
        }
        pathPool[path] = path
        return path
    }

    public func internExtension(_ ext: String) -> String {
        let lowerExt = ext.lowercased()
        guard !lowerExt.isEmpty else { return "" }
        os_unfair_lock_lock(&unfairLock)
        defer { os_unfair_lock_unlock(&unfairLock) }
        if let existing = extensionPool[lowerExt] {
            return existing
        }
        extensionPool[lowerExt] = lowerExt
        return lowerExt
    }

    public func internMimeType(_ mime: String) -> String {
        guard !mime.isEmpty else { return "application/octet-stream" }
        os_unfair_lock_lock(&unfairLock)
        defer { os_unfair_lock_unlock(&unfairLock) }
        if let existing = mimeTypePool[mime] {
            return existing
        }
        mimeTypePool[mime] = mime
        return mime
    }

    public func internDirectoryPrefix(_ prefix: String) -> String {
        guard !prefix.isEmpty else { return "" }
        os_unfair_lock_lock(&unfairLock)
        defer { os_unfair_lock_unlock(&unfairLock) }
        if let existing = directoryPrefixPool[prefix] {
            return existing
        }
        directoryPrefixPool[prefix] = prefix
        return prefix
    }

    public func detectMimeType(forPath path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        if let mime = Self.predefinedMimeTypes[ext] {
            return internMimeType(mime)
        }
        return internMimeType("application/octet-stream")
    }

    public func extractAndInternDirectoryPrefix(fromPath path: String) -> String {
        let nsPath = path as NSString
        let dir = nsPath.deletingLastPathComponent
        guard !dir.isEmpty && dir != "." else { return "" }
        let prefix = dir.hasSuffix("/") ? dir : "\(dir)/"
        return internDirectoryPrefix(prefix)
    }

    public func clearPool() {
        clearPools()
    }

    public func clearPools() {
        os_unfair_lock_lock(&unfairLock)
        defer { os_unfair_lock_unlock(&unfairLock) }
        pathPool.removeAll(keepingCapacity: false)
        extensionPool.removeAll(keepingCapacity: false)
        mimeTypePool.removeAll(keepingCapacity: false)
        directoryPrefixPool.removeAll(keepingCapacity: false)

        for (ext, mime) in Self.predefinedMimeTypes {
            extensionPool[ext] = ext
            mimeTypePool[mime] = mime
        }
    }

    public var poolCounts: (paths: Int, extensions: Int, mimeTypes: Int, prefixes: Int) {
        os_unfair_lock_lock(&unfairLock)
        defer { os_unfair_lock_unlock(&unfairLock) }
        return (pathPool.count, extensionPool.count, mimeTypePool.count, directoryPrefixPool.count)
    }
}

public typealias ArchiveEntryFlyweightFactory = ArchiveEntryMetadataPool

public struct ArchiveEntryMetadataState: Sendable, Equatable {
    public let path: String
    public let extensionName: String
    public let mimeType: String
    public let directoryPrefix: String

    public init(path: String) {
        let pool = ArchiveEntryMetadataPool.shared
        self.path = pool.internPath(path)
        let ext = (path as NSString).pathExtension
        self.extensionName = pool.internExtension(ext)
        self.mimeType = pool.detectMimeType(forPath: path)
        self.directoryPrefix = pool.extractAndInternDirectoryPrefix(fromPath: path)
    }
}

public typealias ArchiveEntryFlyweightState = ArchiveEntryMetadataState
