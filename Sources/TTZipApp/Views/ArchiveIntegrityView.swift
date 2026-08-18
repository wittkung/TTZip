// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import TTZipCore

public struct ArchiveIntegrityView: View {
    public let archivePath: String
    @StateObject private var viewModel = ArchiveIntegrityViewModel()
    @Environment(\.dismiss) private var dismiss
    
    public init(archivePath: String) {
        self.archivePath = archivePath
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Archive Integrity Diagnostics")
                        .font(.title2.bold())
                    Text((archivePath as NSString).lastPathComponent)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.top)
            
            Divider()
            
            // Content State
            if viewModel.isVerifying {
                VStack(spacing: 12) {
                    ProgressView(value: viewModel.progressFraction)
                        .progressViewStyle(.linear)
                    HStack {
                        Text(viewModel.currentVerifyingEntry)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Text("\(Int(viewModel.progressFraction * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 30)
            } else if let report = viewModel.report {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Status Card
                        HStack {
                            Image(systemName: statusIcon(report.overallStatus))
                                .font(.title)
                                .foregroundColor(statusColor(report.overallStatus))
                            VStack(alignment: .leading) {
                                Text(statusTitle(report.overallStatus))
                                    .font(.headline)
                                Text("\(report.verifiedEntriesCount)/\(report.totalEntriesCount) entries verified · \(String(format: "%.1f MB/s", report.averageThroughputMBs)) · \(String(format: "%.2fs", report.verificationDurationSeconds))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                        
                        // Corrupted Entries breakdown if any
                        if !report.corruptedEntries.isEmpty {
                            Text("Damage Breakdown")
                                .font(.headline)
                            ForEach(report.corruptedEntries) { entry in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(entry.entryPath)
                                            .font(.subheadline.monospaced())
                                            .foregroundColor(.red)
                                        Spacer()
                                        Text(entry.errorType.rawValue)
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.red.opacity(0.15))
                                            .cornerRadius(4)
                                    }
                                    Text(entry.diagnosticMessage)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(8)
                                .background(Color(NSColor.windowBackgroundColor))
                                .cornerRadius(6)
                            }
                        }
                    }
                }
            } else if let err = viewModel.errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text("Verification Error")
                        .font(.headline)
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 30)
            }
            
            Spacer()
            
            // Actions
            HStack {
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button(viewModel.isVerifying ? "Verifying..." : "Verify Again") {
                    viewModel.startIntegrityCheck(archivePath: archivePath)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isVerifying)
            }
        }
        .padding()
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            viewModel.startIntegrityCheck(archivePath: archivePath)
        }
    }
    
    private func statusIcon(_ status: IntegrityStatus) -> String {
        switch status {
        case .passed: return "checkmark.circle.fill"
        case .corrupted: return "xmark.octagon.fill"
        case .unreadable: return "slash.circle.fill"
        case .encryptedMissingKey: return "lock.circle.fill"
        }
    }
    
    private func statusColor(_ status: IntegrityStatus) -> Color {
        switch status {
        case .passed: return .green
        case .corrupted: return .red
        case .unreadable: return .orange
        case .encryptedMissingKey: return .yellow
        }
    }
    
    private func statusTitle(_ status: IntegrityStatus) -> String {
        switch status {
        case .passed: return "Archive 100% Intact"
        case .corrupted: return "Archive Contains Corrupted Data"
        case .unreadable: return "Archive Header Damaged or Unreadable"
        case .encryptedMissingKey: return "Encrypted Content Requires Password"
        }
    }
}
