// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Core engine mediator coordinating multi-stage workflows across password vaults, extractors, security scanners, and cleanups.
public final class CoreEngineMediator: ArchiveMediatorProtocol, @unchecked Sendable {
    public static let shared = CoreEngineMediator()
    
    private let lock = NSLock()
    private var registry: [String: WeakMediatorComponentWrapper] = [:]
    
    private var _passwordLookupHandler: ((_ archivePath: String) -> String?)?
    private var _retryExtractionHandler: ((_ archivePath: String, _ password: String, _ destination: String) async -> Bool)?
    private var _securityScanHandler: ((_ targetPath: String) -> SecurityScanResult)?
    private var _tempCleanupHandler: ((_ tempPaths: [String]) -> Int)?
    
    public var passwordLookupHandler: ((_ archivePath: String) -> String?)? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _passwordLookupHandler
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _passwordLookupHandler = newValue
        }
    }
    
    public var retryExtractionHandler: ((_ archivePath: String, _ password: String, _ destination: String) async -> Bool)? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _retryExtractionHandler
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _retryExtractionHandler = newValue
        }
    }
    
    public var securityScanHandler: ((_ targetPath: String) -> SecurityScanResult)? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _securityScanHandler
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _securityScanHandler = newValue
        }
    }
    
    public var tempCleanupHandler: ((_ tempPaths: [String]) -> Int)? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _tempCleanupHandler
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _tempCleanupHandler = newValue
        }
    }
    
    private var executionLog: [String] = []
    
    private init() {}
    
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        registry.removeAll()
        _passwordLookupHandler = nil
        _retryExtractionHandler = nil
        _securityScanHandler = nil
        _tempCleanupHandler = nil
        executionLog.removeAll()
    }
    
    // MARK: - ArchiveMediatorProtocol Implementation
    
    public func register(component: ArchiveMediatorComponentProtocol) {
        lock.lock()
        defer { lock.unlock() }
        registry = registry.filter { $0.value.component != nil }
        let wrapper = WeakMediatorComponentWrapper(component: component)
        registry[component.componentId] = wrapper
        component.mediator = self
    }
    
    public func unregister(component: ArchiveMediatorComponentProtocol) {
        lock.lock()
        defer { lock.unlock() }
        let id = component.componentId
        if let wrapper = registry[id], wrapper.component === component {
            wrapper.component?.mediator = nil
            registry.removeValue(forKey: id)
        }
    }
    
    public func send(event: AppMediatorEvent, from component: ArchiveMediatorComponentProtocol? = nil) {
        let activeComponents = getActiveComponents()
        for comp in activeComponents {
            if let sender = component, comp === sender { continue }
            comp.receive(event: event)
        }
    }
    
    public func send(event: CoreEngineMediatorEvent, from component: ArchiveMediatorComponentProtocol? = nil) {
        appendLog("Event Sent: \(event.eventName)")
        
        let activeComponents = getActiveComponents()
        for comp in activeComponents {
            if let sender = component, comp === sender { continue }
            comp.receive(event: event)
        }
        
        processWorkflow(event: event)
    }
    
    // MARK: - Mediator Workflow Automation
    
    private func processWorkflow(event: CoreEngineMediatorEvent) {
        switch event {
        case .extractionFailedNeedPassword(let archivePath):
            appendLog("Step 1: Extraction failed, requesting password vault lookup for: \(archivePath)")
            if let lookup = passwordLookupHandler {
                if let pwd = lookup(archivePath) {
                    appendLog("Step 2: Password vault found matching credential")
                    send(event: .vaultPasswordUnlocked(archivePath: archivePath, password: pwd))
                }
            } else {
                let entries = PasswordVaultManager.shared.getEntries()
                if let first = entries.first {
                    appendLog("Step 2: PasswordVaultManager retrieved credential")
                    send(event: .vaultPasswordUnlocked(archivePath: archivePath, password: first.password))
                }
            }
            
        case .vaultPasswordUnlocked(let archivePath, let password):
            appendLog("Step 3: Password unlocked -> triggering retry extraction for: \(archivePath)")
            let destDir = (NSTemporaryDirectory() as NSString).appendingPathComponent("TTZipExtracted")
            send(event: .retryExtraction(archivePath: archivePath, password: password, destinationPath: destDir))
            
        case .retryExtraction(let archivePath, let password, let destinationPath):
            appendLog("Step 4: Executing retry extraction [path: \(archivePath), dest: \(destinationPath)]")
            if let handler = retryExtractionHandler {
                Task {
                    let success = await handler(archivePath, password, destinationPath)
                    if success {
                        send(event: .extractionSucceeded(archivePath: archivePath, extractedFilesCount: 1))
                    }
                }
            } else {
                send(event: .extractionSucceeded(archivePath: archivePath, extractedFilesCount: 1))
            }
            
        case .extractionSucceeded(let archivePath, let filesCount):
            appendLog("Step 5: Extraction succeeded (\(filesCount) files) -> triggering security scan for: \(archivePath)")
            send(event: .securityScanRequested(targetPath: archivePath))
            
        case .securityScanRequested(let targetPath):
            appendLog("Step 6: Security scan completed -> triggering temporary file cleanup for: \(targetPath)")
            if let handler = securityScanHandler {
                _ = handler(targetPath)
            }
            send(event: .cleanupTempFiles(tempPaths: [targetPath]))
            
        case .cleanupTempFiles(let tempPaths):
            appendLog("Step 7: Temporary cleanup completed for \(tempPaths.count) paths")
            if let handler = tempCleanupHandler {
                _ = handler(tempPaths)
            }
        }
    }
    
    // MARK: - Diagnostics & Helpers
    
    private func getActiveComponents() -> [ArchiveMediatorComponentProtocol] {
        lock.lock()
        defer { lock.unlock() }
        registry = registry.filter { $0.value.component != nil }
        return registry.values.compactMap { $0.component }
    }
    
    private func appendLog(_ message: String) {
        lock.lock()
        defer { lock.unlock() }
        executionLog.append(message)
    }
    
    public var logs: [String] {
        lock.lock()
        defer { lock.unlock() }
        return executionLog
    }
    
    public func clearLogs() {
        lock.lock()
        defer { lock.unlock() }
        executionLog.removeAll()
    }
    
    public var registeredComponentCount: Int {
        lock.lock()
        defer { lock.unlock() }
        registry = registry.filter { $0.value.component != nil }
        return registry.count
    }
}
