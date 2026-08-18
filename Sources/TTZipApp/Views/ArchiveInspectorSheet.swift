// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import AppKit
import TTZipCore

/// Archive standards inspection and compliance diagnostics sheet.
public struct ArchiveInspectorSheet: View {
    @ObservedObject var viewModel: ArchiveInspectorViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: InspectorTab = .standards
    
    public enum InspectorTab: String, CaseIterable, Identifiable {
        case standards = "Standards"
        case magic = "Magic Anchors"
        case extraFields = "ZIP Extra Fields"
        case compliance = "Compliance"
        
        public var id: String { rawValue }
    }
    
    public init(viewModel: ArchiveInspectorViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            headerBar
            
            Divider()
                .background(TTZipTheme.kintsugiGold.opacity(0.3))
            
            Picker("", selection: $selectedTab) {
                ForEach(InspectorTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            
            Group {
                if viewModel.state.isScanning {
                    loadingView
                } else if let err = viewModel.state.errorMessage {
                    errorView(message: err)
                } else {
                    tabContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()
            
            footerBar
        }
        .frame(width: 680, height: 520)
        .background(TTZipTheme.paperWhite.opacity(0.98))
    }
    
    private var headerBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.badge.gearshape")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(TTZipTheme.archiveAmber)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Archive Standards & Diagnostics")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                Text(viewModel.state.fileName.isEmpty ? "No archive selected" : viewModel.state.fileName)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if !viewModel.state.isScanning {
                HStack(spacing: 6) {
                    Circle()
                        .fill(viewModel.state.complianceReport?.isCompliant == true ? TTZipTheme.bambooGreen : TTZipTheme.cinnabarRed)
                        .frame(width: 8, height: 8)
                    Text(viewModel.state.complianceReport?.isCompliant == true ? "Compliant" : "Deviations Found")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(viewModel.state.complianceReport?.isCompliant == true ? TTZipTheme.bambooGreen : TTZipTheme.cinnabarRed)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.primary.opacity(0.05)))
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 52)
    }
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.1)
            Text("Scanning archive structures and specifications...")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundColor(TTZipTheme.cinnabarRed)
            Text("Parse Error")
                .font(.system(size: 14, weight: .bold))
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    @ViewBuilder
    private var tabContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch selectedTab {
                case .standards:
                    standardsTabView
                case .magic:
                    magicTabView
                case .extraFields:
                    extraFieldsTabView
                case .compliance:
                    complianceTabView
                }
            }
            .padding(20)
        }
    }
    
    private var standardsTabView: some View {
        VStack(alignment: .leading, spacing: 14) {
            metadataRow(label: "Format", value: viewModel.state.detectedFormat?.displayName ?? "Unknown")
            metadataRow(label: "Specification", value: viewModel.state.standardSpec?.officialName ?? "N/A")
            metadataRow(label: "MIME Type", value: viewModel.state.standardSpec?.mimeType ?? "N/A")
            metadataRow(label: "Apple UTI", value: viewModel.state.standardSpec?.appleUTI ?? "N/A")
            
            if let citations = viewModel.state.standardSpec?.standardCitations, !citations.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Standard Citations (RFC / ISO / POSIX)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    ForEach(citations, id: \.standardNumber) { cit in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(cit.organization) \(cit.standardNumber): \(cit.title)")
                                    .font(.system(size: 12, weight: .medium))
                                if !cit.canonicalURL.isEmpty {
                                    Text(cit.canonicalURL)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.03)))
            }
        }
    }
    
    private var magicTabView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Multi-Anchor Signatures")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            
            if viewModel.state.signatureMatches.isEmpty {
                Text("No standard signatures matched.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            } else {
                ForEach(viewModel.state.signatureMatches, id: \.description) { sig in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(sig.description)
                                .font(.system(size: 12, weight: .bold))
                            Spacer()
                            Text("Verified")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(TTZipTheme.bambooGreen)
                        }
                        
                        let hexStr = sig.bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
                        Text("Signature Bytes: [ \(hexStr) ]")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.03)))
                }
            }
        }
    }
    
    private var extraFieldsTabView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ZIP TLV Extra Fields (Zero-Allocation TLV)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            
            if let extra = viewModel.state.parsedExtraFields {
                if let ts = extra.extendedTimestamp {
                    metadataRow(label: "Extended Timestamp (0x5455)", value: "\(ts)")
                }
                if let u = extra.unicodePath {
                    metadataRow(label: "Unicode Path (0x7075)", value: u)
                }
                if let p = extra.posixPermissions {
                    metadataRow(label: "Info-ZIP Permissions (0x7875)", value: "UID: \(p.uid), GID: \(p.gid)")
                }
                if let z64 = extra.zip64Info {
                    metadataRow(label: "Zip64 Extensions (0x0001)", value: "Uncompressed: \(z64.uncompressedSize ?? 0) B, Compressed: \(z64.compressedSize ?? 0) B")
                }
                if let aes = extra.winZipAES {
                    metadataRow(label: "WinZip AES (0x9901)", value: "Strength: \(aes.strength) bit, Method: \(aes.actualMethod)")
                }
            } else {
                Text("No extra fields found or format is non-ZIP.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var complianceTabView: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let report = viewModel.state.complianceReport {
                HStack(spacing: 8) {
                    Image(systemName: report.isCompliant ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(report.isCompliant ? TTZipTheme.bambooGreen : TTZipTheme.cinnabarRed)
                    Text(report.isCompliant ? "Specification Compliance: 100% Passed" : "Specification Deviations or Warnings Detected")
                        .font(.system(size: 13, weight: .bold))
                }
                
                if !report.validatedHeaders.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Validated Headers:")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        ForEach(report.validatedHeaders, id: \.self) { hdr in
                            Text("✓ \(hdr)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(TTZipTheme.bambooGreen)
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.03)))
                }
                
                if !report.violations.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Deviations / Warnings:")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(TTZipTheme.cinnabarRed)
                        ForEach(report.violations, id: \.self) { v in
                            Text("✗ \(v)")
                                .font(.system(size: 11))
                                .foregroundColor(TTZipTheme.cinnabarRed)
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 6).fill(TTZipTheme.cinnabarRed.opacity(0.08)))
                }
            } else {
                Text("No report available.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func metadataRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 140, alignment: .leading)
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)
            Spacer()
        }
    }
    
    private var footerBar: some View {
        HStack {
            Text("Diagnostic Time: \(String(format: "%.2f", viewModel.state.scanDurationMs)) ms")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .tint(TTZipTheme.bambooGreen)
        }
        .padding(.horizontal, 20)
        .frame(height: 48)
        .background(Color.primary.opacity(0.02))
    }
}

public struct ArchiveInspectorContainerView: View {
    let archivePath: String
    @StateObject private var viewModel = ArchiveInspectorViewModel()
    
    public init(archivePath: String) {
        self.archivePath = archivePath
    }
    
    public var body: some View {
        ArchiveInspectorSheet(viewModel: viewModel)
            .onAppear {
                viewModel.inspectArchive(atPath: archivePath)
            }
    }
}
