// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - Security Threat Data Models

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

// MARK: - SecurityScannerVisitor

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
