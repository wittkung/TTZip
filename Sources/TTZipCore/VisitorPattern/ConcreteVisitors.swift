// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CryptoKit
import CTTZipBridge
import zlib

// MARK: - 1. Security Threat Data Models

public enum SecurityThreatLevel: String, Sendable, Equatable, CustomStringConvertible {
    case low = "LOW"
    case medium = "MEDIUM"
    case high = "HIGH"
    case critical = "CRITICAL"
    
    public var description: String { rawValue }
}

public enum SecurityThreatType: String, Sendable, Equatable {
    case zipSlip = "Zip Slip (Path Traversal)"
    case zipBomb = "Zip Bomb (High Compression Ratio)"
    case executableExtension = "Dangerous Executable Extension"
}

public struct SecurityThreat: Sendable, Equatable, Identifiable {
    public var id: String { "\(path)_\(type.rawValue)" }
    public let path: String
    public let type: SecurityThreatType
    public let level: SecurityThreatLevel
    public let detail: String
    
    public init(path: String, type: SecurityThreatType, level: SecurityThreatLevel, detail: String) {
        self.path = path
        self.type = type
        self.level = level
        self.detail = detail
    }
}

// MARK: - 2. SecurityScannerVisitor

/// Recursively scans composite tree for Zip Slip path traversal, Zip Bomb compression ratios, and dangerous executables.
public final class SecurityScannerVisitor: ArchiveComponentVisitorProtocol, @unchecked Sendable {
    public typealias Result = [SecurityThreat]
    
    public static let defaultDangerousExtensions: Set<String> = [
        "exe", "bat", "cmd", "vbs", "js", "scr", "pif", "sh", "command", "app", "dll", "dylib", "so", "ps1", "apk"
    ]
    
    private let dangerousExtensions: Set<String>
    private let maxCompressionRatio: Double
    
    public init(
        dangerousExtensions: Set<String> = SecurityScannerVisitor.defaultDangerousExtensions,
        maxCompressionRatio: Double = 100.0
    ) {
        self.dangerousExtensions = dangerousExtensions
        self.maxCompressionRatio = maxCompressionRatio
    }
    
    public func visit(leaf: ArchiveLeafFile) -> [SecurityThreat] {
        var threats: [SecurityThreat] = []
        let path = leaf.path
        let lowerPath = path.lowercased()
        
        // 1. Path Traversal / Zip Slip Check
        if lowerPath.contains("..") || lowerPath.hasPrefix("/") {
            threats.append(SecurityThreat(
                path: path,
                type: .zipSlip,
                level: .critical,
                detail: "Detected illegal path traversal attack (Zip Slip): \(path)"
            ))
        }
        
        // 2. Dangerous Executable Extension Check
        let ext = (leaf.name as NSString).pathExtension.lowercased()
        if dangerousExtensions.contains(ext) {
            threats.append(SecurityThreat(
                path: path,
                type: .executableExtension,
                level: .high,
                detail: "Detected dangerous executable script or binary extension: .\(ext)"
            ))
        }
        
        // 3. Zip Bomb Check
        let compressedSize = leaf.compressedSizeBytes ?? 0
        if compressedSize > 0 {
            let ratio = Double(leaf.sizeBytes) / Double(compressedSize)
            if ratio > maxCompressionRatio && leaf.sizeBytes > 1_000_000 {
                threats.append(SecurityThreat(
                    path: path,
                    type: .zipBomb,
                    level: .critical,
                    detail: "Detected suspected Zip Bomb risk (decompression ratio: \(String(format: "%.1f", ratio))x, uncompressed size: \(leaf.sizeBytes) bytes)"
                ))
            }
        }
        
        return threats
    }
    
    public func visit(directory: ArchiveCompositeDirectory) -> [SecurityThreat] {
        var threats: [SecurityThreat] = []
        let path = directory.path
        let lowerPath = path.lowercased()
        
        if lowerPath.contains("..") || lowerPath.hasPrefix("/") {
            threats.append(SecurityThreat(
                path: path,
                type: .zipSlip,
                level: .critical,
                detail: "Directory detected illegal path traversal attack (Zip Slip): \(path)"
            ))
        }
        
        for child in directory.getChildren() {
            threats.append(contentsOf: child.accept(visitor: self))
        }
        
        return threats
    }
}

// MARK: - 3. FolderStatsVisitor

public struct FolderStatsResult: Sendable, Equatable {
    public let totalFiles: Int
    public let totalDirectories: Int
    public let totalSizeBytes: Int64
    public let maxDepth: Int
    public let categoryDistribution: [(category: String, count: Int)]
    
    public init(
        totalFiles: Int,
        totalDirectories: Int,
        totalSizeBytes: Int64,
        maxDepth: Int,
        categoryDistribution: [(category: String, count: Int)] = []
    ) {
        self.totalFiles = totalFiles
        self.totalDirectories = totalDirectories
        self.totalSizeBytes = totalSizeBytes
        self.maxDepth = maxDepth
        self.categoryDistribution = categoryDistribution
    }
    
    public static func == (lhs: FolderStatsResult, rhs: FolderStatsResult) -> Bool {
        return lhs.totalFiles == rhs.totalFiles &&
               lhs.totalDirectories == rhs.totalDirectories &&
               lhs.totalSizeBytes == rhs.totalSizeBytes &&
               lhs.maxDepth == rhs.maxDepth
    }
}

/// Recursively aggregates metrics across composite trees (totalFiles, totalDirectories, totalSizeBytes, maxDepth).
public final class FolderStatsVisitor: ArchiveComponentVisitorProtocol, @unchecked Sendable {
    public typealias Result = FolderStatsResult
    
    public init() {}
    
    public func visit(leaf: ArchiveLeafFile) -> FolderStatsResult {
        let cat = categorize(filename: leaf.name)
        return FolderStatsResult(
            totalFiles: 1,
            totalDirectories: 0,
            totalSizeBytes: leaf.sizeBytes,
            maxDepth: 1,
            categoryDistribution: [(category: cat, count: 1)]
        )
    }
    
    public func visit(directory: ArchiveCompositeDirectory) -> FolderStatsResult {
        var files = 0
        var subfolders = 0
        var totalSize: Int64 = 0
        var maxChildDepth = 0
        var catMap: [String: Int] = [:]
        
        for child in directory.getChildren() {
            if child.isDirectory {
                subfolders += 1
            }
            let childStats = child.accept(visitor: self)
            files += childStats.totalFiles
            subfolders += childStats.totalDirectories
            totalSize += childStats.totalSizeBytes
            maxChildDepth = max(maxChildDepth, childStats.maxDepth)
            
            for (cat, count) in childStats.categoryDistribution {
                catMap[cat, default: 0] += count
            }
        }
        
        let sortedDist = catMap.map { (category: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
        
        return FolderStatsResult(
            totalFiles: files,
            totalDirectories: subfolders,
            totalSizeBytes: totalSize,
            maxDepth: 1 + maxChildDepth,
            categoryDistribution: sortedDist
        )
    }
    
    private func categorize(filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        if ["mp4", "mov", "webm", "mkv", "avi", "flv", "m4v", "ts", "3gp"].contains(ext) {
            return "Video"
        } else if ["mp3", "wav", "flac", "m4a", "aac", "ogg", "opus", "aiff"].contains(ext) {
            return "Audio"
        } else if ["png", "jpg", "jpeg", "webp", "gif", "svg", "heic"].contains(ext) {
            return "Image"
        } else if ["srt", "ass", "txt", "swift", "json", "md", "py", "c", "cpp", "vtt", "pdf"].contains(ext) {
            return "Document/Code"
        } else if ["zip", "7z", "rar", "tar", "gz", "zst", "bz2"].contains(ext) {
            return "Archive"
        } else {
            return "Other"
        }
    }
}

// MARK: - 4. ChecksumCalculatorVisitor

public struct ChecksumResult: Sendable, Equatable {
    public let crc32: UInt32
    public let crc32String: String
    public let sha256String: String
    public let processedFiles: Int
    public let totalSizeBytes: Int64
    
    public init(
        crc32: UInt32,
        crc32String: String,
        sha256String: String,
        processedFiles: Int,
        totalSizeBytes: Int64
    ) {
        self.crc32 = crc32
        self.crc32String = crc32String
        self.sha256String = sha256String
        self.processedFiles = processedFiles
        self.totalSizeBytes = totalSizeBytes
    }
}

/// Recursively computes aggregate composite tree checksums (CRC32 and SHA-256 signatures).
public final class ChecksumCalculatorVisitor: ArchiveComponentVisitorProtocol, @unchecked Sendable {
    public typealias Result = ChecksumResult
    
    public init() {}
    
    public func visit(leaf: ArchiveLeafFile) -> ChecksumResult {
        var crc: UInt32 = 0
        var shaData = Data()
        
        if let crcVal = leaf.crc32, crcVal != 0 {
            crc = crcVal
            var crcBig = crc.bigEndian
            shaData.append(Data(bytes: &crcBig, count: MemoryLayout<UInt32>.size))
            shaData.append(leaf.path.data(using: .utf8) ?? Data())
        } else if FileManager.default.fileExists(atPath: leaf.path) {
            let hashCalc = ArchiveEngineFactory.makeHashCalculator()
            if let crcStr = try? hashCalc.computeHashSync(filePath: leaf.path, type: .crc32),
               let crcVal = UInt32(crcStr, radix: 16) {
                crc = crcVal
            }
            if let shaStr = try? hashCalc.computeHashSync(filePath: leaf.path, type: .sha256) {
                shaData.append(shaStr.data(using: .utf8) ?? Data())
            }
        } else {
            let payload = "\(leaf.path)_\(leaf.sizeBytes)"
            let payloadData = payload.data(using: .utf8) ?? Data()
            crc = payloadData.withUnsafeBytes { buffer in
                guard let base = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return UInt32(0) }
                return ttzip_rust_crc32(0, base, buffer.count)
            }
            shaData.append(payloadData)
        }
        
        let sha256Digest = SHA256.hash(data: shaData)
        let sha256Str = sha256Digest.map { String(format: "%02x", $0) }.joined()
        let crcStr = String(format: "%08X", crc)
        
        return ChecksumResult(
            crc32: crc,
            crc32String: crcStr,
            sha256String: sha256Str,
            processedFiles: 1,
            totalSizeBytes: leaf.sizeBytes
        )
    }
    
    public func visit(directory: ArchiveCompositeDirectory) -> ChecksumResult {
        var combinedCRC: UInt32 = 0
        var combinedSHAHasher = SHA256()
        var totalFiles = 0
        var totalSize: Int64 = 0
        
        for child in directory.getChildren() {
            let childRes = child.accept(visitor: self)
            totalFiles += childRes.processedFiles
            totalSize += childRes.totalSizeBytes
            
            if childRes.totalSizeBytes > 0 {
                combinedCRC = UInt32(crc32_combine(uLong(combinedCRC), uLong(childRes.crc32), Int(childRes.totalSizeBytes)))
            } else {
                combinedCRC ^= childRes.crc32
            }
            
            if let shaData = childRes.sha256String.data(using: .utf8) {
                combinedSHAHasher.update(data: shaData)
            }
        }
        
        let finalDigest = combinedSHAHasher.finalize()
        let sha256Str = finalDigest.map { String(format: "%02x", $0) }.joined()
        let crcStr = String(format: "%08X", combinedCRC)
        
        return ChecksumResult(
            crc32: combinedCRC,
            crc32String: crcStr,
            sha256String: sha256Str,
            processedFiles: totalFiles,
            totalSizeBytes: totalSize
        )
    }
}

// MARK: - 5. TreeRendererVisitor

/// Formats composite directory tree into formatted ASCII tree text (`├── file.txt`, `└── folder/`).
public final class TreeRendererVisitor: ArchiveComponentVisitorProtocol, @unchecked Sendable {
    public typealias Result = String
    
    private let includeSize: Bool
    private let currentIndent: String
    private let isLast: Bool
    private let isRoot: Bool
    
    public init(includeSize: Bool = false) {
        self.includeSize = includeSize
        self.currentIndent = ""
        self.isLast = true
        self.isRoot = true
    }
    
    private init(includeSize: Bool, currentIndent: String, isLast: Bool, isRoot: Bool) {
        self.includeSize = includeSize
        self.currentIndent = currentIndent
        self.isLast = isLast
        self.isRoot = isRoot
    }
    
    public func visit(leaf: ArchiveLeafFile) -> String {
        let prefix = isRoot ? "" : (isLast ? "└── " : "├── ")
        let sizeInfo = includeSize ? " (\(formatBytes(leaf.sizeBytes)))" : ""
        return "\(currentIndent)\(prefix)\(leaf.name)\(sizeInfo)"
    }
    
    public func visit(directory: ArchiveCompositeDirectory) -> String {
        let nameStr = directory.name.isEmpty ? "." : directory.name
        let dirHeader: String
        if isRoot {
            dirHeader = "\(nameStr)/"
        } else {
            let prefix = isLast ? "└── " : "├── "
            dirHeader = "\(currentIndent)\(prefix)\(nameStr)/"
        }
        
        let children = directory.getChildren()
        if children.isEmpty {
            return dirHeader
        }
        
        let childIndent: String
        if isRoot {
            childIndent = ""
        } else {
            childIndent = currentIndent + (isLast ? "    " : "│   ")
        }
        
        var lines: [String] = [dirHeader]
        for (index, child) in children.enumerated() {
            let childIsLast = (index == children.count - 1)
            let childVisitor = TreeRendererVisitor(
                includeSize: includeSize,
                currentIndent: childIndent,
                isLast: childIsLast,
                isRoot: false
            )
            lines.append(child.accept(visitor: childVisitor))
        }
        
        return lines.joined(separator: "\n")
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        return ByteCountFormatterCache.string(fromByteCount: bytes)
    }
}
