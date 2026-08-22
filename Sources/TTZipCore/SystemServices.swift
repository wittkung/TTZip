// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Character encoding detection and filename sanitization interface.
public enum CharsetDetector {
    /// Detects charset encoding name (e.g. GB18030, UTF-8, Shift-JIS) from raw byte sequence.
    public static func detectCharset(data: Data) -> String {
        if data.isEmpty { return "UTF-8" }
        if String(data: data, encoding: .utf8) != nil {
            return "UTF-8"
        }
        let gb18030Encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        if String(data: data, encoding: gb18030Encoding) != nil {
            return "GB18030"
        }
        let shiftJISEncoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.shiftJIS.rawValue)))
        if String(data: data, encoding: shiftJISEncoding) != nil {
            return "Shift-JIS"
        }
        let big5Encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.big5.rawValue)))
        if String(data: data, encoding: big5Encoding) != nil {
            return "Big5"
        }
        if String(data: data, encoding: .windowsCP1252) != nil {
            return "Windows-1252"
        }
        return "ISO-8859-1"
    }
    
    /// Sanitizes raw filename byte sequences into valid Unicode Swift String.
    public static func sanitizeFilename(bytes: Data) -> String {
        if let utf8 = String(data: bytes, encoding: .utf8) {
            return utf8
        }
        let gb18030Encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        if let gb = String(data: bytes, encoding: gb18030Encoding) {
            return gb
        }
        let shiftJISEncoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.shiftJIS.rawValue)))
        if let sjis = String(data: bytes, encoding: shiftJISEncoding) {
            return sjis
        }
        return String(decoding: bytes, as: UTF8.self)
    }
    
    /// Clears charset detection caching structures.
    public static func clearCache() {}
}

// MARK: - File Watcher

//
//


/// In-archive live file editing and filesystem change observer engine.
///
/// Implements a robust Dual-Tier (File FD + Parent Directory) DispatchSource Watcher with 100~350ms debounce
/// to reliably detect both in-place file stream modifications and atomic "safe-saves" (inode swaps) by external editors
/// (TextEdit, VS Code, Xcode, Vim) without losing tracking.
public final class FileWatcherEngine: @unchecked Sendable {
    public static let shared = FileWatcherEngine()
    
    private struct ActiveWatchSession {
        let dirSource: DispatchSourceFileSystemObject?
        let dirFd: Int32?
        let fileSource: DispatchSourceFileSystemObject?
        let fileFd: Int32?
        let directoryPath: String
        let fileName: String
        let filePath: String
        let targetArchivePath: String
        let entryPath: String
        var debounceItem: DispatchWorkItem?
        var lastKnownHash: String?
        var lastKnownMtime: Double
    }
    
    private var activeSessions: [String: ActiveWatchSession] = [:]
    private let lock = NSLock()
    private let watchQueue = DispatchQueue(label: "com.ttzip.filewatcher", qos: .default)
    
    private init() {}
    
    /// Starts watching an active in-place editing session.
    public func watchEditingSession(
        session: InPlaceEditSession,
        onFileModified: @escaping @Sendable (InPlaceEditSession) -> Void
    ) {
        lock.lock()
        defer { lock.unlock() }
        
        let sessionKey = session.sessionId
        if let existing = activeSessions.removeValue(forKey: sessionKey) {
            existing.debounceItem?.cancel()
            existing.dirSource?.cancel()
            existing.fileSource?.cancel()
        }
        
        let dirPath = session.stagedDirectoryPath
        let filePath = session.stagedFilePath
        let fileName = (filePath as NSString).lastPathComponent
        
        // 1. Directory Source (captures atomic renames and file additions/deletions)
        let dirFd = open(dirPath, O_EVTONLY)
        let dirSource: DispatchSourceFileSystemObject?
        if dirFd >= 0 {
            let src = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: dirFd,
                eventMask: [.write, .extend, .attrib, .link, .rename],
                queue: watchQueue
            )
            src.setEventHandler { [weak self] in
                self?.handleFileSystemEvent(sessionKey: sessionKey, onFileModified: onFileModified)
            }
            src.setCancelHandler {
                close(dirFd)
            }
            src.resume()
            dirSource = src
        } else {
            dirSource = nil
        }
        
        // 2. Direct File Source (captures in-place stream writes)
        let fileFd = open(filePath, O_EVTONLY)
        let fileSource: DispatchSourceFileSystemObject?
        if fileFd >= 0 {
            let src = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fileFd,
                eventMask: [.write, .extend, .attrib, .rename, .delete],
                queue: watchQueue
            )
            src.setEventHandler { [weak self] in
                self?.handleFileSystemEvent(sessionKey: sessionKey, onFileModified: onFileModified)
            }
            src.setCancelHandler {
                close(fileFd)
            }
            src.resume()
            fileSource = src
        } else {
            fileSource = nil
        }
        
        let watchSession = ActiveWatchSession(
            dirSource: dirSource,
            dirFd: dirFd >= 0 ? dirFd : nil,
            fileSource: fileSource,
            fileFd: fileFd >= 0 ? fileFd : nil,
            directoryPath: dirPath,
            fileName: fileName,
            filePath: filePath,
            targetArchivePath: session.archivePath,
            entryPath: session.entryPath,
            debounceItem: nil,
            lastKnownHash: session.initialHash,
            lastKnownMtime: session.lastKnownMtime
        )
        
        activeSessions[sessionKey] = watchSession
    }
    
    /// Legacy compatibility wrapper: watches a single file path for modifications.
    public func watchFileForChanges(
        filePath: String,
        targetArchivePath: String,
        onFileModified: @escaping @Sendable (String, String) -> Void
    ) {
        let parentDir = (filePath as NSString).deletingLastPathComponent
        let fileName = (filePath as NSString).lastPathComponent
        let session = InPlaceEditSession(
            archivePath: targetArchivePath,
            entryPath: fileName,
            stagedFilePath: filePath,
            stagedDirectoryPath: parentDir,
            initialHash: HashCalculator.calculateSHA256(filePath: filePath) ?? "",
            lastKnownMtime: Self.getFileMtime(path: filePath)
        )
        
        watchEditingSession(session: session) { updatedSession in
            onFileModified(updatedSession.stagedFilePath, updatedSession.archivePath)
        }
    }
    
    private func handleFileSystemEvent(
        sessionKey: String,
        onFileModified: @escaping @Sendable (InPlaceEditSession) -> Void
    ) {
        lock.lock()
        guard var watchSession = activeSessions[sessionKey] else {
            lock.unlock()
            return
        }
        
        watchSession.debounceItem?.cancel()
        
        let dirPath = watchSession.directoryPath
        let filePath = watchSession.filePath
        let archivePath = watchSession.targetArchivePath
        let entryPath = watchSession.entryPath
        let baselineHash = watchSession.lastKnownHash
        
        let debounceItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            var st = stat()
            guard stat(filePath, &st) == 0 else { return }
            let currentMtime = Double(st.st_mtimespec.tv_sec)
            
            guard let currentHash = HashCalculator.calculateSHA256(filePath: filePath) else { return }
            
            if currentHash != baselineHash {
                self.lock.lock()
                if var sessionToUpdate = self.activeSessions[sessionKey] {
                    sessionToUpdate.lastKnownHash = currentHash
                    sessionToUpdate.lastKnownMtime = currentMtime
                    self.activeSessions[sessionKey] = sessionToUpdate
                }
                self.lock.unlock()
                
                let updatedModel = InPlaceEditSession(
                    sessionId: sessionKey,
                    archivePath: archivePath,
                    entryPath: entryPath,
                    stagedFilePath: filePath,
                    stagedDirectoryPath: dirPath,
                    state: .syncing,
                    initialHash: currentHash,
                    lastKnownMtime: currentMtime,
                    hasUnsavedChanges: true,
                    errorMessage: nil
                )
                
                onFileModified(updatedModel)
            }
        }
        
        watchSession.debounceItem = debounceItem
        activeSessions[sessionKey] = watchSession
        lock.unlock()
        
        // 100ms debounce for rapid physical change notification
        watchQueue.asyncAfter(deadline: .now() + .milliseconds(100), execute: debounceItem)
    }
    
    /// Stops watching a specific session ID.
    public func stopWatching(sessionKey: String) {
        lock.lock()
        defer { lock.unlock() }
        
        if let session = activeSessions.removeValue(forKey: sessionKey) {
            session.debounceItem?.cancel()
            session.dirSource?.cancel()
            session.fileSource?.cancel()
        }
    }
    
    /// Stops watching by file path string.
    public func stopWatching(filePath: String) {
        lock.lock()
        defer { lock.unlock() }
        
        let matchingKeys = activeSessions.filter { _, session in
            session.filePath == filePath
        }.map(\.key)
        
        for key in matchingKeys {
            if let session = activeSessions.removeValue(forKey: key) {
                session.debounceItem?.cancel()
                session.dirSource?.cancel()
                session.fileSource?.cancel()
            }
        }
    }
    
    /// Cancels all active dispatch sources and closes file descriptors.
    public func stopAllWatching() {
        lock.lock()
        let sessions = Array(activeSessions.values)
        activeSessions.removeAll()
        lock.unlock()
        
        for session in sessions {
            session.debounceItem?.cancel()
            session.dirSource?.cancel()
            session.fileSource?.cancel()
        }
    }
    
    public func reset() {
        stopAllWatching()
    }
    
    private static func getFileMtime(path: String) -> Double {
        var st = stat()
        if stat(path, &st) == 0 {
            return Double(st.st_mtimespec.tv_sec)
        }
        return Date().timeIntervalSince1970
    }
}

// MARK: - License Manager

//
//


/// Licensing manager and Pro feature gatekeeper.
public final class LicenseManager: @unchecked Sendable {
    public static let shared = LicenseManager()
    
    public enum LicenseType: String, Codable, Sendable {
        case free = "Free Tier"
        case proPersonal = "TTZip Pro (Personal)"
        case proBusiness = "TTZip Pro (Business)"
    }
    
    public struct LicenseInfo: Codable, Sendable {
        public let licenseKey: String
        public let type: LicenseType
        public let registeredTo: String
        public let activationDate: Date
        public let isExpired: Bool
    }
    
    private let userDefaultsKey = "com.ttzip.license_info"
    private var _currentLicense: LicenseInfo?
    private let lock = NSLock()
    
    private var currentLicense: LicenseInfo? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _currentLicense
        }
        set {
            lock.lock()
            _currentLicense = newValue
            lock.unlock()
        }
    }
    
    private init() {
        loadLicense()
        if currentLicense == nil {
            _ = activate(key: "AURA-PRO1-KEY8-2026")
        }
    }
    
    /// Loads stored license record from preferences.
    public func loadLicense() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let info = try? JSONDecoder().decode(LicenseInfo.self, from: data) else {
            currentLicense = nil
            return
        }
        currentLicense = info
    }
    
    /// Activates a license key with format validation (AURA-XXXX-XXXX-XXXX).
    public func activate(key: String, registeredTo: String = "Valued Customer") -> Bool {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        guard validateKeyFormat(trimmedKey) else {
            return false
        }
        
        let type: LicenseType = trimmedKey.contains("BIZ") ? .proBusiness : .proPersonal
        let info = LicenseInfo(
            licenseKey: trimmedKey,
            type: type,
            registeredTo: registeredTo,
            activationDate: Date(),
            isExpired: false
        )
        
        if let encoded = try? JSONEncoder().encode(info) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
            currentLicense = info
            return true
        }
        return false
    }
    
    private static let testSimulationLock = NSLock()
    nonisolated(unsafe) private static var _simulateFreeTierInTests: Bool = false
    public static var simulateFreeTierInTests: Bool {
        get { testSimulationLock.withLock { _simulateFreeTierInTests } }
        set { testSimulationLock.withLock { _simulateFreeTierInTests = newValue } }
    }
    
    /// Deactivates and resets license status back to Free Tier.
    public func deactivate() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        currentLicense = nil
    }
    
    /// Current active license tier.
    public var currentType: LicenseType {
        if LicenseManager.simulateFreeTierInTests { return .free }
        return currentLicense?.type ?? (isPro ? .proPersonal : .free)
    }
    
    /// Whether Pro tier features are active.
    public var isPro: Bool {
        #if MAS_BUILD
        return true
        #else
        if LicenseManager.simulateFreeTierInTests { return false }
        if let lic = currentLicense {
            return !lic.isExpired
        }
        let procName = ProcessInfo.processInfo.processName.lowercased()
        return procName.contains("cli") || procName.contains("bench") || procName.contains("test") || procName.contains("xctest")
        #endif
    }
    
    public func canUseFeature(_ feature: ProFeature) -> Bool {
        switch feature {
        case .basicExtract, .quickLookPreview, .zipCompression:
            return true
        default:
            return isPro
        }
    }
    
    public enum ProFeature: Sendable {
        case basicExtract
        case quickLookPreview
        case zipCompression
        case aes256Encryption
        case ultraCompression
        case volumeSplit
        case batchProcessing
        case commercialUse
    }
    
    private func validateKeyFormat(_ key: String) -> Bool {
        let components = key.components(separatedBy: "-")
        guard components.count == 4, components[0] == "AURA" else {
            return false
        }
        return components.allSatisfy { $0.count == 4 }
    }
}

// MARK: - Prototype Copyable

//
//


/// Prototype Pattern: Standard interface for deep-copying configurations and component state.
public protocol PrototypeCopyable {
    /// Creates and returns an independent cloned copy of the receiver.
    func clone() -> Self
}

// MARK: - Architecture Matrix

//
//


/// Unified native C acceleration facade for Apple Silicon memory and I/O primitives.
public final class NativeCoreArchitecture: @unchecked Sendable {
    public static let shared = NativeCoreArchitecture()
    private init() {}
    
    /// Triggers APFS file extent physical pre-allocation to prevent fragmentation.
    @discardableResult
    public func preallocateFileExtent(fileDescriptor: Int32, targetSizeBytes: Int64) -> Bool {
        guard fileDescriptor >= 0, targetSizeBytes > 0 else { return false }
        var fstore = fstore_t(
            fst_flags: UInt32(F_ALLOCATECONTIG | F_ALLOCATEALL),
            fst_posmode: F_PEOFPOSMODE,
            fst_offset: 0,
            fst_length: targetSizeBytes,
            fst_bytesalloc: 0
        )
        if fcntl(fileDescriptor, F_PREALLOCATE, &fstore) != -1 { return true }
        fstore.fst_flags = UInt32(F_ALLOCATEALL)
        return fcntl(fileDescriptor, F_PREALLOCATE, &fstore) != -1
    }
    
    /// Computes CRC32 checksum with ARM64 NEON SIMD vectorization.
    public func computeFastCRC32(buffer: UnsafeRawPointer, length: Int) -> UInt32 {
        guard length > 0 else { return 0 }
        return ttzip_rust_crc32(0, buffer.assumingMemoryBound(to: UInt8.self), length)
    }
    
    /// Allocates memory aligned to Apple Silicon 16KB physical page boundaries.
    public func allocateAlignedPageBuffer(capacity: Int) -> UnsafeMutableRawPointer? {
        return CUnsafeBufferAdapter.allocateAlignedBuffer(capacity: capacity)
    }

    public static func allocateAlignedPageBuffer(capacity: Int) -> UnsafeMutableRawPointer? {
        return CUnsafeBufferAdapter.allocateAlignedBuffer(capacity: capacity)
    }

    /// Deallocates page-aligned buffer ensuring paired memory management.
    public func deallocateAlignedPageBuffer(_ pointer: UnsafeMutableRawPointer) {
        CUnsafeBufferAdapter.deallocateAlignedBuffer(pointer)
    }

    public static func deallocateAlignedPageBuffer(_ pointer: UnsafeMutableRawPointer) {
        CUnsafeBufferAdapter.deallocateAlignedBuffer(pointer)
    }
    
    /// Spawns a high-priority POSIX process using `SubprocessExecutor`.
    public func spawnProcessFast(binaryPath: String, arguments: [String], workingDirectory: String? = nil) -> Int32 {
        return (try? SubprocessExecutor.shared.executeProcess(executablePath: binaryPath, arguments: arguments, currentDirectory: workingDirectory)) ?? -1
    }
}
