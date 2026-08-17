import Foundation

/// 协同组件弱引用封装容器 (防范循环引用)
public final class WeakMediatorComponentWrapper: @unchecked Sendable {
    public let componentId: String
    public weak var component: ArchiveMediatorComponentProtocol?
    
    public init(component: ArchiveMediatorComponentProtocol) {
        self.componentId = component.componentId
        self.component = component
    }
}

/// 【3.8 中介者模式 (Mediator Pattern)】GUI 应用集中化中介者 (UI App Mediator)
public final class ArchiveAppMediator: ArchiveMediatorProtocol, @unchecked Sendable {
    /// 全局共享单例
    public static let shared = ArchiveAppMediator()
    
    private let lock = NSLock()
    private var registry: [String: WeakMediatorComponentWrapper] = [:]
    
    private init() {}
    
    /// 注册组件
    public func register(component: ArchiveMediatorComponentProtocol) {
        lock.lock()
        defer { lock.unlock() }
        
        // 自动清理已被释放的无用弱引用条目
        registry = registry.filter { $0.value.component != nil }
        
        let wrapper = WeakMediatorComponentWrapper(component: component)
        registry[component.componentId] = wrapper
        component.mediator = self
    }
    
    /// 注销组件
    public func unregister(component: ArchiveMediatorComponentProtocol) {
        lock.lock()
        defer { lock.unlock() }
        
        let id = component.componentId
        if let wrapper = registry[id], wrapper.component === component {
            wrapper.component?.mediator = nil
            registry.removeValue(forKey: id)
        }
    }
    
    /// 注销指定 ID 的组件
    public func unregister(componentId: String) {
        lock.lock()
        defer { lock.unlock() }
        
        if let wrapper = registry[componentId] {
            wrapper.component?.mediator = nil
            registry.removeValue(forKey: componentId)
        }
    }
    
    /// 统一广播并定向分发 GUI 应用交互事件
    public func send(event: AppMediatorEvent, from sender: ArchiveMediatorComponentProtocol? = nil) {
        lock.lock()
        // 定时清理已释放条目并快照当前活跃组件
        registry = registry.filter { $0.value.component != nil }
        let activeComponents = registry.values.compactMap { $0.component }
        lock.unlock()
        
        for component in activeComponents {
            // 默认广播至除发送者以外的所有有效订阅组件 (若 sender 为 nil 则通知全员)
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
    
    /// 统一广播 Core 引擎服务协同事件
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
    
    /// 定向发送事件给特定 ID 的组件
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
    
    /// 获取当前注册的活跃组件数量 (自动排查失效弱引用)
    public var registeredComponentCount: Int {
        lock.lock()
        defer { lock.unlock() }
        registry = registry.filter { $0.value.component != nil }
        return registry.count
    }
    
    /// 检查特定组件 ID 是否被成功注册
    public func isRegistered(componentId: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return registry[componentId]?.component != nil
    }
    
    /// 清空所有已注册组件句柄 (用于测试重置)
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        for wrapper in registry.values {
            wrapper.component?.mediator = nil
        }
        registry.removeAll()
    }
}
