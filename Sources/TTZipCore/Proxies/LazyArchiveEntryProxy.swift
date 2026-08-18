// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Virtual proxy encapsulating lazy-loading semantics for heavy entry attributes (Virtual Proxy Pattern).
///
/// Keeps entry scanning lightweight by resolving POSIX attributes, thumbnails, and cryptographic hashes only on demand.
public final class LazyArchiveEntryProxy: Identifiable, @unchecked Sendable, Equatable {
    public var id: String { entry.path }
    public let entry: ArchiveEntry
    
    private let lock = NSLock()
    
    private var _posixAttributes: [FileAttributeKey: Any]?
    private var _posixPermissions: UInt16?
    private var _mediaMetadata: [String: String]?
    private var _thumbnailData: Data?
    private var _sha256Hash: String?
    
    public private(set) var posixLoadCount: Int = 0
    public private(set) var mediaMetadataLoadCount: Int = 0
    public private(set) var thumbnailLoadCount: Int = 0
    public private(set) var hashLoadCount: Int = 0
    
    private var posixProvider: (@Sendable () -> [FileAttributeKey: Any])?
    private var mediaMetadataProvider: (@Sendable () -> [String: String])?
    private var thumbnailProvider: (@Sendable () -> Data?)?
    private var hashProvider: (@Sendable () -> String)?
    
    public init(
        entry: ArchiveEntry,
        posixProvider: (@Sendable () -> [FileAttributeKey: Any])? = nil,
        mediaMetadataProvider: (@Sendable () -> [String: String])? = nil,
        thumbnailProvider: (@Sendable () -> Data?)? = nil,
        hashProvider: (@Sendable () -> String)? = nil
    ) {
        self.entry = entry
        self.posixProvider = posixProvider
        self.mediaMetadataProvider = mediaMetadataProvider
        self.thumbnailProvider = thumbnailProvider
        self.hashProvider = hashProvider
    }
    
    // MARK: - Passthrough Attributes (Zero-Cost Access)
    
    public var path: String { entry.path }
    public var name: String { entry.name }
    public var uncompressedSize: Int64 { entry.uncompressedSize }
    public var isDirectory: Bool { entry.isDirectory }
    public var detectedEncoding: String { entry.detectedEncoding }
    public var modificationDate: Date? { entry.modificationDate }
    public var extensionName: String { entry.extensionName }
    public var mimeType: String { entry.mimeType }
    public var formattedSize: String { entry.formattedSize }
    
    // MARK: - Lazy Loaded Virtual Proxy Attributes
    
    public var isPosixLoaded: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _posixAttributes != nil
    }
    
    public var posixAttributes: [FileAttributeKey: Any] {
        lock.lock()
        defer { lock.unlock() }
        if let attributes = _posixAttributes {
            return attributes
        }
        let loaded = posixProvider?() ?? [:]
        _posixAttributes = loaded
        posixProvider = nil
        posixLoadCount += 1
        return loaded
    }
    
    public var posixPermissions: UInt16 {
        lock.lock()
        defer { lock.unlock() }
        if let perms = _posixPermissions {
            return perms
        }
        if _posixAttributes == nil {
            let loaded = posixProvider?() ?? [:]
            _posixAttributes = loaded
            posixProvider = nil
            posixLoadCount += 1
        }
        let attrs = _posixAttributes ?? [:]
        let perms = (attrs[.posixPermissions] as? NSNumber)?.uint16Value ?? (isDirectory ? 0o755 : 0o644)
        _posixPermissions = perms
        return perms
    }
    
    public var isMediaMetadataLoaded: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _mediaMetadata != nil
    }
    
    public var mediaMetadata: [String: String] {
        lock.lock()
        defer { lock.unlock() }
        if let metadata = _mediaMetadata {
            return metadata
        }
        let loaded = mediaMetadataProvider?() ?? [:]
        _mediaMetadata = loaded
        mediaMetadataProvider = nil
        mediaMetadataLoadCount += 1
        return loaded
    }
    
    public var isThumbnailLoaded: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _thumbnailData != nil
    }
    
    public var thumbnailData: Data? {
        lock.lock()
        defer { lock.unlock() }
        if let thumb = _thumbnailData {
            return thumb
        }
        let loaded = thumbnailProvider?()
        _thumbnailData = loaded
        thumbnailProvider = nil
        thumbnailLoadCount += 1
        return loaded
    }
    
    public var isHashLoaded: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _sha256Hash != nil
    }
    
    public var sha256Hash: String {
        lock.lock()
        defer { lock.unlock() }
        if let hash = _sha256Hash {
            return hash
        }
        let loaded = hashProvider?() ?? ""
        _sha256Hash = loaded
        hashProvider = nil
        hashLoadCount += 1
        return loaded
    }
    
    // MARK: - Factory & Conversion Helpers
    
    /// Factory creating lazy proxy bound to physical file resolvers.
    public static func create(for entry: ArchiveEntry, diskPath: String? = nil) -> LazyArchiveEntryProxy {
        guard let path = diskPath, FileManager.default.fileExists(atPath: path) else {
            return LazyArchiveEntryProxy(entry: entry)
        }
        
        let posixResolver: @Sendable () -> [FileAttributeKey: Any] = {
            return (try? FileManager.default.attributesOfItem(atPath: path)) ?? [:]
        }
        
        let metadataResolver: @Sendable () -> [String: String] = {
            var meta: [String: String] = [:]
            meta["DiskPath"] = path
            meta["MimeType"] = entry.mimeType
            meta["Extension"] = entry.extensionName
            return meta
        }
        
        let thumbnailResolver: @Sendable () -> Data? = {
            if ["png", "jpg", "jpeg", "gif", "txt", "json", "xml", "md"].contains(entry.extensionName.lowercased()) {
                return try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
            }
            return nil
        }
        
        return LazyArchiveEntryProxy(
            entry: entry,
            posixProvider: posixResolver,
            mediaMetadataProvider: metadataResolver,
            thumbnailProvider: thumbnailResolver
        )
    }
    
    public static func == (lhs: LazyArchiveEntryProxy, rhs: LazyArchiveEntryProxy) -> Bool {
        return lhs.entry == rhs.entry
    }
}
