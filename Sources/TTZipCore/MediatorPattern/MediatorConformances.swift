import Foundation

// MARK: - 【3.8 中介者模式 (Mediator Pattern)】核心通用组件扩展与适配器

/// 通用中介者匿名回调组件，适用于不需要独立 Class 的闭包订阅者
public final class AnonymousMediatorComponent: ArchiveMediatorComponentProtocol, @unchecked Sendable {
    public let componentId: String
    public var mediator: ArchiveMediatorProtocol?
    
    private let appEventCallback: ((AppMediatorEvent) -> Void)?
    private let engineEventCallback: ((CoreEngineMediatorEvent) -> Void)?
    
    public init(
        componentId: String = UUID().uuidString,
        appEventCallback: ((AppMediatorEvent) -> Void)? = nil,
        engineEventCallback: ((CoreEngineMediatorEvent) -> Void)? = nil
    ) {
        self.componentId = componentId
        self.appEventCallback = appEventCallback
        self.engineEventCallback = engineEventCallback
    }
    
    public func receive(event: AppMediatorEvent) {
        appEventCallback?(event)
    }
    
    public func receive(event: CoreEngineMediatorEvent) {
        engineEventCallback?(event)
    }
}

// MARK: - 基础组件解耦事件便捷派发扩展

extension ArchiveMediatorComponentProtocol {
    /// 向所属中介者快捷发送 AppMediatorEvent
    public func notifyMediator(_ event: AppMediatorEvent) {
        mediator?.send(event: event, from: self)
    }
    
    /// 向所属中介者快捷发送 CoreEngineMediatorEvent
    public func notifyMediator(_ event: CoreEngineMediatorEvent) {
        mediator?.send(event: event, from: self)
    }
}
