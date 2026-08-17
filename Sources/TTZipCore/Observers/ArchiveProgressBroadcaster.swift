import Foundation

/// 【3.2 观察者模式 (Observer Pattern)】线程安全的高性能进度广播总线 (`ArchiveProgressBroadcaster`)
/// 负责在压缩、解压、修复与批处理任务进行中向所有订阅者线程安全地分发实时进度与吞吐率数据
public final class ArchiveProgressBroadcaster: @unchecked Sendable {
    public static let shared = ArchiveProgressBroadcaster()
    
    private var observers: [WeakObserverWrapper] = []
    private let lock = NSLock()
    
    private init() {}
    
    /// 注册进度观察者（支持指定 UI 主线程或自定义队列分发）
    public func addObserver(_ observer: ArchiveProgressObserverProtocol, dispatchQueue: DispatchQueue? = nil) {
        lock.lock()
        defer { lock.unlock() }
        
        observers.removeAll { !$0.isAlive }
        
        if let idx = observers.firstIndex(where: { $0.observer === observer }) {
            observers[idx] = WeakObserverWrapper(observer, dispatchQueue: dispatchQueue)
        } else {
            observers.append(WeakObserverWrapper(observer, dispatchQueue: dispatchQueue))
        }
    }
    
    /// 移除指定进度观察者
    public func removeObserver(_ observer: ArchiveProgressObserverProtocol) {
        lock.lock()
        defer { lock.unlock() }
        
        observers.removeAll { $0.observer === observer || !$0.isAlive }
    }
    
    /// 清空所有注册的进度观察者
    public func removeAllObservers() {
        lock.lock()
        defer { lock.unlock() }
        
        observers.removeAll()
    }
    
    /// 当前活动观察者数量
    public var observerCount: Int {
        lock.lock()
        defer { lock.unlock() }
        
        observers.removeAll { !$0.isAlive }
        return observers.count
    }
    
    /// 广播单文件/单任务进度更新
    public func broadcastProgress(_ progress: ArchiveProgressInfo) {
        lock.lock()
        observers.removeAll { !$0.isAlive }
        let currentObservers = observers
        lock.unlock()
        
        for wrapper in currentObservers {
            wrapper.invoke { (observer: ArchiveProgressObserverProtocol) in
                observer.onProgressUpdated(progress)
            }
        }
    }
    
    /// 广播批处理任务整体进度更新
    public func broadcastBatchProgress(_ progress: BatchProgressInfo) {
        lock.lock()
        observers.removeAll { !$0.isAlive }
        let currentObservers = observers
        lock.unlock()
        
        for wrapper in currentObservers {
            wrapper.invoke { (observer: ArchiveProgressObserverProtocol) in
                observer.onBatchProgressUpdated(progress)
            }
        }
    }
}
