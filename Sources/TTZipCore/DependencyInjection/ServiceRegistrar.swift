import Foundation

// MARK: - 全库服务统一注册入口 (TTZipServiceRegistrar)

/// 负责全库 20+ 核心服务、仓储、代理、中介者与并发调度器的引导注册
public enum TTZipServiceRegistrar {
    
    /// 统一注册全库所有服务与接口映射
    public static func registerAllServices(container: DependencyContainerProtocol = DependencyContainer.shared) {
        
        // MARK: - 1. 外观门面与引擎 (Facades & Engine)
        container.register(TTZipEngineFacading.self, lifetime: .singleton) { _ in
            TTZipEngineFacade.shared
        }
        container.register(TTZipEngineFacade.self, lifetime: .singleton) { _ in
            TTZipEngineFacade.shared
        }
        container.register(ArchiveBatchFacade.self, lifetime: .singleton) { _ in
            ArchiveBatchFacade.shared
        }
        
        // MARK: - 2. 仓储层 (Repositories)
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
        
        // MARK: - 3. 中介者与观察者中心 (Mediator & Event Center)
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
        
        // MARK: - 4. 并发与任务调度器 (Concurrency & Task Dispatcher)
        container.register(ArchiveWorkerPool.self, lifetime: .singleton) { _ in
            ArchiveWorkerPool.shared
        }
        container.register(ArchiveTaskDispatcher.self, lifetime: .transient) { _ in
            ArchiveTaskDispatcher()
        }
        
        // MARK: - 5. 代理层 (Proxies)
        container.register(ArchiveInspectionCacheProxy.self, lifetime: .singleton) { _ in
            ArchiveInspectionCacheProxy.shared
        }
        container.register(SecurityProtectionProxy.self, lifetime: .singleton) { _ in
            SecurityProtectionProxy.shared
        }
        container.register(SmartLoggingProxy.self, lifetime: .singleton) { _ in
            SmartLoggingProxy.shared
        }
        
        // MARK: - 6. 策略上下文 (Strategy Contexts)
        container.register(CharsetDetectionStrategyContext.self, lifetime: .singleton) { _ in
            CharsetDetectionStrategyContext.shared
        }
        
        // MARK: - 7. 状态机与备忘录管理者 (State Machine & Caretakers)
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
        
        // MARK: - 8. 基础设施与管理器 (Managers & Security)
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
