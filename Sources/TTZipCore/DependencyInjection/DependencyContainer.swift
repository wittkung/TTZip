// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - Dependency Container Scope

/// Isolated scope token managing `.scoped` service lifetimes.
public final class DependencyContainerScope: @unchecked Sendable {
    public let scopeID = UUID()
    private weak var container: DependencyContainer?
    private var scopedInstances: [ObjectIdentifier: Any] = [:]
    private let lock = POSIXReadWriteLock()
    
    public init(container: DependencyContainer) {
        self.container = container
    }
    
    public func resolve<Service>(_ type: Service.Type = Service.self) -> Service? {
        guard let container = container else { return nil }
        return container.resolve(type, scope: self)
    }
    
    public func resolveRequired<Service>(_ type: Service.Type = Service.self) -> Service {
        guard let container = container else {
            fatalError("[DependencyContainerScope] Container deallocated, unable to resolve required service: \(Service.self)")
        }
        return container.resolveRequired(type, scope: self)
    }
    
    fileprivate func getCachedInstance<Service>(for key: ObjectIdentifier) -> Service? {
        return lock.withReadLock {
            return scopedInstances[key] as? Service
        }
    }
    
    fileprivate func setCachedInstance<Service>(_ instance: Service, for key: ObjectIdentifier) {
        lock.withWriteLock {
            scopedInstances[key] = instance
        }
    }
    
    public func clear() {
        lock.withWriteLock {
            scopedInstances.removeAll()
        }
    }
}

// MARK: - Service Registration Box

private final class ServiceRegistrationBox: @unchecked Sendable {
    let lifetime: ServiceLifetime
    let factory: @Sendable (DependencyContainerProtocol) -> Any
    var singletonInstance: Any?
    let lock = POSIXReadWriteLock()
    
    init(lifetime: ServiceLifetime, factory: @escaping @Sendable (DependencyContainerProtocol) -> Any) {
        self.lifetime = lifetime
        self.factory = factory
    }
    
    func getOrCreateSingleton(container: DependencyContainerProtocol) -> Any {
        return lock.withWriteLock {
            if let existing = singletonInstance {
                return existing
            }
            let newInstance = factory(container)
            singletonInstance = newInstance
            return newInstance
        }
    }
    
    func clearCache() {
        lock.withWriteLock {
            singletonInstance = nil
        }
    }
}

// MARK: - High-Performance Thread-Safe Dependency Container

/// Thread-safe dependency injection container built upon `POSIXReadWriteLock`.
public final class DependencyContainer: DependencyContainerProtocol, @unchecked Sendable {
    
    /// Global shared dependency container instance.
    public static let shared: DependencyContainer = {
        let container = DependencyContainer()
        TTZipServiceRegistrar.registerAllServices(container: container)
        return container
    }()
    
    private var registrations: [ObjectIdentifier: ServiceRegistrationBox] = [:]
    private let rwLock = POSIXReadWriteLock()
    
    public init() {}
    
    // MARK: - DependencyContainerProtocol Implementation
    
    /// Registers a service factory and lifetime specification.
    public func register<Service>(
        _ type: Service.Type,
        lifetime: ServiceLifetime = .singleton,
        factory: @escaping @Sendable (DependencyContainerProtocol) -> Service
    ) {
        let key = ObjectIdentifier(type)
        let box = ServiceRegistrationBox(lifetime: lifetime, factory: factory)
        rwLock.withWriteLock {
            registrations[key] = box
        }
    }
    
    /// Resolves an optional service instance.
    public func resolve<Service>(_ type: Service.Type) -> Service? {
        return resolve(type, scope: nil)
    }
    
    /// Resolves an optional service instance within an optional container scope.
    public func resolve<Service>(_ type: Service.Type, scope: DependencyContainerScope?) -> Service? {
        let key = ObjectIdentifier(type)
        guard let box = (rwLock.withReadLock { registrations[key] }) else {
            return nil
        }
        
        switch box.lifetime {
        case .singleton:
            return box.getOrCreateSingleton(container: self) as? Service
            
        case .transient:
            return box.factory(self) as? Service
            
        case .scoped:
            if let scope = scope {
                if let cached: Service = scope.getCachedInstance(for: key) {
                    return cached
                }
                let created = box.factory(self)
                if let typed = created as? Service {
                    scope.setCachedInstance(typed, for: key)
                }
                return created as? Service
            } else {
                return box.factory(self) as? Service
            }
        }
    }
    
    /// Resolves a required service instance or throws a fatal assertion.
    public func resolveRequired<Service>(_ type: Service.Type) -> Service {
        return resolveRequired(type, scope: nil)
    }
    
    /// Resolves a required service instance within an optional container scope.
    public func resolveRequired<Service>(_ type: Service.Type, scope: DependencyContainerScope?) -> Service {
        if let service: Service = resolve(type, scope: scope) {
            return service
        }
        fatalError("[DependencyContainer] Required service \(type) is not registered in dependency container.")
    }
    
    /// Unregisters a previously registered service type.
    public func unregister<Service>(_ type: Service.Type) {
        let key = ObjectIdentifier(type)
        rwLock.withWriteLock {
            _ = registrations.removeValue(forKey: key)
        }
    }
    
    /// Resets container registrations and cached instances.
    public func reset() {
        rwLock.withWriteLock {
            for box in registrations.values {
                box.clearCache()
            }
            registrations.removeAll()
        }
    }
    
    /// Creates an isolated execution scope.
    public func createScope() -> DependencyContainerScope {
        return DependencyContainerScope(container: self)
    }
}

// MARK: - Property Wrappers

/// Property wrapper providing zero-boilerplate service injection.
@propertyWrapper
public struct Injected<Service>: Sendable {
    private let containerProvider: @Sendable () -> DependencyContainerProtocol
    
    public init(container: DependencyContainerProtocol = DependencyContainer.shared) {
        self.containerProvider = { container }
    }
    
    public init(containerProvider: @escaping @Sendable () -> DependencyContainerProtocol) {
        self.containerProvider = containerProvider
    }
    
    public var wrappedValue: Service {
        let container = containerProvider()
        return container.resolveRequired(Service.self)
    }
}

/// Property wrapper providing zero-boilerplate optional service injection.
@propertyWrapper
public struct InjectedOptional<Service>: Sendable {
    private let containerProvider: @Sendable () -> DependencyContainerProtocol
    
    public init(container: DependencyContainerProtocol = DependencyContainer.shared) {
        self.containerProvider = { container }
    }
    
    public init(containerProvider: @escaping @Sendable () -> DependencyContainerProtocol) {
        self.containerProvider = containerProvider
    }
    
    public var wrappedValue: Service? {
        let container = containerProvider()
        return container.resolve(Service.self)
    }
}
