// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

final class ProducerConsumerPatternTests: XCTestCase {

    private var tempDirURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirURL = FileManager.default.temporaryDirectory.appendingPathComponent("ProducerConsumerTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let url = tempDirURL {
            try? FileManager.default.removeItem(at: url)
        }
        try super.tearDownWithError()
    }

    // MARK: - 1. Push / Pop / Finish

    func testBasicPushPopFinishLifecycle() async throws {
        let queue = BoundedProducerConsumerQueue<Int>(maxCapacity: 10)
        
        try await queue.push(10)
        try await queue.push(20)
        try await queue.push(30)
        
        XCTAssertEqual(queue.count, 3)
        
        let item1 = try await queue.pop()
        XCTAssertEqual(item1, 10)
        
        let item2 = try await queue.pop()
        XCTAssertEqual(item2, 20)
        
        let item3 = try await queue.pop()
        XCTAssertEqual(item3, 30)
        
        XCTAssertEqual(queue.count, 0)
        
        queue.finish()
        
        let itemEOF = try await queue.pop()
        XCTAssertNil(itemEOF)
        XCTAssertTrue(queue.isCompleted)
    }

    // MARK: - 2. maxCapacity = 5, 100

    func testBackpressureAndMemoryLimitCap() async throws {
        let queue = BoundedProducerConsumerQueue<Int>(maxCapacity: 5)
        let totalItems = 100
        
        let pushTask = Task {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for i in 0..<totalItems {
                    group.addTask {
                        try await queue.push(i)
                    }
                }
                try await group.waitForAll()
            }
            queue.finish()
        }
        
        // 100 Producer Tasks
        try await Task.sleep(nanoseconds: 50_000_000)
        
        // Count maxCapacity = 5 ，
        XCTAssertLessThanOrEqual(queue.count, 5)
        XCTAssertEqual(queue.pendingProducerCount, totalItems - 5)
        
        var poppedItems: [Int] = []
        while let item = try await queue.pop() {
            poppedItems.append(item)
        }
        
        try await pushTask.value
        
        XCTAssertEqual(poppedItems.count, totalItems)
        XCTAssertEqual(Set(poppedItems).count, totalItems)
        XCTAssertTrue(queue.isCompleted)
    }

    // MARK: - 3.

    func testMultiProducerMultiConsumerConcurrentThroughput() async throws {
        let queue = BoundedProducerConsumerQueue<Int>(maxCapacity: 16)
        let itemsPerProducer = 200
        let producerCount = 5
        let consumerCount = 5
        let totalExpectedItems = itemsPerProducer * producerCount
        
        let receivedItemsBox = LockProtectedArray<Int>()
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            // Consumers
            for _ in 0..<consumerCount {
                group.addTask {
                    while let item = try await queue.pop() {
                        receivedItemsBox.append(item)
                    }
                }
            }
            
            // Producers
            for pIndex in 0..<producerCount {
                group.addTask {
                    for i in 0..<itemsPerProducer {
                        let value = pIndex * itemsPerProducer + i
                        try await queue.push(value)
                    }
                }
            }
            
            // finish
            try await Task.sleep(nanoseconds: 100_000_000)
            queue.finish()
            
            try await group.waitForAll()
        }
        
        let results = receivedItemsBox.values
        XCTAssertEqual(results.count, totalExpectedItems)
        XCTAssertEqual(Set(results).count, totalExpectedItems)
    }

    // MARK: - 4. cancel

    func testCancelSignalFastPropagation() async throws {
        let queue = BoundedProducerConsumerQueue<Int>(maxCapacity: 1)
        try await queue.push(1)
        
        // Producer
        let producerTask = Task {
            try await queue.push(2)
        }
        
        // Empty Consumer
        let emptyQueue = BoundedProducerConsumerQueue<Int>(maxCapacity: 1)
        let consumerTask = Task {
            _ = try await emptyQueue.pop()
        }
        
        try await Task.sleep(nanoseconds: 30_000_000)
        
        // Cancel
        queue.cancel()
        emptyQueue.cancel()
        
        do {
            try await producerTask.value
            XCTFail("Producer Task should throw cancelled error")
        } catch {
            XCTAssertTrue(error is BoundedProducerConsumerQueue<Int>.QueueError)
        }
        
        do {
            _ = try await consumerTask.value
            XCTFail("Consumer Task should throw cancelled error")
        } catch {
            XCTAssertTrue(error is BoundedProducerConsumerQueue<Int>.QueueError)
        }
    }

    // MARK: - 5. 100+ Zero Deadlock

    func testHighConcurrency100TasksZeroDeadlock() async throws {
        let queue = BoundedProducerConsumerQueue<Int>(maxCapacity: 8)
        let taskCount = 100
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<taskCount {
                group.addTask {
                    if i % 2 == 0 {
                        try? await queue.push(i)
                    } else {
                        _ = try? await queue.pop()
                    }
                }
            }
            
            try await Task.sleep(nanoseconds: 50_000_000)
            queue.finish()
            
            for _ in 0..<taskCount {
                group.addTask {
                    _ = try? await queue.pop()
                }
            }
            
            try await group.waitForAll()
        }
        
        XCTAssertTrue(queue.isCompleted)
    }

    // MARK: - 6. ArchiveDataChunk EOF

    func testArchiveDataChunkInitializationAndEOF() {
        let chunk = ArchiveDataChunk(chunkID: 10, offset: 1024, data: Data([0x01, 0x02]), isEOF: false, crc32: 12345)
        XCTAssertEqual(chunk.chunkID, 10)
        XCTAssertEqual(chunk.id, 10)
        XCTAssertEqual(chunk.offset, 1024)
        XCTAssertEqual(chunk.data.count, 2)
        XCTAssertFalse(chunk.isEOF)
        XCTAssertEqual(chunk.crc32, 12345)

        let eofChunk = ArchiveDataChunk.eof(chunkID: 99)
        XCTAssertEqual(eofChunk.chunkID, 99)
        XCTAssertTrue(eofChunk.isEOF)
        XCTAssertTrue(eofChunk.data.isEmpty)
    }

    // MARK: - 7. DiskReadProducer MemoryPageFlyweightPool

    func testDiskReadProducerFlyweightPoolIntegration() async throws {
        let filePath = tempDirURL.appendingPathComponent("read_test.bin").path
        let testData = Data(repeating: 0xAB, count: 128 * 1024) // 128KB
        try testData.write(to: URL(fileURLWithPath: filePath))

        let producer = try DiskReadProducer(filePath: filePath, chunkSize: 64 * 1024)
        
        guard let chunk1 = try await producer.produce() else {
            XCTFail("Chunk 1 should not be nil")
            return
        }
        XCTAssertEqual(chunk1.chunkID, 0)
        XCTAssertEqual(chunk1.data.count, 64 * 1024)
        XCTAssertFalse(chunk1.isEOF)

        guard let chunk2 = try await producer.produce() else {
            XCTFail("Chunk 2 should not be nil")
            return
        }
        XCTAssertEqual(chunk2.chunkID, 1)
        XCTAssertEqual(chunk2.data.count, 64 * 1024)

        guard let eofChunk = try await producer.produce() else {
            XCTFail("EOF chunk should not be nil")
            return
        }
        XCTAssertTrue(eofChunk.isEOF)

        let nilChunk = try await producer.produce()
        XCTAssertNil(nilChunk)

        // MemoryPageFlyweightPool
        let stats = MemoryPageFlyweightPool.shared.poolStats
        XCTAssertGreaterThan(stats.borrowCount, 0)
    }

    // MARK: - 8. CompressorConsumerGroup

    func testCompressorConsumerGroupParallelCompression() async throws {
        let inputQueue = BoundedProducerConsumerQueue<ArchiveDataChunk>(maxCapacity: 10)
        let outputQueue = BoundedProducerConsumerQueue<ArchiveDataChunk>(maxCapacity: 10)
        
        let group = CompressorConsumerGroup(workerCount: 4, compressionLevel: .normal)

        let rawChunk = ArchiveDataChunk(
            chunkID: 0,
            offset: 0,
            data: Data(repeating: 0x41, count: 10 * 1024), // 10KB 易压缩重复数据
            isEOF: false
        )

        try await inputQueue.push(rawChunk)
        try await inputQueue.push(ArchiveDataChunk.eof(chunkID: 1))
        inputQueue.finish()

        try await group.startProcessing(inputQueue: inputQueue, outputQueue: outputQueue)

        var poppedChunks: [ArchiveDataChunk] = []
        while let chunk = try await outputQueue.pop() {
            poppedChunks.append(chunk)
        }

        guard let compressedChunk = poppedChunks.first(where: { $0.chunkID == 0 }) else {
            XCTFail("Compressed chunk with chunkID 0 should exist")
            return
        }

        XCTAssertEqual(compressedChunk.chunkID, 0)
        XCTAssertNotNil(compressedChunk.crc32)
        XCTAssertLessThan(compressedChunk.data.count, rawChunk.data.count) // 确认数据被压缩
    }

    // MARK: - 9. DiskWriteConsumer Chunk

    func testDiskWriteConsumerSequentialReordering() async throws {
        let outputPath = tempDirURL.appendingPathComponent("write_test.bin").path
        let consumer = try DiskWriteConsumer(outputPath: outputPath)

        let chunk1 = ArchiveDataChunk(chunkID: 1, offset: 10, data: Data("World".utf8))
        let chunk0 = ArchiveDataChunk(chunkID: 0, offset: 0, data: Data("Hello ".utf8))
        let chunk2 = ArchiveDataChunk(chunkID: 2, offset: 15, data: Data("!".utf8))

        // Chunk: 1 -> 0 -> 2
        try await consumer.consume(chunk1)
        XCTAssertEqual(consumer.totalWrittenBytes, 0) // 此时缺少 Chunk 0，无法写盘

        try await consumer.consume(chunk0)
        XCTAssertEqual(consumer.totalWrittenBytes, 11) // 触发 0 和 1 顺序写盘

        try await consumer.consume(chunk2)
        XCTAssertEqual(consumer.totalWrittenBytes, 12) // 触发 2 写盘

        try consumer.finish()

        let writtenData = try Data(contentsOf: URL(fileURLWithPath: outputPath))
        XCTAssertEqual(String(data: writtenData, encoding: .utf8), "Hello World!")
    }

    // MARK: - 10. ArchivePipelineProducerConsumerEngine

    func testEndToEndArchivePipelineEngine() async throws {
        let inputPath = tempDirURL.appendingPathComponent("pipeline_in.dat").path
        let outputPath = tempDirURL.appendingPathComponent("pipeline_out.bin").path

        let sampleData = Data(repeating: 0x55, count: 256 * 1024) // 256KB
        try sampleData.write(to: URL(fileURLWithPath: inputPath))

        let engine = ArchivePipelineProducerConsumerEngine()
        let stats = try await engine.processPipeline(
            inputPath: inputPath,
            outputPath: outputPath,
            chunkSize: 32 * 1024,
            maxQueueCapacity: 8,
            workerCount: 4,
            level: .normal
        )

        XCTAssertEqual(stats.totalOriginalBytes, 256 * 1024)
        XCTAssertGreaterThan(stats.totalCompressedBytes, 0)
        XCTAssertLessThan(stats.totalCompressedBytes, stats.totalOriginalBytes)
        XCTAssertGreaterThan(stats.throughputMBs, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputPath))
    }

    // MARK: - 12. ArchiveOperationPipeline -

    func testArchiveOperationPipelineIntegration() async throws {
        let inputPath = tempDirURL.appendingPathComponent("pipeline_op_in.txt").path
        let outputPath = tempDirURL.appendingPathComponent("pipeline_op_out.bin").path

        let textData = Data("Producer Consumer Pattern Integration Test".utf8)
        try textData.write(to: URL(fileURLWithPath: inputPath))

        let pipeline = ArchiveOperationPipeline()
        let stats = try await pipeline.createArchiveWithProducerConsumerEngine(
            inputPath: inputPath,
            outputPath: outputPath,
            maxQueueCapacity: 8
        )

        XCTAssertEqual(stats.totalOriginalBytes, Int64(textData.count))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputPath))
    }

    // MARK: - 13. Finish Push

    func testPushAfterFinishThrowsError() async throws {
        let queue = BoundedProducerConsumerQueue<Int>(maxCapacity: 5)
        queue.finish()

        do {
            try await queue.push(100)
            XCTFail("Pushing after finish should throw QueueError.finished")
        } catch {
            XCTAssertEqual(error as? BoundedProducerConsumerQueue<Int>.QueueError, .finished)
        }
    }

    // MARK: - 14. Finish Pop nil

    func testPopFinishedEmptyQueueReturnsNil() async throws {
        let queue = BoundedProducerConsumerQueue<String>(maxCapacity: 5)
        queue.finish()

        let item = try await queue.pop()
        XCTAssertNil(item)
    }

    // MARK: - 15. Cancel Error

    func testCancelWithCustomError() async throws {
        let queue = BoundedProducerConsumerQueue<Double>(maxCapacity: 2)
        let customErr = BoundedProducerConsumerQueue<Double>.QueueError.custom("Custom IO Failure")

        queue.cancel(error: customErr)

        do {
            try await queue.push(3.14)
            XCTFail("Pushing cancelled queue should throw custom error")
        } catch {
            XCTAssertEqual(error as? BoundedProducerConsumerQueue<Double>.QueueError, customErr)
        }
    }

    // MARK: - 16. 1

    func testSingleElementQueueCapacityBoundary() async throws {
        let queue = BoundedProducerConsumerQueue<Int>(maxCapacity: 1)
        
        try await queue.push(1)
        XCTAssertEqual(queue.count, 1)
        
        let producerTask = Task {
            try await queue.push(2)
        }
        
        try await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertEqual(queue.pendingProducerCount, 1)
        
        let val1 = try await queue.pop()
        XCTAssertEqual(val1, 1)
        
        try await producerTask.value
        
        let val2 = try await queue.pop()
        XCTAssertEqual(val2, 2)
    }

    // MARK: - 17. 50 + 50 Cancel

    func testConcurrentCancelResumesSuspendedProducersAndConsumers() async throws {
        let queue = BoundedProducerConsumerQueue<Int>(maxCapacity: 5)
        
        // Verify expected invariant
        for i in 0..<5 {
            try await queue.push(i)
        }
        
        let suspendedProducersCountBox = LockProtectedInt(0)
        let suspendedConsumersCountBox = LockProtectedInt(0)
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            // 50 Producer
            for i in 0..<50 {
                group.addTask {
                    do {
                        try await queue.push(100 + i)
                    } catch {
                        suspendedProducersCountBox.increment()
                    }
                }
            }
            
            // queue
            try await Task.sleep(nanoseconds: 50_000_000)
            queue.cancel()
            
            // 50 Cancel Consumer
            for _ in 0..<50 {
                group.addTask {
                    do {
                        _ = try await queue.pop()
                    } catch {
                        suspendedConsumersCountBox.increment()
                    }
                }
            }
            
            try await group.waitForAll()
        }
        
        XCTAssertEqual(suspendedProducersCountBox.value, 50)
        XCTAssertEqual(suspendedConsumersCountBox.value, 50)
    }

    // MARK: - 18. DiskWriteConsumer

    func testDiskWriteConsumerMaxReorderBufferCapacity() async throws {
        let outputPath = tempDirURL.appendingPathComponent("max_reorder_test.bin").path
        let maxCap = 5
        let consumer = try DiskWriteConsumer(outputPath: outputPath, maxReorderBufferCapacity: maxCap)

        // 1~5 Chunk ( Chunk 0)
        for i in 1...maxCap {
            let chunk = ArchiveDataChunk(chunkID: Int64(i), offset: Int64(i * 10), data: Data("Data \(i)".utf8))
            try await consumer.consume(chunk)
        }

        // 5 Chunk
        XCTAssertEqual(consumer.pendingChunksCount, maxCap)

        let isConsumerSuspendedBox = LockProtectedInt(0)
        let isConsumerFinishedBox = LockProtectedInt(0)

        // Task Chunk 6 ( )， Continuation
        let overflowTask = Task {
            isConsumerSuspendedBox.increment()
            let chunk6 = ArchiveDataChunk(chunkID: 6, offset: 60, data: Data("Data 6".utf8))
            try await consumer.consume(chunk6)
            isConsumerFinishedBox.increment()
        }

        try await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertEqual(isConsumerSuspendedBox.value, 1)
        XCTAssertEqual(isConsumerFinishedBox.value, 0) // overflowTask 仍挂起在 Continuation 中

        // Chunk 0 nextExpectedChunkID
        let chunk0 = ArchiveDataChunk(chunkID: 0, offset: 0, data: Data("Data 0".utf8))
        try await consumer.consume(chunk0)

        try await overflowTask.value

        XCTAssertEqual(isConsumerFinishedBox.value, 1) // overflowTask 成功唤醒并完成
        XCTAssertEqual(consumer.pendingChunksCount, 0) // 缓冲区已全部清空

        try consumer.finish()

        let writtenData = try Data(contentsOf: URL(fileURLWithPath: outputPath))
        let writtenString = String(data: writtenData, encoding: .utf8)
        XCTAssertEqual(writtenString, "Data 0Data 1Data 2Data 3Data 4Data 5Data 6")
    }

    // MARK: - 19. TaskGroup Cancel

    func testArchivePipelineEngineErrorCancellationPropagation() async throws {
        let inputPath = tempDirURL.appendingPathComponent("pipeline_err_in.dat").path
        let outputPath = tempDirURL.appendingPathComponent("pipeline_err_out.bin").path

        let sampleData = Data(repeating: 0x42, count: 64 * 1024)
        try sampleData.write(to: URL(fileURLWithPath: inputPath))

        // Producer/Compressor
        // inputPath DiskReadProducer produce FileHandle
        try FileManager.default.removeItem(atPath: inputPath)

        let engine = ArchivePipelineProducerConsumerEngine()
        do {
            _ = try await engine.processPipeline(
                inputPath: inputPath,
                outputPath: outputPath,
                chunkSize: 4096,
                maxQueueCapacity: 4
            )
            XCTFail("Should throw error due to missing input file")
        } catch {
            // ， Task
            XCTAssertNotNil(error)
        }
    }
}

// MARK: - Thread-Safe Helper Utilities for Tests

private final class LockProtectedArray<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var array: [T] = []

    func append(_ element: T) {
        lock.lock()
        defer { lock.unlock() }
        array.append(element)
    }

    var values: [T] {
        lock.lock()
        defer { lock.unlock() }
        return array
    }
}

private final class LockProtectedInt: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: Int

    init(_ value: Int) {
        self._value = value
    }

    func increment() {
        lock.lock()
        defer { lock.unlock() }
        _value += 1
    }

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }
}
