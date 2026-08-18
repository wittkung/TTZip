// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Weak reference container preventing retain cycles in mediator registries.
public final class WeakMediatorComponentWrapper: @unchecked Sendable {
    public let componentId: String
    public weak var component: ArchiveMediatorComponentProtocol?
    
    public init(component: ArchiveMediatorComponentProtocol) {
        self.componentId = component.componentId
        self.component = component
    }
}

/// Centralized GUI application mediator coordinating UI interactions and event broadcasting.
public final class ArchiveAppMediator: ArchiveMediatorProtocol, @unchecked Sendable {
    public static let shared = ArchiveAppMediator()
    
    private let lock = NSLock()
    private var registry: [String: WeakMediatorComponentWrapper] = [:]
    
    private init() {}
    
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
    
    public func unregister(componentId: String) {
        lock.lock()
        defer { lock.unlock() }
        
        if let wrapper = registry[componentId] {
            wrapper.component?.mediator = nil
            registry.removeValue(forKey: componentId)
        }
    }
    
    public func send(event: AppMediatorEvent, from sender: ArchiveMediatorComponentProtocol? = nil) {
        lock.lock()
        registry = registry.filter { $0.value.component != nil }
        let activeComponents = registry.values.compactMap { $0.component }
        lock.unlock()
        
        for component in activeComponents {
            if let sender = sender, component === sender {
                continue
            }
            
            if Thread.isMainThread {
                component.receive(event: event)
            } else {
                DispatchQueue.main.async {
                    component.receive(event: event)
                }
            }
        }
    }
    
    public func send(event: CoreEngineMediatorEvent, from sender: ArchiveMediatorComponentProtocol? = nil) {
        lock.lock()
        registry = registry.filter { $0.value.component != nil }
        let activeComponents = registry.values.compactMap { $0.component }
        lock.unlock()
        
        for component in activeComponents {
            if let sender = sender, component === sender {
                continue
            }
            
            if Thread.isMainThread {
                component.receive(event: event)
            } else {
                DispatchQueue.main.async {
                    component.receive(event: event)
                }
            }
        }
    }
    
    public func sendTargeted(event: AppMediatorEvent, targetComponentId: String) {
        lock.lock()
        let targetComponent = registry[targetComponentId]?.component
        lock.unlock()
        
        guard let component = targetComponent else { return }
        
        if Thread.isMainThread {
            component.receive(event: event)
        } else {
            DispatchQueue.main.async {
                component.receive(event: event)
            }
        }
    }
    
    public var registeredComponentCount: Int {
        lock.lock()
        defer { lock.unlock() }
        registry = registry.filter { $0.value.component != nil }
        return registry.count
    }
    
    public func isRegistered(componentId: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return registry[componentId]?.component != nil
    }
    
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        for wrapper in registry.values {
            wrapper.component?.mediator = nil
        }
        registry.removeAll()
    }
}
