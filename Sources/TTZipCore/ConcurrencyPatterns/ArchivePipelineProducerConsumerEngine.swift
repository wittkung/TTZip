import Foundation
import CTTZipBridge

/// 磁盘流式读取生产者 (DiskReadProducer)
/// 结合 MemoryPageFlyweightPool 分配页对齐 Buffer 流式读入数据块
public final class DiskReadProducer: AsyncProducerProtocol, @unchecked Sendable {
    private let fileURL: URL
    private let chunkSize: Int
    private let lock = NSLock()
    private var fileHandle: FileHandle?
    private var currentChunkID: Int64 = 0
    private var currentOffset: Int64 = 0
    private var isEOFReached: Bool = false

    public init(filePath: String, chunkSize: Int = 64 * 1024) throws {
        self.fileURL = URL(fileURLWithPath: filePath)
        self.chunkSize = max(4096, chunkSize)
        self.fileHandle = try FileHandle(forReadingFrom: fileURL)
    }

    deinit {
        try? fileHandle?.close()
    }

    private func performSyncProduce() throws -> ArchiveDataChunk? {
        lock.lock()
        defer { lock.unlock() }

        if isEOFReached {
            return nil
        }

        guard let handle = fileHandle else {
            isEOFReached = true
            return nil
        }

        let pageSize: MemoryPageSize = chunkSize <= 4096 ? .page4K : .page64K
        let flyweight = MemoryPageFlyweightPool.shared.borrowBuffer(size: pageSize)
        defer { MemoryPageFlyweightPool.shared.returnBuffer(flyweight) }

        let readData = (try? handle.read(upToCount: chunkSize)) ?? Data()
        if readData.isEmpty {
            isEOFReached = true
            let eofChunk = ArchiveDataChunk.eof(chunkID: currentChunkID)
            currentChunkID += 1
            return eofChunk
        }

        let chunk = ArchiveDataChunk(
            chunkID: currentChunkID,
            offset: currentOffset,
            data: readData,
            isEOF: false
        )

        currentChunkID += 1
        currentOffset += Int64(readData.count)

        if readData.count < chunkSize {
            isEOFReached = true
        }

        return chunk
    }

    public func produce() async throws -> ArchiveDataChunk? {
        return try performSyncProduce()
    }
}

/// 多线程并行压缩消费者组 (CompressorConsumerGroup)
/// 利用 Apple Silicon / 多核并发对 Input Queue 数据块进行全核极速压缩
public final class CompressorConsumerGroup: @unchecked Sendable {
    private let workerCount: Int
    private let compressionLevel: ArchiveCompressionLevel

    public init(
        workerCount: Int = max(2, ProcessInfo.processInfo.activeProcessorCount),
        compressionLevel: ArchiveCompressionLevel = .normal
    ) {
        self.workerCount = max(1, workerCount)
        self.compressionLevel = compressionLevel
    }

    /// 开启并行压缩管道工作线程，从 inputQueue 读取 Chunk，压缩后推入 outputQueue
    public func startProcessing(
        inputQueue: BoundedProducerConsumerQueue<ArchiveDataChunk>,
        outputQueue: BoundedProducerConsumerQueue<ArchiveDataChunk>
    ) async throws {
        let level = compressionLevel
        let libdeflateLevel: Int32 = Int32(min(12, max(0, level.rawValue)))

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<workerCount {
                group.addTask {
                    while true {
                        guard let chunk = try await inputQueue.pop() else { break }
                        
                        if chunk.isEOF {
                            try await outputQueue.push(chunk)
                            break
                        }

                        let rawData = chunk.data
                        var compressedData = rawData

                        if level != .store && !rawData.isEmpty {
                            let maxCap = rawData.count + 512
                            let pageSize: MemoryPageSize = maxCap > 4096 ? .page64K : .page4K
                            var compSize: size_t = 0
                            var payloadBuf = Data()

                            MemoryPageFlyweightPool.shared.withBuffer(size: pageSize) { dstPtr, capacity in
                                if capacity >= maxCap {
                                    compSize = rawData.withUnsafeBytes { inPtr -> size_t in
                                        guard let src = inPtr.baseAddress else { return 0 }
                                        return ttzip_libdeflate_compress(src, rawData.count, dstPtr, capacity, libdeflateLevel)
                                    }
                                    if compSize > 0 && compSize < rawData.count {
                                        payloadBuf = Data(bytes: dstPtr, count: compSize)
                                    }
                                } else {
                                    let uninitPtr = UnsafeMutablePointer<UInt8>.allocate(capacity: maxCap)
                                    compSize = rawData.withUnsafeBytes { inPtr -> size_t in
                                        guard let src = inPtr.baseAddress else { return 0 }
                                        return ttzip_libdeflate_compress(src, rawData.count, uninitPtr, maxCap, libdeflateLevel)
                                    }
                                    if compSize > 0 && compSize < rawData.count {
                                        payloadBuf = Data(bytesNoCopy: uninitPtr, count: compSize, deallocator: .custom { ptr, _ in ptr.deallocate() })
                                    } else {
                                        uninitPtr.deallocate()
                                    }
                                }
                            }

                            if compSize > 0 && compSize < rawData.count {
                                compressedData = payloadBuf
                            }
                        }

                        let crc: UInt32 = rawData.withUnsafeBytes { ptr -> UInt32 in
                            guard let base = ptr.baseAddress else { return 0 }
                            return ttzip_compute_buffer_crc32(base, rawData.count)
                        }

                        let processedChunk = ArchiveDataChunk(
                            chunkID: chunk.chunkID,
                            offset: chunk.offset,
                            data: compressedData,
                            isEOF: false,
                            crc32: crc,
                            metadata: ["originalSize": "\(rawData.count)"]
                        )

                        try await outputQueue.push(processedChunk)
                    }
                }
            }
            try await group.waitForAll()
        }
        outputQueue.finish()
    }
}

/// 顺序落盘写出消费者 (DiskWriteConsumer)
/// 保证多线程并发压缩产生的数据块严格无序错位，保序落盘写出
public final class DiskWriteConsumer: AsyncConsumerProtocol, @unchecked Sendable {
    private let outputPath: String
    public let maxReorderBufferCapacity: Int
    private let lock = NSLock()
    private var fileHandle: FileHandle?
    private var nextExpectedChunkID: Int64 = 0
    private var pendingChunks: [Int64: ArchiveDataChunk] = [:]
    private var waitingContinuations: [CheckedContinuation<Void, Error>] = []
    private var isCancelled: Bool = false
    private var cancelError: Error? = nil
    
    private var _totalWrittenBytes: Int64 = 0
    private var _totalChunksProcessed: Int64 = 0

    public var totalWrittenBytes: Int64 {
        lock.lock()
        defer { lock.unlock() }
        return _totalWrittenBytes
    }

    public var totalChunksProcessed: Int64 {
        lock.lock()
        defer { lock.unlock() }
        return _totalChunksProcessed
    }

    public var pendingChunksCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return pendingChunks.count
    }

    public init(outputPath: String, maxReorderBufferCapacity: Int = 64) throws {
        self.outputPath = outputPath
        self.maxReorderBufferCapacity = max(1, maxReorderBufferCapacity)
        let fm = FileManager.default
        try? fm.removeItem(atPath: outputPath)
        fm.createFile(atPath: outputPath, contents: nil)
        self.fileHandle = FileHandle(forWritingAtPath: outputPath)
    }

    deinit {
        try? fileHandle?.close()
    }

    private func checkCapacityAndRegisterContinuation(_ chunk: ArchiveDataChunk, continuation: CheckedContinuation<Void, Error>) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        if isCancelled {
            continuation.resume(throwing: cancelError ?? BoundedProducerConsumerQueue<ArchiveDataChunk>.QueueError.cancelled)
            return true
        }

        if pendingChunks.count >= maxReorderBufferCapacity && chunk.chunkID != nextExpectedChunkID {
            waitingContinuations.append(continuation)
            return true
        }

        return false
    }

    private func performSyncConsume(_ chunk: ArchiveDataChunk) throws -> [CheckedContinuation<Void, Error>] {
        lock.lock()
        defer { lock.unlock() }

        if isCancelled {
            throw cancelError ?? BoundedProducerConsumerQueue<ArchiveDataChunk>.QueueError.cancelled
        }

        pendingChunks[chunk.chunkID] = chunk

        // 顺序排空待写出 Chunk
        while let nextChunk = pendingChunks.removeValue(forKey: nextExpectedChunkID) {
            if !nextChunk.data.isEmpty, let handle = fileHandle {
                try handle.write(contentsOf: nextChunk.data)
                _totalWrittenBytes += Int64(nextChunk.data.count)
            }
            _totalChunksProcessed += 1
            nextExpectedChunkID += 1
        }

        // 当 nextExpectedChunkID 推进并清理缓冲区后，若 pendingChunks.count < maxReorderBufferCapacity，唤醒被挂起的 Continuation
        if pendingChunks.count < maxReorderBufferCapacity && !waitingContinuations.isEmpty {
            let toResume = waitingContinuations
            waitingContinuations.removeAll()
            return toResume
        }
        return []
    }

    private func handleConsumeError(_ error: Error) -> [CheckedContinuation<Void, Error>] {
        lock.lock()
        defer { lock.unlock() }
        isCancelled = true
        cancelError = error
        let toResume = waitingContinuations
        waitingContinuations.removeAll()
        return toResume
    }

    public func consume(_ chunk: ArchiveDataChunk) async throws {
        if chunk.isEOF {
            return
        }

        // 1. 容量上限检查：当缓冲区满且当前 chunk 不是紧接着需要的 nextExpectedChunkID 时，挂起等待背压释放
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let handled = checkCapacityAndRegisterContinuation(chunk, continuation: continuation)
            if !handled {
                continuation.resume()
            }
        }

        // 2. 写入 pendingChunks 并顺序排空落盘
        let continuationsToResume: [CheckedContinuation<Void, Error>]
        do {
            continuationsToResume = try performSyncConsume(chunk)
        } catch {
            let toResume = handleConsumeError(error)
            for c in toResume {
                c.resume(throwing: error)
            }
            throw error
        }

        for continuation in continuationsToResume {
            continuation.resume()
        }
    }

    /// 取消消费者并释放所有挂起的 Continuation
    public func cancel(error: Error? = nil) {
        lock.lock()
        if isCancelled {
            lock.unlock()
            return
        }
        isCancelled = true
        cancelError = error
        pendingChunks.removeAll()
        let toResume = waitingContinuations
        waitingContinuations.removeAll()
        lock.unlock()

        let err = error ?? BoundedProducerConsumerQueue<ArchiveDataChunk>.QueueError.cancelled
        for c in toResume {
            c.resume(throwing: err)
        }
    }

    /// 标记消费完成，刷盘关闭 Handle
    public func finish() throws {
        lock.lock()
        defer { lock.unlock() }
        if isCancelled { return }
        try fileHandle?.synchronize()
        try fileHandle?.close()
        fileHandle = nil
    }
}

/// 归档管道 Producer-Consumer 核心引擎 (ArchivePipelineProducerConsumerEngine)
public final class ArchivePipelineProducerConsumerEngine: Sendable {

    /// 管道执行统计报告
    public struct PipelineStats: Sendable, Equatable {
        public let totalOriginalBytes: Int64
        public let totalCompressedBytes: Int64
        public let totalChunksProcessed: Int64
        public let durationSeconds: Double
        public let throughputMBs: Double
    }

    public init() {}

    /// 贯穿运行 Full Producer-Consumer 管道
    public func processPipeline(
        inputPath: String,
        outputPath: String,
        chunkSize: Int = 64 * 1024,
        maxQueueCapacity: Int = 16,
        maxReorderBufferCapacity: Int = 64,
        workerCount: Int = max(2, ProcessInfo.processInfo.activeProcessorCount),
        level: ArchiveCompressionLevel = .normal
    ) async throws -> PipelineStats {
        let startTime = Date()
        let fm = FileManager.default
        let attr = try fm.attributesOfItem(atPath: inputPath)
        let totalOriginalBytes = (attr[.size] as? Int64) ?? 0

        let producer = try DiskReadProducer(filePath: inputPath, chunkSize: chunkSize)
        let consumer = try DiskWriteConsumer(outputPath: outputPath, maxReorderBufferCapacity: maxReorderBufferCapacity)

        let inputQueue = BoundedProducerConsumerQueue<ArchiveDataChunk>(maxCapacity: maxQueueCapacity)
        let outputQueue = BoundedProducerConsumerQueue<ArchiveDataChunk>(maxCapacity: maxQueueCapacity)

        let compressorGroup = CompressorConsumerGroup(workerCount: workerCount, compressionLevel: level)

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                // Task 1: 生产者 Task -> 从磁盘 Read 数据存入 inputQueue
                group.addTask {
                    do {
                        while let chunk = try await producer.produce() {
                            let isEOF = chunk.isEOF
                            try await inputQueue.push(chunk)
                            if isEOF { break }
                        }
                        inputQueue.finish()
                    } catch {
                        inputQueue.cancel(error: error)
                        outputQueue.cancel(error: error)
                        consumer.cancel(error: error)
                        throw error
                    }
                }

                // Task 2: 消费者组 Task -> 从 inputQueue 读取，多线程并行压缩，推入 outputQueue
                group.addTask {
                    do {
                        try await compressorGroup.startProcessing(inputQueue: inputQueue, outputQueue: outputQueue)
                    } catch {
                        inputQueue.cancel(error: error)
                        outputQueue.cancel(error: error)
                        consumer.cancel(error: error)
                        throw error
                    }
                }

                // Task 3: 磁盘落盘 Task -> 从 outputQueue 读取保序写入磁盘
                for _ in 0..<max(2, workerCount) {
                    group.addTask {
                        do {
                            while let chunk = try await outputQueue.pop() {
                                if chunk.isEOF { break }
                                try await consumer.consume(chunk)
                            }
                        } catch {
                            inputQueue.cancel(error: error)
                            outputQueue.cancel(error: error)
                            consumer.cancel(error: error)
                            throw error
                        }
                    }
                }

                try await group.waitForAll()
            }
            try consumer.finish()
        } catch {
            inputQueue.cancel(error: error)
            outputQueue.cancel(error: error)
            consumer.cancel(error: error)
            throw error
        }

        let elapsed = max(0.001, Date().timeIntervalSince(startTime))
        let throughput = (Double(totalOriginalBytes) / (1024 * 1024)) / elapsed

        return PipelineStats(
            totalOriginalBytes: totalOriginalBytes,
            totalCompressedBytes: consumer.totalWrittenBytes,
            totalChunksProcessed: consumer.totalChunksProcessed,
            durationSeconds: elapsed,
            throughputMBs: throughput
        )
    }
}

