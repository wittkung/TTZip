// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - Mediator Event Definitions

/// GUI and UI layer interaction events.
public enum AppMediatorEvent: Sendable, Equatable {
    case requestPasswordPrompt(archivePath: String)
    case passwordUnlocked(archivePath: String, password: String)
    case requestCompression(inputPaths: [String], outputPath: String)
    case compressionCompleted(outputPath: String)
    case requestExtraction(archivePath: String, destinationPath: String)
    case extractionFailed(archivePath: String, error: String)
    case presetSelected(presetId: String)
    case securityThreatDetected(threatPath: String, reason: String)
    case taskStateChanged(taskId: String, stateDescription: String)
    case openTab(tabIndex: Int)

    public var eventName: String {
        switch self {
        case .requestPasswordPrompt: return "requestPasswordPrompt"
        case .passwordUnlocked: return "passwordUnlocked"
        case .requestCompression: return "requestCompression"
        case .compressionCompleted: return "compressionCompleted"
        case .requestExtraction: return "requestExtraction"
        case .extractionFailed: return "extractionFailed"
        case .presetSelected: return "presetSelected"
        case .securityThreatDetected: return "securityThreatDetected"
        case .taskStateChanged: return "taskStateChanged"
        case .openTab: return "openTab"
        }
    }
}

/// Core engine coordination and workflow events.
public enum CoreEngineMediatorEvent: Sendable, Equatable {
    case extractionFailedNeedPassword(archivePath: String)
    case vaultPasswordUnlocked(archivePath: String, password: String)
    case retryExtraction(archivePath: String, password: String, destinationPath: String)
    case extractionSucceeded(archivePath: String, extractedFilesCount: Int)
    case securityScanRequested(targetPath: String)
    case cleanupTempFiles(tempPaths: [String])

    public var eventName: String {
        switch self {
        case .extractionFailedNeedPassword: return "extractionFailedNeedPassword"
        case .vaultPasswordUnlocked: return "vaultPasswordUnlocked"
        case .retryExtraction: return "retryExtraction"
        case .extractionSucceeded: return "extractionSucceeded"
        case .securityScanRequested: return "securityScanRequested"
        case .cleanupTempFiles: return "cleanupTempFiles"
        }
    }
}

// MARK: - Mediator Protocols

/// Central mediator interface protocol coordinating events between components (Mediator Pattern).
public protocol ArchiveMediatorProtocol: AnyObject, Sendable {
    /// Registers component with the mediator.
    func register(component: ArchiveMediatorComponentProtocol)
    
    /// Unregisters component from the mediator.
    func unregister(component: ArchiveMediatorComponentProtocol)
    
    /// Dispatches UI app events.
    func send(event: AppMediatorEvent, from component: ArchiveMediatorComponentProtocol?)
    
    /// Dispatches core engine coordination events.
    func send(event: CoreEngineMediatorEvent, from component: ArchiveMediatorComponentProtocol?)
}

/// Interface protocol for components interacting via a mediator.
public protocol ArchiveMediatorComponentProtocol: AnyObject, Sendable {
    /// Unique component identifier.
    var componentId: String { get }
    
    /// Weak reference or binding to mediator instance.
    var mediator: ArchiveMediatorProtocol? { get set }
    
    /// Receives UI app events.
    func receive(event: AppMediatorEvent)
    
    /// Receives core engine coordination events.
    func receive(event: CoreEngineMediatorEvent)
}

// MARK: - Default Implementations

extension ArchiveMediatorComponentProtocol {
    public var componentId: String {
        String(reflecting: type(of: self))
    }

    public func receive(event: AppMediatorEvent) {}
    public func receive(event: CoreEngineMediatorEvent) {}
}
