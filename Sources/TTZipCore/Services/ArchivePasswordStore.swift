// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Process-level thread-safe archive password LRU cache with secure memory erasure.
public final class ArchivePasswordStore: @unchecked Sendable {
    public static let shared = ArchivePasswordStore()
    private let lock = NSLock()
    private var passwords: [String: String] = [:]
    private var lruOrder: [String] = []
    public let maxCapacity: Int
    
    private convenience init() {
        self.init(maxCapacity: 128)
    }
    
    internal init(maxCapacity: Int = 128) {
        self.maxCapacity = maxCapacity
    }
    
    private func normalize(_ path: String) -> String {
        if let u = URL(string: path), u.scheme != nil {
            return u.path
        }
        return URL(fileURLWithPath: path).path
    }
    
    public func getPassword(for path: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        let normPath = normalize(path)
        guard let pwd = passwords[normPath] else { return nil }
        
        if let idx = lruOrder.firstIndex(of: normPath) {
            lruOrder.remove(at: idx)
        }
        lruOrder.append(normPath)
        return pwd
    }
    
    public func setPassword(_ pwd: String, for path: String) {
        lock.lock()
        defer { lock.unlock() }
        let normPath = normalize(path)
        
        if passwords[normPath] != nil {
            var old = passwords[normPath] ?? ""
            eraseSensitiveString(&old)
            if let idx = lruOrder.firstIndex(of: normPath) {
                lruOrder.remove(at: idx)
            }
        }
        
        while passwords.count >= maxCapacity, !lruOrder.isEmpty {
            let oldestKey = lruOrder.removeFirst()
            if var evictedPwd = passwords.removeValue(forKey: oldestKey) {
                eraseSensitiveString(&evictedPwd)
            }
        }
        
        passwords[normPath] = pwd
        lruOrder.append(normPath)
    }
    
    public func removePassword(for path: String) {
        lock.lock()
        defer { lock.unlock() }
        let normPath = normalize(path)
        if var pwd = passwords.removeValue(forKey: normPath) {
            eraseSensitiveString(&pwd)
        }
        if let idx = lruOrder.firstIndex(of: normPath) {
            lruOrder.remove(at: idx)
        }
    }
    
    public func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        for key in passwords.keys {
            if var pwd = passwords[key] {
                eraseSensitiveString(&pwd)
            }
        }
        passwords.removeAll()
        lruOrder.removeAll()
    }
    
    private func eraseSensitiveString(_ str: inout String) {
        str.withUTF8 { buffer in
            if let base = buffer.baseAddress, buffer.count > 0 {
                let raw = UnsafeMutableRawPointer(mutating: base)
                PlatformMemory.secureZero(pointer: raw, byteCount: buffer.count)
            }
        }
        str = ""
    }
}
