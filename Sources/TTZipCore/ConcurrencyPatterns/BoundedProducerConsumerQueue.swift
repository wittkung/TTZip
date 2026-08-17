import Foundation

/// 泛型有界背压 (Backpressure) 生产者-消费者并发队列
/// 限制内存峰值防止 OOM，提供 Push/Pop/Finish/Cancel 管道生命周期控制与 Zero Deadlock 保证
public final class BoundedProducerConsumerQueue<Element: Sendable>: @unchecked Sendable {
    
    /// 有界队列异常类型
    public enum QueueError: Error, CustomStringConvertible, Equatable {
        case finished
        case cancelled
        case custom(String)

        public static func == (lhs: QueueError, rhs: QueueError) -> Bool {
            switch (lhs, rhs) {
            case (.finished, .finished), (.cancelled, .cancelled):
                return true
            case (.custom(let l), .custom(let r)):
                return l == r
            default:
                return false
            }
        }

        public var description: String {
            switch self {
            case .finished:
                return "BoundedProducerConsumerQueue has been finished."
            case .cancelled:
                return "BoundedProducerConsumerQueue has been cancelled."
            case .custom(let reason):
                return "BoundedProducerConsumerQueue error: \(reason)"
            }
        }
    }

    private struct PendingProducer {
        let element: Element
        let continuation: CheckedContinuation<Void, Error>
    }

    private let lock = NSLock()
    public let maxCapacity: Int
    private var buffer: [Element] = []
    private var isFinished: Bool = false
    private var isCancelled: Bool = false
    private var cancelError: Error? = nil

    private var waitingConsumers: [CheckedContinuation<Element?, Error>] = []
    private var waitingProducers: [PendingProducer] = []

    public init(maxCapacity: Int = 16) {
        self.maxCapacity = max(1, maxCapacity)
    }

    /// 推送元素入队列 (当队列满时自动暂停生产者，触发 Backpressure)
    public func push(_ element: Element) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            lock.lock()
            
            if isCancelled {
                let err = cancelError ?? QueueError.cancelled
                lock.unlock()
                continuation.resume(throwing: err)
                return
            }
            
            if isFinished {
                lock.unlock()
                continuation.resume(throwing: QueueError.finished)
                return
            }
            
            // 若有正在挂起等待数据的消费者，直接透传数据给消费者
            if !waitingConsumers.isEmpty {
                let consumerContinuation = waitingConsumers.removeFirst()
                lock.unlock()
                continuation.resume()
                consumerContinuation.resume(returning: element)
                return
            }
            
            // 若队列未满，直接入队
            if buffer.count < maxCapacity {
                buffer.append(element)
                lock.unlock()
                continuation.resume()
                return
            }
            
            // 队列已满：挂起生产者，放入等待队列 (Backpressure)
            waitingProducers.append(PendingProducer(element: element, continuation: continuation))
            lock.unlock()
        }
    }

    /// 弹出队列头部元素 (当队列为空时自动暂停消费者，待有新元素入队或 finish 时唤醒)
    public func pop() async throws -> Element? {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Element?, Error>) in
            lock.lock()
            
            if isCancelled {
                let err = cancelError ?? QueueError.cancelled
                lock.unlock()
                continuation.resume(throwing: err)
                return
            }
            
            // 若 Buffer 非空，取出头部元素
            if !buffer.isEmpty {
                let item = buffer.removeFirst()
                
                // 唤醒一个挂起中的生产者，将其元素补入 Buffer
                var producerToResume: PendingProducer? = nil
                if !waitingProducers.isEmpty {
                    producerToResume = waitingProducers.removeFirst()
                    buffer.append(producerToResume!.element)
                }
                lock.unlock()
                
                continuation.resume(returning: item)
                producerToResume?.continuation.resume()
                return
            }
            
            // Buffer 为空但有挂起的生产者 (防边界保护)
            if !waitingProducers.isEmpty {
                let producerToResume = waitingProducers.removeFirst()
                lock.unlock()
                continuation.resume(returning: producerToResume.element)
                producerToResume.continuation.resume()
                return
            }
            
            // Buffer 为空且已 finish
            if isFinished {
                lock.unlock()
                continuation.resume(returning: nil)
                return
            }
            
            // Buffer 为空且处于正常接收状态：挂起消费者
            waitingConsumers.append(continuation)
            lock.unlock()
        }
    }

    /// 标记数据推入完毕
    public func finish() {
        lock.lock()
        if isFinished || isCancelled {
            lock.unlock()
            return
        }
        isFinished = true
        
        let consumersToResume = waitingConsumers
        waitingConsumers.removeAll()
        
        let producersToResume = waitingProducers
        waitingProducers.removeAll()
        
        lock.unlock()
        
        for consumer in consumersToResume {
            consumer.resume(returning: nil)
        }
        for producer in producersToResume {
            producer.continuation.resume(throwing: QueueError.finished)
        }
    }

    /// 取消队列并通知所有挂起的生产者和消费者
    public func cancel(error: Error? = nil) {
        lock.lock()
        if isCancelled {
            lock.unlock()
            return
        }
        isCancelled = true
        cancelError = error
        
        buffer.removeAll()
        
        let consumersToResume = waitingConsumers
        waitingConsumers.removeAll()
        
        let producersToResume = waitingProducers
        waitingProducers.removeAll()
        
        lock.unlock()
        
        let err = error ?? QueueError.cancelled
        for consumer in consumersToResume {
            consumer.resume(throwing: err)
        }
        for producer in producersToResume {
            producer.continuation.resume(throwing: err)
        }
    }

    // MARK: - Safe State Inspection
    
    /// 当前 Buffer 中元素数量
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return buffer.count
    }

    /// 挂起中的生产者数量
    public var pendingProducerCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return waitingProducers.count
    }

    /// 挂起中的消费者数量
    public var pendingConsumerCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return waitingConsumers.count
    }

    /// 队列是否终结 (Finish 或 Cancel) 且 Buffer 归零
    public var isCompleted: Bool {
        lock.lock()
        defer { lock.unlock() }
        return (isFinished || isCancelled) && buffer.isEmpty
    }
}
