import Foundation

private final class WeakBox: @unchecked Sendable {
    weak var value: AnyObject?
    init(_ value: AnyObject?) {
        self.value = value
    }
}

/// 弱引用观察者包装器，彻底消除循环引用与内存泄露隐患
public final class WeakObserverWrapper: @unchecked Sendable {
    public weak var observer: AnyObject?
    public let dispatchQueue: DispatchQueue?
    
    public init(_ observer: AnyObject, dispatchQueue: DispatchQueue? = nil) {
        self.observer = observer
        self.dispatchQueue = dispatchQueue
    }
    
    public var isAlive: Bool {
        return observer != nil
    }
    
    /// 在指定队列或当前线程安全分发回调
    public func invoke<Observer>(_ closure: @escaping (Observer) -> Void) {
        if let queue = dispatchQueue {
            let box = WeakBox(observer)
            nonisolated(unsafe) let sendableClosure = closure
            queue.async {
                guard let target = box.value as? Observer else { return }
                sendableClosure(target)
            }
        } else {
            guard let target = observer as? Observer else { return }
            closure(target)
        }
    }
}
