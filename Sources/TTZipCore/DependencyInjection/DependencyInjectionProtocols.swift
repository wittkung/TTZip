import Foundation

// MARK: - 【4.5 依赖注入模式 (Dependency Injection Pattern)】服务生命周期枚举

/// 定义服务在依赖容器中的生命周期
public enum ServiceLifetime: Sendable, Equatable {
    /// 全局单例：在首次解析时实例化，后续解析复用同一实例
    case singleton
    /// 瞬态：每次解析均通过 Factory 重新创建全新实例
    case transient
    /// 作用域隔离：在同一 Scope 作用域中复用同一实例，不同 Scope 隔离开
    case scoped
}

// MARK: - 依赖注入容器接口协议 (Dependency Container Protocol)

/// 规范依赖注入容器的注册、解析、注销与重置能力
public protocol DependencyContainerProtocol: AnyObject, Sendable {
    /// 注册服务工厂
    func register<Service>(
        _ type: Service.Type,
        lifetime: ServiceLifetime,
        factory: @escaping @Sendable (DependencyContainerProtocol) -> Service
    )
    
    /// 解析可选服务实例
    func resolve<Service>(_ type: Service.Type) -> Service?
    
    /// 解析强类型必选服务
    func resolveRequired<Service>(_ type: Service.Type) -> Service
    
    /// 注销指定类型的服务
    func unregister<Service>(_ type: Service.Type)
    
    /// 清空容器所有注册条目与缓存实例
    func reset()
}

extension DependencyContainerProtocol {
    /// 便捷注册默认类型
    public func register<Service>(
        _ type: Service.Type = Service.self,
        lifetime: ServiceLifetime = .singleton,
        factory: @escaping @Sendable (DependencyContainerProtocol) -> Service
    ) {
        register(type, lifetime: lifetime, factory: factory)
    }
    
    /// 便捷解析泛型推导服务
    public func resolve<Service>() -> Service? {
        return resolve(Service.self)
    }
    
    /// 便捷解析强类型必选泛型推导服务
    public func resolveRequired<Service>() -> Service {
        return resolveRequired(Service.self)
    }
}
