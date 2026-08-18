// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Dependency injection test bootstrapping and mock registration adapter.
public struct DependencyInjectionConformances {
    
    /// Bootstraps core services into the shared dependency container.
    public static func bootstrapCoreServices() {
        TTZipServiceRegistrar.registerAllServices(container: DependencyContainer.shared)
    }
    
    /// Injects a mock service implementation for test isolation.
    public static func registerMock<Service: Sendable>(_ serviceType: Service.Type, mockInstance: Service) {
        DependencyContainer.shared.register(serviceType, lifetime: .singleton) { _ in
            mockInstance
        }
    }
    
    /// Restores default production service registrations.
    public static func restoreDefaultService<Service>(_ serviceType: Service.Type) {
        TTZipServiceRegistrar.registerAllServices(container: DependencyContainer.shared)
    }
}
