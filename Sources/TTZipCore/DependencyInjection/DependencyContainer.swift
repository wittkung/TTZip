import Foundation

// MARK: - 作用域容器 (Dependency Container Scope)

/// 隔离作用域模型 (Scope Token)，用于 `.scoped` 生命周期管理
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
            fatalError("⚠️ [DependencyContainerScope] 容器已释放，无法解析必选服务 \(Service.self)")
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

// MARK: - 注册服务映射内部数据结构

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

// MARK: - 线程安全高性能依赖注入容器 (DependencyContainer)

/// 基于 POSIXReadWriteLock 的高并发安全依赖注入容器
public final class DependencyContainer: DependencyContainerProtocol, @unchecked Sendable {
    
    /// 全局默认共享依赖容器
    public static let shared: DependencyContainer = {
        let container = DependencyContainer()
        TTZipServiceRegistrar.registerAllServices(container: container)
        return container
    }()
    
    private var registrations: [ObjectIdentifier: ServiceRegistrationBox] = [:]
    private let rwLock = POSIXReadWriteLock()
    
    public init() {}
    
    // MARK: - DependencyContainerProtocol 协议实现
    
    /// 注册服务工厂
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
    
    /// 解析可选服务
    public func resolve<Service>(_ type: Service.Type) -> Service? {
        return resolve(type, scope: nil)
    }
    
    /// 支持 Scope 作用域解析可选服务
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
                // 若未显式传入 Scope，回退为单次解析创建
                return box.factory(self) as? Service
            }
        }
    }
    
    /// 解析强类型必选服务
    public func resolveRequired<Service>(_ type: Service.Type) -> Service {
        return resolveRequired(type, scope: nil)
    }
    
    /// 支持 Scope 作用域解析必选服务
    public func resolveRequired<Service>(_ type: Service.Type, scope: DependencyContainerScope?) -> Service {
        if let service: Service = resolve(type, scope: scope) {
            return service
        }
        fatalError("⚠️ [DependencyContainer] 关键服务类型 \(type) 未在依赖注入容器中注册！")
    }
    
    /// 注销服务
    public func unregister<Service>(_ type: Service.Type) {
        let key = ObjectIdentifier(type)
        rwLock.withWriteLock {
            _ = registrations.removeValue(forKey: key)
        }
    }
    
    /// 重置容器状态（清除所有注册与缓存实例）
    public func reset() {
        rwLock.withWriteLock {
            for box in registrations.values {
                box.clearCache()
            }
            registrations.removeAll()
        }
    }
    
    /// 创建全新的隔离作用域 (DependencyContainerScope)
    public func createScope() -> DependencyContainerScope {
        return DependencyContainerScope(container: self)
    }
}

// MARK: - 属性包装器 (Property Wrappers for Zero-Boilerplate Injection)

/// 自动属性注入包装器 (@Injected)
/// 零侵入自动从指定 DependencyContainer 解析必选服务
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

/// 自动可选属性注入包装器 (@InjectedOptional)
/// 零侵入自动从指定 DependencyContainer 解析可选服务，未注册时返回 nil
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
