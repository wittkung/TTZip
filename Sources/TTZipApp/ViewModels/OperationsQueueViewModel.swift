// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import SwiftUI
import TTZipCore

@MainActor
public final class OperationsQueueViewModel: ObservableObject {
    @Published public var tasks: [QueuedArchiveOperation] = []
    @Published public var activeTasksCount: Int = 0
    @Published public var overallProgress: Double = 0.0
    @Published public var overallThroughputMBs: Double = 0.0
    
    private var eventTask: Task<Void, Never>?
    
    public init() {
        startListeningToQueue()
    }
    
    deinit {
        eventTask?.cancel()
    }
    
    public func startListeningToQueue() {
        eventTask?.cancel()
        eventTask = Task { [weak self] in
            let stream = await GlobalOperationsQueue.shared.observeEvents()
            for await _ in stream {
                guard let self = self else { break }
                await self.refreshState()
            }
        }
    }
    
    public func refreshState() async {
        let allTasks = await GlobalOperationsQueue.shared.getAllTasks()
        self.tasks = allTasks
        
        let running = allTasks.filter { $0.state == .running }
        self.activeTasksCount = running.count
        
        if running.isEmpty {
            self.overallProgress = 0.0
            self.overallThroughputMBs = 0.0
            DockProgressManager.shared.clearProgress()
        } else {
            let totalBytes = running.reduce(0) { $0 + $1.totalBytes }
            let processedBytes = running.reduce(0) { $0 + $1.bytesProcessed }
            let fraction = totalBytes > 0 ? Double(processedBytes) / Double(totalBytes) : 0.0
            self.overallProgress = fraction
            self.overallThroughputMBs = running.reduce(0.0) { $0 + $1.throughputMBs }
            DockProgressManager.shared.updateProgress(fraction: fraction, activeCount: running.count)
        }
    }
    
    public func cancelTask(id: UUID) {
        Task {
            await GlobalOperationsQueue.shared.cancel(taskId: id)
            await refreshState()
        }
    }
}
