import Foundation

/// 任务取消感知观察者协议
public protocol TaskCancellationObserverProtocol: AnyObject, Sendable {
    func onTaskCancelled(taskId: String)
}

/// 【3.2 观察者模式 (Observer Pattern)】任务取消感知与控制中心 (`TaskCancellationObserverCenter`)
/// 提供跨模块异步任务取消感知、状态查询与取消广播
public final class TaskCancellationObserverCenter: @unchecked Sendable {
    public static let shared = TaskCancellationObserverCenter()
    
    private var cancelledTaskIds: Set<String> = []
    private var observers: [String: [WeakObserverWrapper]] = [:]
    private let lock = NSLock()
    
    private init() {}
    
    /// 注册任务 ID
    public func registerTask(_ taskId: String) {
        lock.lock()
        defer { lock.unlock() }
        cancelledTaskIds.remove(taskId)
    }
    
    /// 声明任务已结束（正常完成/失败/取消善后完毕），清理该 taskId 对应的所有记录与观察者，实现自动剪枝防泄漏
    public func finishTask(_ taskId: String) {
        lock.lock()
        defer { lock.unlock() }
        cancelledTaskIds.remove(taskId)
        observers.removeValue(forKey: taskId)
    }
    
    /// 请求取消指定任务，并向该任务的观察者广播取消事件
    public func cancelTask(_ taskId: String) {
        lock.lock()
        cancelledTaskIds.insert(taskId)
        let taskObservers = observers[taskId] ?? []
        let validObservers = taskObservers.filter { $0.isAlive }
        if validObservers.isEmpty {
            observers.removeValue(forKey: taskId)
        } else {
            observers[taskId] = validObservers
        }
        lock.unlock()
        
        for wrapper in validObservers {
            wrapper.invoke { (observer: TaskCancellationObserverProtocol) in
                observer.onTaskCancelled(taskId: taskId)
            }
        }
    }
    
    /// 检查指定任务是否已请求取消
    public func isTaskCancelled(_ taskId: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelledTaskIds.contains(taskId)
    }
    
    /// 添加任务取消监听器
    public func addObserver(
        _ observer: TaskCancellationObserverProtocol,
        forTask taskId: String,
        dispatchQueue: DispatchQueue? = nil
    ) {
        lock.lock()
        defer { lock.unlock() }
        
        var list = observers[taskId] ?? []
        list.removeAll { !$0.isAlive }
        let wrapper = WeakObserverWrapper(observer, dispatchQueue: dispatchQueue)
        if let idx = list.firstIndex(where: { $0.observer === observer }) {
            list[idx] = wrapper
        } else {
            list.append(wrapper)
        }
        observers[taskId] = list
    }
    
    /// 移除任务取消监听器
    public func removeObserver(_ observer: TaskCancellationObserverProtocol, forTask taskId: String) {
        lock.lock()
        defer { lock.unlock() }
        
        if var list = observers[taskId] {
            list.removeAll { $0.observer === observer || !$0.isAlive }
            if list.isEmpty {
                observers.removeValue(forKey: taskId)
            } else {
                observers[taskId] = list
            }
        }
    }
    
    /// 剪枝清理所有已出作用域自动销毁的失效观察者及空 task 映射
    public func prune() {
        lock.lock()
        defer { lock.unlock() }
        
        for (taskId, list) in observers {
            let valid = list.filter { $0.isAlive }
            if valid.isEmpty {
                observers.removeValue(forKey: taskId)
            } else {
                observers[taskId] = valid
            }
        }
    }
    
    /// 当前已注册观察者的任务 ID 映射数量
    public var registeredObserverTaskCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return observers.keys.count
    }
    
    /// 获取指定任务的活动观察者数量
    public func observerCount(forTask taskId: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        guard let list = observers[taskId] else { return 0 }
        let valid = list.filter { $0.isAlive }
        if valid.isEmpty {
            observers.removeValue(forKey: taskId)
            return 0
        }
        observers[taskId] = valid
        return valid.count
    }
    
    /// 清空所有状态
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        cancelledTaskIds.removeAll()
        observers.removeAll()
    }
}
