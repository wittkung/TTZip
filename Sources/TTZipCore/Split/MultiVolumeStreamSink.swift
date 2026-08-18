// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// In-stream zero-copy multi-volume split archive writer sink.
///
/// Intercepts archive byte streams in real time at byte-level accuracy, seamlessly closing
/// the active volume and opening subsequent volume files without double disk buffering.
public final class MultiVolumeStreamSink: @unchecked Sendable {
    public let baseOutputPath: String
    public let volumeSizeBytes: Int64
    public let namingPattern: VolumeNamingPattern
    public let cleanOnFailure: Bool
    
    private var currentVolumeIndex: Int = 1
    private var bytesWrittenInCurrentVolume: Int64 = 0
    private var totalBytesWritten: Int64 = 0
    private var activeFileHandle: FileHandle?
    private var activeVolumePath: String?
    private var generatedVolumePaths: [String] = []
    private let lock = NSLock()
    private var isClosed = false
    
    public init(
        baseOutputPath: String,
        volumeSizeBytes: Int64,
        namingPattern: VolumeNamingPattern = .numberedExtension,
        cleanOnFailure: Bool = true
    ) throws {
        guard volumeSizeBytes >= 65536 else {
            throw ArchiveError.invalidFormat
        }
        self.baseOutputPath = baseOutputPath
        self.volumeSizeBytes = volumeSizeBytes
        self.namingPattern = namingPattern
        self.cleanOnFailure = cleanOnFailure
        
        try openVolume(index: 1)
    }
    
    /// Writes a data buffer across volume boundaries.
    public func write(data: Data) throws {
        try data.withUnsafeBytes { rawBuffer in
            try write(buffer: rawBuffer)
        }
    }
    
    /// Writes raw byte buffer across volume boundaries with zero intermediate allocations.
    public func write(buffer: UnsafeRawBufferPointer) throws {
        lock.lock()
        defer { lock.unlock() }
        
        guard !isClosed, let basePtr = buffer.baseAddress else { return }
        var bytesRemaining = buffer.count
        var currentOffset = 0
        
        while bytesRemaining > 0 {
            guard let handle = activeFileHandle else {
                throw ArchiveError.readFailed(code: -1)
            }
            
            let spaceInCurrent = volumeSizeBytes - bytesWrittenInCurrentVolume
            let bytesToWrite = min(Int(spaceInCurrent), bytesRemaining)
            
            if bytesToWrite > 0 {
                let chunkData = Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: basePtr.advanced(by: currentOffset)), count: bytesToWrite, deallocator: .none)
                try handle.write(contentsOf: chunkData)
                bytesWrittenInCurrentVolume += Int64(bytesToWrite)
                totalBytesWritten += Int64(bytesToWrite)
                currentOffset += bytesToWrite
                bytesRemaining -= bytesToWrite
            }
            
            if bytesWrittenInCurrentVolume >= volumeSizeBytes && bytesRemaining > 0 {
                try rotateToNextVolume()
            }
        }
    }
    
    private func openVolume(index: Int) throws {
        let path = volumePath(for: index)
        let fm = FileManager.default
        if fm.fileExists(atPath: path) {
            try? fm.removeItem(atPath: path)
        }
        fm.createFile(atPath: path, contents: nil)
        let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: path))
        self.activeFileHandle = handle
        self.activeVolumePath = path
        self.currentVolumeIndex = index
        self.bytesWrittenInCurrentVolume = 0
        self.generatedVolumePaths.append(path)
    }
    
    private func rotateToNextVolume() throws {
        try activeFileHandle?.close()
        activeFileHandle = nil
        try openVolume(index: currentVolumeIndex + 1)
    }
    
    /// Computes volume file path for the given 1-based index according to the naming pattern.
    public func volumePath(for index: Int) -> String {
        switch namingPattern {
        case .numberedExtension:
            // Standard: archive.7z.001, archive.zip.001, archive.tar.001
            return String(format: "%@.%03d", baseOutputPath, index)
            
        case .pkzipSpanned:
            // PKZIP standard: archive.z01, archive.z02, ... archive.zip (final part renamed on close)
            let baseWithoutExt = (baseOutputPath as NSString).deletingPathExtension
            return String(format: "%@.z%02d", baseWithoutExt, index)
            
        case .rawSplit:
            // Raw split: archive.001, archive.002
            return String(format: "%@.%03d", baseOutputPath, index)
        }
    }
    
    /// Flushes and closes all volume handles, returning the complete list of generated volume paths.
    @discardableResult
    public func close() throws -> [String] {
        lock.lock()
        defer { lock.unlock() }
        
        guard !isClosed else { return generatedVolumePaths }
        isClosed = true
        
        try activeFileHandle?.close()
        activeFileHandle = nil
        
        // For PKZIP spanned format, the last volume should be named base.zip
        if namingPattern == .pkzipSpanned && !generatedVolumePaths.isEmpty {
            let lastPath = generatedVolumePaths.removeLast()
            let finalZipPath = baseOutputPath
            let fm = FileManager.default
            if fm.fileExists(atPath: finalZipPath) {
                try? fm.removeItem(atPath: finalZipPath)
            }
            try fm.moveItem(atPath: lastPath, toPath: finalZipPath)
            generatedVolumePaths.append(finalZipPath)
        }
        
        return generatedVolumePaths
    }
    
    /// Purges all generated volumes in the event of an archive failure.
    public func cancelAndCleanup() {
        lock.lock()
        defer { lock.unlock() }
        
        isClosed = true
        try? activeFileHandle?.close()
        activeFileHandle = nil
        
        if cleanOnFailure {
            let fm = FileManager.default
            for path in generatedVolumePaths {
                try? fm.removeItem(atPath: path)
            }
        }
        generatedVolumePaths.removeAll()
    }
    
    deinit {
        try? activeFileHandle?.close()
    }
}
