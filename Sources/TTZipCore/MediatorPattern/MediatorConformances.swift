// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Anonymous closure-based mediator component subscriber.
public final class AnonymousMediatorComponent: ArchiveMediatorComponentProtocol, @unchecked Sendable {
    public let componentId: String
    public var mediator: ArchiveMediatorProtocol?
    
    private let appEventCallback: ((AppMediatorEvent) -> Void)?
    private let engineEventCallback: ((CoreEngineMediatorEvent) -> Void)?
    
    public init(
        componentId: String = UUID().uuidString,
        appEventCallback: ((AppMediatorEvent) -> Void)? = nil,
        engineEventCallback: ((CoreEngineMediatorEvent) -> Void)? = nil
    ) {
        self.componentId = componentId
        self.appEventCallback = appEventCallback
        self.engineEventCallback = engineEventCallback
    }
    
    public func receive(event: AppMediatorEvent) {
        appEventCallback?(event)
    }
    
    public func receive(event: CoreEngineMediatorEvent) {
        engineEventCallback?(event)
    }
}

// MARK: - Component Event Notification Helpers

extension ArchiveMediatorComponentProtocol {
    /// Dispatches `AppMediatorEvent` to attached mediator.
    public func notifyMediator(_ event: AppMediatorEvent) {
        mediator?.send(event: event, from: self)
    }
    
    /// Dispatches `CoreEngineMediatorEvent` to attached mediator.
    public func notifyMediator(_ event: CoreEngineMediatorEvent) {
        mediator?.send(event: event, from: self)
    }
}
