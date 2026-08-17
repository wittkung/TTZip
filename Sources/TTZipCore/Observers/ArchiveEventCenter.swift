import Foundation

private struct EventSubscription: Sendable {
    let wrapper: WeakObserverWrapper
    let filterEvents: Set<ArchiveEventType>?
}

/// 【3.2 观察者模式 (Observer Pattern)】全局事件发布-订阅中心 (`ArchiveEventCenter`)
/// 采用弱引用包装器 (WeakObserverWrapper) 彻底消除循环引用，支持解耦发布/订阅系统级异步事件
public final class ArchiveEventCenter: ArchiveEventCenterProtocol, @unchecked Sendable {
    public static let shared = ArchiveEventCenter()
    
    private var subscriptions: [EventSubscription] = []
    private let lock = NSLock()
    
    private init() {}
    
    /// 订阅全局系统事件
    /// - Parameters:
    ///   - observer: 实现了 `ArchiveEventObserverProtocol` 的观察者
    ///   - events: 仅关注的事件集合（传入 nil 则接收全部事件）
    ///   - dispatchQueue: 指定回调分发的 GCD 队列
    public func addObserver(
        _ observer: ArchiveEventObserverProtocol,
        forEvents events: Set<ArchiveEventType>? = nil,
        dispatchQueue: DispatchQueue? = nil
    ) {
        lock.lock()
        defer { lock.unlock() }
        
        subscriptions.removeAll { !$0.wrapper.isAlive }
        
        let wrapper = WeakObserverWrapper(observer, dispatchQueue: dispatchQueue)
        let newSub = EventSubscription(wrapper: wrapper, filterEvents: events)
        if let idx = subscriptions.firstIndex(where: { $0.wrapper.observer === observer }) {
            subscriptions[idx] = newSub
        } else {
            subscriptions.append(newSub)
        }
    }
    
    /// 移除指定事件观察者
    public func removeObserver(_ observer: ArchiveEventObserverProtocol) {
        lock.lock()
        defer { lock.unlock() }
        
        subscriptions.removeAll { $0.wrapper.observer === observer || !$0.wrapper.isAlive }
    }
    
    /// 清空所有注册的事件观察者
    public func removeAllObservers() {
        lock.lock()
        defer { lock.unlock() }
        
        subscriptions.removeAll()
    }
    
    /// 当前活动订阅者数量
    public var observerCount: Int {
        lock.lock()
        defer { lock.unlock() }
        
        subscriptions.removeAll { !$0.wrapper.isAlive }
        return subscriptions.count
    }
    
    /// 发布系统事件
    public func post(event: ArchiveEvent) {
        lock.lock()
        subscriptions.removeAll { !$0.wrapper.isAlive }
        let validSubscriptions = subscriptions
        lock.unlock()
        
        let targetType = event.eventType
        for sub in validSubscriptions {
            if let filter = sub.filterEvents, !filter.contains(targetType) {
                continue
            }
            sub.wrapper.invoke { (observer: ArchiveEventObserverProtocol) in
                observer.onArchiveEvent(event)
            }
        }
    }
    
    // MARK: - 便捷事件发布 API
    
    public func postArchiveCompleted(
        archivePath: String,
        operationType: ArchiveOperationType,
        duration: TimeInterval,
        totalBytes: Int64
    ) {
        post(event: .archiveCompleted(
            archivePath: archivePath,
            operationType: operationType,
            duration: duration,
            totalBytes: totalBytes
        ))
    }
    
    public func postExtractionFailed(archivePath: String, error: String) {
        post(event: .extractionFailed(archivePath: archivePath, error: error))
    }
    
    public func postSecurityThreatIntercepted(archivePath: String, threatDescription: String) {
        post(event: .securityThreatIntercepted(archivePath: archivePath, threatDescription: threatDescription))
    }
    
    public func postPasswordVaultUnlocked(archivePath: String, password: String, isVaultUnlocked: Bool) {
        post(event: .passwordVaultUnlocked(archivePath: archivePath, password: password, isVaultUnlocked: isVaultUnlocked))
    }
    
    public func postPresetChanged(oldPresetName: String?, newPresetName: String) {
        post(event: .presetChanged(oldPresetName: oldPresetName, newPresetName: newPresetName))
    }
    
    public func postTaskStateChanged(taskId: UUID, oldState: String, newState: String) {
        post(event: .taskStateChanged(taskId: taskId, oldState: oldState, newState: newState))
    }
}
