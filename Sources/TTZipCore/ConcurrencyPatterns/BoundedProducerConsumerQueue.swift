// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Generic bounded producer-consumer queue with cooperative backpressure control.
public final class BoundedProducerConsumerQueue<Element: Sendable>: @unchecked Sendable {
    
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

    /// Pushes element to queue, suspending producer if capacity threshold is reached (backpressure).
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
            
            if !waitingConsumers.isEmpty {
                let consumerContinuation = waitingConsumers.removeFirst()
                lock.unlock()
                continuation.resume()
                consumerContinuation.resume(returning: element)
                return
            }
            
            if buffer.count < maxCapacity {
                buffer.append(element)
                lock.unlock()
                continuation.resume()
                return
            }
            
            waitingProducers.append(PendingProducer(element: element, continuation: continuation))
            lock.unlock()
        }
    }

    /// Pops element from queue head, suspending consumer if buffer is empty until new item or termination.
    public func pop() async throws -> Element? {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Element?, Error>) in
            lock.lock()
            
            if isCancelled {
                let err = cancelError ?? QueueError.cancelled
                lock.unlock()
                continuation.resume(throwing: err)
                return
            }
            
            if !buffer.isEmpty {
                let item = buffer.removeFirst()
                
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
            
            if !waitingProducers.isEmpty {
                let producerToResume = waitingProducers.removeFirst()
                lock.unlock()
                continuation.resume(returning: producerToResume.element)
                producerToResume.continuation.resume()
                return
            }
            
            if isFinished {
                lock.unlock()
                continuation.resume(returning: nil)
                return
            }
            
            waitingConsumers.append(continuation)
            lock.unlock()
        }
    }

    /// Signals end of input to the queue.
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

    /// Cancels the queue, terminating pending producers and consumers immediately with an error.
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
    
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return buffer.count
    }

    public var pendingProducerCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return waitingProducers.count
    }

    public var pendingConsumerCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return waitingConsumers.count
    }

    public var isCompleted: Bool {
        lock.lock()
        defer { lock.unlock() }
        return (isFinished || isCancelled) && buffer.isEmpty
    }
}
