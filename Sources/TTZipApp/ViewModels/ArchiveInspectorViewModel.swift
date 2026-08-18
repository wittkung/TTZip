// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import SwiftUI
import TTZipCore

/// Thread-safe in-memory cache for archive diagnostics snapshots.
public final class ArchiveDiagnosticsCache: @unchecked Sendable {
    public static let shared = ArchiveDiagnosticsCache()
    
    private let lock = NSLock()
    private var cache: [ArchiveDiagnosticsCacheKey: ArchiveInspectorState] = [:]
    
    private init() {}
    
    public func get(key: ArchiveDiagnosticsCacheKey) -> ArchiveInspectorState? {
        lock.lock()
        defer { lock.unlock() }
        return cache[key]
    }
    
    public func set(key: ArchiveDiagnosticsCacheKey, state: ArchiveInspectorState) {
        lock.lock()
        defer { lock.unlock() }
        if cache.count > 256 {
            cache.removeAll(keepingCapacity: true)
        }
        cache[key] = state
    }
    
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAll()
    }
}

/// Archive inspection and standards compliance diagnostic ViewModel.
@MainActor
public final class ArchiveInspectorViewModel: ObservableObject {
    @Published public var state: ArchiveInspectorState = ArchiveInspectorState(
        filePath: "",
        fileName: "",
        fileByteSize: 0,
        detectedFormat: nil,
        standardSpec: nil,
        signatureMatches: [],
        parsedExtraFields: nil,
        complianceReport: nil,
        isScanning: false,
        scanDurationMs: 0.0,
        errorMessage: nil
    )
    
    private var currentTask: Task<Void, Never>? = nil
    
    public init() {}
    
    /// Asynchronously performs non-blocking archive attribute and standards compliance scan.
    public func inspectArchive(atPath path: String) {
        guard !path.isEmpty else { return }
        
        currentTask?.cancel()
        
        let url = URL(fileURLWithPath: path)
        let fileName = url.lastPathComponent
        
        var size: Int64 = 0
        var mtime: Double = 0.0
        if let attrs = try? FileManager.default.attributesOfItem(atPath: path) {
            size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
            mtime = (attrs[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0.0
        }
        
        let cacheKey = ArchiveDiagnosticsCacheKey(
            filePath: path,
            fileByteSize: size,
            modificationTimestamp: mtime
        )
        
        if let cached = ArchiveDiagnosticsCache.shared.get(key: cacheKey) {
            self.state = cached
            return
        }
        
        self.state = ArchiveInspectorState(
            filePath: path,
            fileName: fileName,
            fileByteSize: size,
            detectedFormat: nil,
            standardSpec: nil,
            signatureMatches: [],
            parsedExtraFields: nil,
            complianceReport: nil,
            isScanning: true,
            scanDurationMs: 0.0,
            errorMessage: nil
        )
        
        currentTask = Task.detached(priority: .userInitiated) { [weak self] in
            let start = DispatchTime.now().uptimeNanoseconds
            
            var detectedFormat: ArchiveCompressionFormat? = nil
            var spec: ArchiveFormatStandardSpec? = nil
            var matchedSigs: [ArchiveMagicSignature] = []
            var extraFields: ParsedZipExtraFields? = nil
            var report: StandardsComplianceReport? = nil
            var errorMsg: String? = nil
            
            do {
                detectedFormat = try ArchiveMagicSignatureScanner.detectFormat(fileURL: url)
                if let fmt = detectedFormat {
                    spec = ArchiveFormatStandardRegistry.shared.spec(for: fmt)
                    if let s = spec {
                        matchedSigs = s.magicSignatures
                    }
                }
                
                report = try StandardsComplianceChecker.checkCompliance(fileURL: url, expectedFormat: detectedFormat)
                
                if detectedFormat == .zip, let handle = try? FileHandle(forReadingFrom: url) {
                    defer { try? handle.close() }
                    let headerData = handle.readData(ofLength: 1024)
                    headerData.withUnsafeBytes { rawPtr in
                        if rawPtr.count > 30 {
                            let extraSlice = UnsafeRawBufferPointer(rebasing: rawPtr[30...])
                            extraFields = ZipExtraFieldParser.parse(extraData: extraSlice)
                        }
                    }
                }
            } catch {
                errorMsg = error.localizedDescription
            }
            
            let elapsedNanos = DispatchTime.now().uptimeNanoseconds - start
            let durationMs = Double(elapsedNanos) / 1_000_000.0
            
            let finalState = ArchiveInspectorState(
                filePath: path,
                fileName: fileName,
                fileByteSize: size,
                detectedFormat: detectedFormat,
                standardSpec: spec,
                signatureMatches: matchedSigs,
                parsedExtraFields: extraFields,
                complianceReport: report,
                isScanning: false,
                scanDurationMs: durationMs,
                errorMessage: errorMsg
            )
            
            ArchiveDiagnosticsCache.shared.set(key: cacheKey, state: finalState)
            
            await MainActor.run {
                guard let self = self, !Task.isCancelled else { return }
                self.state = finalState
            }
        }
    }
}
