import Foundation

// MARK: - 【4.5 依赖注入模式 (Dependency Injection Pattern)】领域层依赖注入扩展与协议适配

/// 依赖注入引导与测试隔离适配器
public struct DependencyInjectionConformances {
    
    /// 在单元测试或应用启动前重置并预热核心依赖容器
    public static func bootstrapCoreServices() {
        TTZipServiceRegistrar.registerAllServices(container: DependencyContainer.shared)
    }
    
    /// 为指定测试用例注入 Mock 服务实例
    public static func registerMock<Service: Sendable>(_ serviceType: Service.Type, mockInstance: Service) {
        DependencyContainer.shared.register(serviceType, lifetime: .singleton) { _ in
            mockInstance
        }
    }
    
    /// 恢复指定服务为默认生产环境实现
    public static func restoreDefaultService<Service>(_ serviceType: Service.Type) {
        TTZipServiceRegistrar.registerAllServices(container: DependencyContainer.shared)
    }
}
