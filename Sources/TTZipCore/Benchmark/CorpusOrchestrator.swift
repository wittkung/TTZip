// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// 语料实体描述
public struct CorpusItem: Sendable {
    public let id: String
    public let name: String
    public let tier: BenchmarkTierCategory
    public let path: String
    public let sizeBytes: Int64
    public let isDirectory: Bool
    
    public init(id: String, name: String, tier: BenchmarkTierCategory, path: String, sizeBytes: Int64, isDirectory: Bool = false) {
        self.id = id
        self.name = name
        self.tier = tier
        self.path = path
        self.sizeBytes = sizeBytes
        self.isDirectory = isDirectory
    }
}

/// 5-Tier 科学多模态真实语料库编排与零拷贝只读调度中枢
public final class CorpusOrchestrator: @unchecked Sendable {
    
    public static let shared = CorpusOrchestrator()
    
    private let lock = NSLock()
    private var cachedItems: [BenchmarkTierCategory: [CorpusItem]] = [:]
    private var mmapHandles: [String: (ptr: UnsafeRawPointer, size: size_t, fd: Int32)] = [:]
    
    public init() {}
    
    deinit {
        lock.lock()
        defer { lock.unlock() }
        for (_, val) in mmapHandles {
            munmap(UnsafeMutableRawPointer(mutating: val.ptr), val.size)
            close(val.fd)
        }
        mmapHandles.removeAll()
    }
    
    // MARK: - 1. 自适应三级发现 (Discovery)
    
    /// 获取指定 Tier 下的所有真实语料项
    public func items(for tier: BenchmarkTierCategory) -> [CorpusItem] {
        lock.lock()
        if let existing = cachedItems[tier], !existing.isEmpty {
            lock.unlock()
            return existing
        }
        lock.unlock()
        
        let discovered = discoverItems(for: tier)
        lock.lock()
        cachedItems[tier] = discovered
        lock.unlock()
        return discovered
    }
    
    /// 获取全部 5 大 Tier 语料项集合
    public func allItems() -> [BenchmarkTierCategory: [CorpusItem]] {
        var result: [BenchmarkTierCategory: [CorpusItem]] = [:]
        for tier in BenchmarkTierCategory.allCases {
            result[tier] = items(for: tier)
        }
        return result
    }
    
    // MARK: - 2. 内存映射与热路径零分配 (Zero-Copy mmap)
    
    /// 为单文件语料建立/复用全局只读 POSIX mmap 缓冲区
    public func withMappedBuffer<R>(for item: CorpusItem, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
        guard !item.isDirectory else {
            throw NSError(domain: "CorpusOrchestrator", code: 400, userInfo: [NSLocalizedDescriptionKey: "Cannot mmap directory tree: \(item.path)"])
        }
        
        lock.lock()
        if let entry = mmapHandles[item.path] {
            lock.unlock()
            let rawBuf = UnsafeRawBufferPointer(start: entry.ptr, count: entry.size)
            return try body(rawBuf)
        }
        
        let fd = open(item.path, O_RDONLY)
        guard fd >= 0 else {
            lock.unlock()
            throw NSError(domain: "CorpusOrchestrator", code: 404, userInfo: [NSLocalizedDescriptionKey: "Failed to open corpus file at \(item.path)"])
        }
        
        var st = stat()
        if fstat(fd, &st) != 0 || st.st_size <= 0 {
            close(fd)
            lock.unlock()
            throw NSError(domain: "CorpusOrchestrator", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid file size for \(item.path)"])
        }
        
        let size = size_t(st.st_size)
        guard let mapped = mmap(nil, size, PROT_READ, MAP_SHARED, fd, 0), mapped != MAP_FAILED else {
            close(fd)
            lock.unlock()
            throw NSError(domain: "CorpusOrchestrator", code: 500, userInfo: [NSLocalizedDescriptionKey: "mmap failed for \(item.path)"])
        }
        
        // 显式通知内核顺序预取
        madvise(mapped, size, MADV_WILLNEED | MADV_SEQUENTIAL)
        
        let rawPtr = UnsafeRawPointer(mapped)
        mmapHandles[item.path] = (ptr: rawPtr, size: size, fd: fd)
        lock.unlock()
        
        let rawBuf = UnsafeRawBufferPointer(start: rawPtr, count: size)
        return try body(rawBuf)
    }
    
    // MARK: - 3. 内部发现算法
    
    private func discoverItems(for tier: BenchmarkTierCategory) -> [CorpusItem] {
        let silesiaRoot = resolveSilesiaDirectory()
        let enwik8Path = resolveEnwik8Path()
        
        var items: [CorpusItem] = []
        
        switch tier {
        case .tier1Text:
            if let enwik = enwik8Path, FileManager.default.fileExists(atPath: enwik) {
                let size = (try? FileManager.default.attributesOfItem(atPath: enwik)[.size] as? Int64) ?? 100_000_000
                items.append(CorpusItem(id: "enwik8", name: "enwik8 (Wikipedia 100MB)", tier: tier, path: enwik, sizeBytes: size))
            }
            if let root = silesiaRoot {
                for name in ["webster", "dickens", "reymont"] {
                    let p = (root as NSString).appendingPathComponent(name)
                    if FileManager.default.fileExists(atPath: p) {
                        let sz = (try? FileManager.default.attributesOfItem(atPath: p)[.size] as? Int64) ?? 0
                        items.append(CorpusItem(id: "silesia_\(name)", name: "Silesia \(name)", tier: tier, path: p, sizeBytes: sz))
                    }
                }
            }
            
        case .tier2Binary:
            if let root = silesiaRoot {
                for name in ["mozilla", "ooffice"] {
                    let p = (root as NSString).appendingPathComponent(name)
                    if FileManager.default.fileExists(atPath: p) {
                        let sz = (try? FileManager.default.attributesOfItem(atPath: p)[.size] as? Int64) ?? 0
                        items.append(CorpusItem(id: "silesia_\(name)", name: "Silesia \(name)", tier: tier, path: p, sizeBytes: sz))
                    }
                }
            }
            
        case .tier3Structured:
            if let root = silesiaRoot {
                for name in ["nci", "osdb", "xml"] {
                    let p = (root as NSString).appendingPathComponent(name)
                    if FileManager.default.fileExists(atPath: p) {
                        let sz = (try? FileManager.default.attributesOfItem(atPath: p)[.size] as? Int64) ?? 0
                        items.append(CorpusItem(id: "silesia_\(name)", name: "Silesia \(name)", tier: tier, path: p, sizeBytes: sz))
                    }
                }
            }
            
        case .tier4SourceTree:
            if let root = silesiaRoot {
                let sambaPath = (root as NSString).appendingPathComponent("samba")
                if FileManager.default.fileExists(atPath: sambaPath) {
                    let sz = (try? FileManager.default.attributesOfItem(atPath: sambaPath)[.size] as? Int64) ?? 0
                    items.append(CorpusItem(id: "silesia_samba", name: "Silesia samba (Source Tree Tar)", tier: tier, path: sambaPath, sizeBytes: sz))
                }
            }
            
        case .tier5DenseMatrix:
            if let root = silesiaRoot {
                for name in ["mr", "x-ray", "sao"] {
                    let p = (root as NSString).appendingPathComponent(name)
                    if FileManager.default.fileExists(atPath: p) {
                        let sz = (try? FileManager.default.attributesOfItem(atPath: p)[.size] as? Int64) ?? 0
                        items.append(CorpusItem(id: "silesia_\(name)", name: "Silesia \(name)", tier: tier, path: p, sizeBytes: sz))
                    }
                }
            }
        }
        
        return items
    }
    
    private func resolveSilesiaDirectory() -> String? {
        if let env = ProcessInfo.processInfo.environment["TTZIP_SILESIA_PATH"], FileManager.default.fileExists(atPath: env) {
            return env
        }
        if let envRoot = ProcessInfo.processInfo.environment["TTZIP_CORPUS_ROOT"] {
            let p = (envRoot as NSString).appendingPathComponent("Silesia")
            if FileManager.default.fileExists(atPath: p) { return p }
        }
        
        // 查找既有 SPM 资源路径
        let currentFilePath = #filePath
        let testsDir = ((currentFilePath as NSString).deletingLastPathComponent as NSString).deletingLastPathComponent
        let fixturesSilesia = ((testsDir as NSString).appendingPathComponent("TTZipTests/Fixtures/Silesia") as NSString).standardizingPath
        if FileManager.default.fileExists(atPath: fixturesSilesia) {
            return fixturesSilesia
        }
        
        let localDev = "/Users/kevintung/Documents/dev/TTZip/Tests/TTZipTests/Fixtures/Silesia"
        if FileManager.default.fileExists(atPath: localDev) {
            return localDev
        }
        return nil
    }
    
    private func resolveEnwik8Path() -> String? {
        if let env = ProcessInfo.processInfo.environment["TTZIP_ENWIK8_PATH"], FileManager.default.fileExists(atPath: env) {
            return env
        }
        let cachePath = "/Users/kevintung/Library/Caches/com.ttzip.tests/fixtures/enwik8.xml"
        if FileManager.default.fileExists(atPath: cachePath) {
            return cachePath
        }
        return nil
    }
}
