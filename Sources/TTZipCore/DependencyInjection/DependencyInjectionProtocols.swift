// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Service lifecycle definitions within dependency containers.
public enum ServiceLifetime: Sendable, Equatable {
    /// Global singleton: instantiated upon first resolution and reused across subsequent requests.
    case singleton
    /// Transient: instantiated anew via factory upon every resolution.
    case transient
    /// Scoped: reused within the same `DependencyContainerScope`, isolated across different scopes.
    case scoped
}

/// Dependency injection container protocol defining registration, resolution, and reset semantics.
public protocol DependencyContainerProtocol: AnyObject, Sendable {
    /// Registers a service factory.
    func register<Service>(
        _ type: Service.Type,
        lifetime: ServiceLifetime,
        factory: @escaping @Sendable (DependencyContainerProtocol) -> Service
    )
    
    /// Resolves an optional service instance.
    func resolve<Service>(_ type: Service.Type) -> Service?
    
    /// Resolves a required service instance.
    func resolveRequired<Service>(_ type: Service.Type) -> Service
    
    /// Unregisters a registered service type.
    func unregister<Service>(_ type: Service.Type)
    
    /// Resets container registrations and cached instances.
    func reset()
}

extension DependencyContainerProtocol {
    /// Convenience registration helper using default generic type.
    public func register<Service>(
        _ type: Service.Type = Service.self,
        lifetime: ServiceLifetime = .singleton,
        factory: @escaping @Sendable (DependencyContainerProtocol) -> Service
    ) {
        register(type, lifetime: lifetime, factory: factory)
    }
    
    /// Convenience resolution helper with inferred return type.
    public func resolve<Service>() -> Service? {
        return resolve(Service.self)
    }
    
    /// Convenience required resolution helper with inferred return type.
    public func resolveRequired<Service>() -> Service {
        return resolveRequired(Service.self)
    }
}
