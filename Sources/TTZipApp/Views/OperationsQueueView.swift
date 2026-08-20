// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import TTZipCore

/// Real-time multi-task operations management window with live throughput telemetry and controls.
public struct OperationsQueueView: View {
    @ObservedObject private var l10n = AppLocalizationState.shared
    @StateObject private var viewModel = OperationsQueueViewModel()
    @Environment(\.dismiss) private var dismiss
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 16) {
            // Header Stats
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(l10n.t(L10n.Queue.title))
                        .font(.title2.bold())
                    Text("\(viewModel.activeTasksCount) " + l10n.t(L10n.Queue.activeTasks) + " · " + l10n.formatThroughput(viewModel.overallThroughputMBs))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                if viewModel.activeTasksCount > 0 {
                    ProgressView(value: viewModel.overallProgress)
                        .progressViewStyle(.circular)
                        .scaleEffect(0.7)
                }
            }
            .padding(.top)
            
            Divider()
            
            // Task List
            if viewModel.tasks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text(l10n.t(L10n.Queue.emptyQueue))
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.tasks) { task in
                            TaskRowView(task: task) {
                                viewModel.cancelTask(id: task.id)
                            }
                        }
                    }
                }
            }
            
            Divider()
            
            HStack {
                Spacer()
                Button(l10n.t(L10n.Common.close)) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding()
        .frame(minWidth: 550, minHeight: 400)
    }
}

private struct TaskRowView: View {
    let task: QueuedArchiveOperation
    let onCancel: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: operationIcon(task.operationType))
                .font(.title2)
                .foregroundColor(stateColor(task.state))
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(task.name)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text(task.state.rawValue.uppercased())
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(stateColor(task.state).opacity(0.15))
                        .foregroundColor(stateColor(task.state))
                        .cornerRadius(4)
                }
                
                if task.state == .running {
                    ProgressView(value: task.fractionCompleted)
                        .progressViewStyle(.linear)
                    
                    HStack {
                        let processedStr = ByteCountFormatter.string(fromByteCount: task.bytesProcessed, countStyle: .file)
                        let totalStr = ByteCountFormatter.string(fromByteCount: task.totalBytes, countStyle: .file)
                        Text("\(processedStr) / \(totalStr)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.1f MB/s", task.throughputMBs))
                            .font(.caption2.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                } else if let err = task.errorMessage {
                    Text(err)
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }
            
            if task.state == .running || task.state == .queued {
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Cancel task")
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private func operationIcon(_ type: ArchiveOperationType) -> String {
        switch type {
        case .compress, .batch: return "archivebox.fill"
        case .extract: return "doc.zipper"
        case .repair, .recover: return "wrench.and.screwdriver.fill"
        case .inspect: return "magnifyingglass"
        }
    }
    
    private func stateColor(_ state: ArchiveTaskExecutionState) -> Color {
        switch state {
        case .queued: return .secondary
        case .running: return .blue
        case .paused: return .orange
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .gray
        }
    }
}
