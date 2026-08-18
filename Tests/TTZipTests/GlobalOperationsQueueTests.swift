// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore

private actor TestOrderCollector {
    var executionOrder: [String] = []
    func append(_ val: String) {
        executionOrder.append(val)
    }
    func getOrder() -> [String] {
        return executionOrder
    }
}

final class GlobalOperationsQueueTests: XCTestCase {
    
    func testQueueEnqueueAndExecute() async throws {
        let queue = GlobalOperationsQueue(maxConcurrentTasks: 2)
        
        let expectation1 = expectation(description: "Task 1 executed")
        let expectation2 = expectation(description: "Task 2 executed")
        
        let id1 = await queue.enqueue(name: "Compress Document A", operationType: .compress) {
            try? await Task.sleep(nanoseconds: 20_000_000)
            expectation1.fulfill()
        }
        
        let id2 = await queue.enqueue(name: "Extract Archive B", operationType: .extract) {
            try? await Task.sleep(nanoseconds: 20_000_000)
            expectation2.fulfill()
        }
        
        XCTAssertNotEqual(id1, id2)
        await fulfillment(of: [expectation1, expectation2], timeout: 5.0)
        
        let tasks = await queue.getAllTasks()
        XCTAssertEqual(tasks.count, 2)
        XCTAssertTrue(tasks.allSatisfy { $0.state == .completed })
    }
    
    func testQueuePriorityOrdering() async throws {
        let queue = GlobalOperationsQueue(maxConcurrentTasks: 1)
        let collector = TestOrderCollector()
        
        let blockerExp = expectation(description: "Blocker executed")
        let exp1 = expectation(description: "Low Priority executed")
        let exp2 = expectation(description: "High Priority executed")
        
        // 1. Occupy the single worker with blocker task
        await queue.enqueue(name: "Blocker", operationType: .compress) {
            try? await Task.sleep(nanoseconds: 50_000_000)
            blockerExp.fulfill()
        }
        
        // 2. Enqueue background task (goes into pending queue)
        await queue.enqueue(name: "Background Job", operationType: .compress, priority: .background) {
            await collector.append("background")
            exp1.fulfill()
        }
        
        // 3. Enqueue critical task (should be prioritized ahead of background task)
        await queue.enqueue(name: "Critical Job", operationType: .extract, priority: .critical) {
            await collector.append("critical")
            exp2.fulfill()
        }
        
        await fulfillment(of: [blockerExp, exp2, exp1], timeout: 5.0)
        
        let finalOrder = await collector.getOrder()
        XCTAssertEqual(finalOrder, ["critical", "background"], "Critical task must execute before background task in pending queue")
    }
    
    func testQueueCancellation() async throws {
        let queue = GlobalOperationsQueue(maxConcurrentTasks: 1)
        
        let blockExpectation = expectation(description: "Block task executed")
        
        // 1. Block the queue with a slow task
        _ = await queue.enqueue(name: "Slow Task", operationType: .compress) {
            try? await Task.sleep(nanoseconds: 100_000_000)
            blockExpectation.fulfill()
        }
        
        // 2. Enqueue pending task
        let pendingId = await queue.enqueue(name: "Task to cancel", operationType: .extract) {
            XCTFail("Cancelled task should not execute")
        }
        
        // 3. Cancel pending task
        await queue.cancel(taskId: pendingId)
        
        await fulfillment(of: [blockExpectation], timeout: 5.0)
        
        let allTasks = await queue.getAllTasks()
        if let cancelledOp = allTasks.first(where: { $0.id == pendingId }) {
            XCTAssertEqual(cancelledOp.state, .cancelled)
        }
    }
}
