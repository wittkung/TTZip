// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Unified service registrar configuring core engines, facades, repositories, and handlers.
public enum TTZipServiceRegistrar {
    
    /// Registers all standard library services and protocol bindings into the given container.
    public static func registerAllServices(container: DependencyContainerProtocol = DependencyContainer.shared) {
        
        // MARK: - 1. Facades & Engines
        container.register(TTZipEngineFacading.self, lifetime: .singleton) { _ in
            TTZipEngineFacade.shared
        }
        container.register(TTZipEngineFacade.self, lifetime: .singleton) { _ in
            TTZipEngineFacade.shared
        }
        container.register(ArchiveBatchFacade.self, lifetime: .singleton) { _ in
            ArchiveBatchFacade.shared
        }
        
        // MARK: - 2. Repositories
        container.register((any ArchivePresetRepositoryProtocol).self, lifetime: .singleton) { _ in
            UserDefaultsPresetRepository()
        }
        container.register(UserDefaultsPresetRepository.self, lifetime: .singleton) { _ in
            UserDefaultsPresetRepository()
        }
        container.register(KeychainPasswordRepository.self, lifetime: .singleton) { _ in
            KeychainPasswordRepository.shared
        }
        container.register((any ArchiveHistoryRepositoryProtocol).self, lifetime: .singleton) { _ in
            JSONFileArchiveHistoryRepository()
        }
        container.register(JSONFileArchiveHistoryRepository.self, lifetime: .singleton) { _ in
            JSONFileArchiveHistoryRepository()
        }
        
        // MARK: - 3. Mediator & Event Center
        container.register(ArchiveMediatorProtocol.self, lifetime: .singleton) { _ in
            ArchiveAppMediator.shared
        }
        container.register(ArchiveAppMediator.self, lifetime: .singleton) { _ in
            ArchiveAppMediator.shared
        }
        container.register(ArchiveEventCenterProtocol.self, lifetime: .singleton) { _ in
            ArchiveEventCenter.shared
        }
        container.register(ArchiveEventCenter.self, lifetime: .singleton) { _ in
            ArchiveEventCenter.shared
        }
        
        // MARK: - 4. Concurrency & Task Dispatcher
        container.register(ArchiveWorkerPool.self, lifetime: .singleton) { _ in
            ArchiveWorkerPool.shared
        }
        container.register(ArchiveTaskDispatcher.self, lifetime: .transient) { _ in
            ArchiveTaskDispatcher()
        }
        
        // MARK: - 5. Proxies
        container.register(ArchiveInspectionCacheProxy.self, lifetime: .singleton) { _ in
            ArchiveInspectionCacheProxy.shared
        }
        container.register(SecurityProtectionProxy.self, lifetime: .singleton) { _ in
            SecurityProtectionProxy.shared
        }
        container.register(SmartLoggingProxy.self, lifetime: .singleton) { _ in
            SmartLoggingProxy.shared
        }
        
        // MARK: - 6. Strategy Contexts
        container.register(CharsetDetectionStrategyContext.self, lifetime: .singleton) { _ in
            CharsetDetectionStrategyContext.shared
        }
        
        // MARK: - 7. State Machine & Caretakers
        container.register(ArchiveTaskStateMachine.self, lifetime: .transient) { _ in
            ArchiveTaskStateMachine()
        }
        container.register(PresetEditorCaretaker.self, lifetime: .transient) { _ in
            PresetEditorCaretaker()
        }
        container.register(AppViewStateCaretaker.self, lifetime: .transient) { _ in
            AppViewStateCaretaker()
        }
        container.register(TaskCheckpointCaretaker.self, lifetime: .transient) { _ in
            TaskCheckpointCaretaker()
        }
        
        // MARK: - 8. Managers & Security
        container.register(PresetManager.self, lifetime: .singleton) { _ in
            PresetManager.shared
        }
        container.register(PasswordVaultManager.self, lifetime: .singleton) { _ in
            PasswordVaultManager.shared
        }
        container.register(CommandHistoryManager.self, lifetime: .singleton) { _ in
            CommandHistoryManager.shared
        }
        container.register(LicenseManager.self, lifetime: .singleton) { _ in
            LicenseManager.shared
        }
    }
}
