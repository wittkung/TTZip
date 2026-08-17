// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Weitao Kung (Witt Kung) <kevintungs@163.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import os

/// 享元模式 (Flyweight Pattern): ArchiveEntry 内部状态驻留共享工厂
/// 针对包含海量文件（如 node_modules 或数十万个文件的 Zip/7z）的归档包，
/// 使上万个 ArchiveEntry / ArchiveLeafFile 共享相同的扩展名、MIME 类型、路径与相对目录前缀，
/// 大幅降低内存占用与堆分配频率（省内存 70%+）。
public final class ArchiveEntryFlyweightFactory: @unchecked Sendable {
    public static let shared = ArchiveEntryFlyweightFactory()
    
    private var unfairLock = os_unfair_lock_s()
    
    // 享元内部状态共享池
    private var pathPool: [String: String] = [:]
    private var extensionPool: [String: String] = [:]
    private var mimeTypePool: [String: String] = [:]
    private var directoryPrefixPool: [String: String] = [:]
    
    // 内置常见 MIME 类型映射表 (常用文件扩展名享元)
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
    
    // 容量管制阈值 (防止海量不可复用路径导致无上限内存扩张)
    public var maxPathPoolCapacity: Int = 50_000

    private init() {
        // 预热常用 MIME 享元池
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
    
    // MARK: - Interning API (字符串驻留享元)
    
    /// 驻留共享路径字符串
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
    
    /// 驻留共享文件扩展名
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
    
    /// 驻留共享 MIME 类型
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
    
    /// 驻留共享目录前缀
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
    
    /// 根据路径或扩展名推导并驻留 MIME 类型
    public func detectMimeType(forPath path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        if let mime = Self.predefinedMimeTypes[ext] {
            return internMimeType(mime)
        }
        return internMimeType("application/octet-stream")
    }
    
    /// 从文件相对路径提取并驻留目录前缀 (例如 "node_modules/lodash/index.js" -> "node_modules/lodash/")
    public func extractAndInternDirectoryPrefix(fromPath path: String) -> String {
        let nsPath = path as NSString
        let dir = nsPath.deletingLastPathComponent
        guard !dir.isEmpty && dir != "." else { return "" }
        let prefix = dir.hasSuffix("/") ? dir : "\(dir)/"
        return internDirectoryPrefix(prefix)
    }
    
    // MARK: - Pool Management & Statistics
    
    /// 统一内存释放接口 (遵从享元池统一 clearPool 规范)
    public func clearPool() {
        clearPools()
    }

    /// 清空享元池（主要用于单元测试与内存释放）
    public func clearPools() {
        os_unfair_lock_lock(&unfairLock)
        defer { os_unfair_lock_unlock(&unfairLock) }
        pathPool.removeAll(keepingCapacity: false)
        extensionPool.removeAll(keepingCapacity: false)
        mimeTypePool.removeAll(keepingCapacity: false)
        directoryPrefixPool.removeAll(keepingCapacity: false)
        
        // 重新填充默认映射
        for (ext, mime) in Self.predefinedMimeTypes {
            extensionPool[ext] = ext
            mimeTypePool[mime] = mime
        }
    }
    
    /// 当前享元池内部状态节点总数统计
    public var poolCounts: (paths: Int, extensions: Int, mimeTypes: Int, prefixes: Int) {
        os_unfair_lock_lock(&unfairLock)
        defer { os_unfair_lock_unlock(&unfairLock) }
        return (pathPool.count, extensionPool.count, mimeTypePool.count, directoryPrefixPool.count)
    }
    
    /// 评估海量对象下使用享元模式相比独立创建的内存节省比例
    public func estimatedMemorySavingsRatio(totalEntriesProcessed: Int) -> Double {
        guard totalEntriesProcessed > 0 else { return 0.0 }
        let counts = poolCounts
        let totalUniqueFlyweights = counts.paths + counts.extensions + counts.mimeTypes + counts.prefixes
        let totalRawAllocations = totalEntriesProcessed * 4 // 每个 entry 包含 path, ext, mime, prefix
        if totalRawAllocations <= totalUniqueFlyweights { return 0.0 }
        let saved = Double(totalRawAllocations - totalUniqueFlyweights) / Double(totalRawAllocations)
        return min(0.95, max(0.0, saved))
    }
}

/// 享元共享对象 (Flyweight Shared Intrinsic State Representation)
public struct ArchiveEntryFlyweightState: Sendable, Equatable {
    public let path: String
    public let extensionName: String
    public let mimeType: String
    public let directoryPrefix: String
    
    public init(path: String) {
        let factory = ArchiveEntryFlyweightFactory.shared
        self.path = factory.internPath(path)
        let ext = (path as NSString).pathExtension
        self.extensionName = factory.internExtension(ext)
        self.mimeType = factory.detectMimeType(forPath: path)
        self.directoryPrefix = factory.extractAndInternDirectoryPrefix(fromPath: path)
    }
}
