// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import TTZipCore
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Resolved action for handling file collisions.
public enum FileCollisionAction: Sendable {
    /// Overwrite the existing destination file.
    case overwrite
    /// Skip extracting or writing this entry.
    case skip
    /// Rename existing file with a `.bak` extension and overwrite.
    case backup
    /// Abort the entire extraction operation immediately.
    case abort
}

/// Thread-safe file collision and overwrite resolution engine.
///
/// Implements interactive TTY prompting, mtime comparison heuristics, backup generation,
/// and batch policy overrides during archive extraction.
public final class FileCollisionResolver: @unchecked Sendable {
    private var activePolicy: FileCollisionPolicy
    private let lock = NSLock()
    
    /// Initializes a resolver with the given base collision policy.
    /// - Parameter policy: Initial resolution policy (default: `.prompt`).
    public init(policy: FileCollisionPolicy = .prompt) {
        self.activePolicy = policy
    }
    
    /// Evaluates whether a destination file exists and determines the appropriate action.
    /// - Parameters:
    ///   - destinationPath: Absolute or relative destination filesystem path.
    ///   - entrySize: Uncompressed byte size of the incoming archive entry.
    ///   - entryMtime: Unix modification timestamp of the incoming archive entry.
    /// - Returns: Computed `FileCollisionAction`.
    public func resolveCollision(
        destinationPath: String,
        entrySize: Int64 = 0,
        entryMtime: Int64 = 0
    ) -> FileCollisionAction {
        lock.lock()
        defer { lock.unlock() }
        
        let fm = FileManager.default
        guard fm.fileExists(atPath: destinationPath) else {
            return .overwrite
        }
        
        switch activePolicy {
        case .always:
            return .overwrite
            
        case .never:
            return .skip
            
        case .backup:
            createBackupFile(at: destinationPath)
            return .overwrite
            
        case .newer:
            if let attrs = try? fm.attributesOfItem(atPath: destinationPath),
               let modDate = attrs[.modificationDate] as? Date {
                let existingMtime = Int64(modDate.timeIntervalSince1970)
                let existingSize = (attrs[.size] as? NSNumber)?.int64Value ?? 0
                if entryMtime > existingMtime || entrySize != existingSize {
                    return .overwrite
                } else {
                    return .skip
                }
            }
            return .overwrite
            
        case .prompt:
            // If running non-interactively without a TTY, default safely to overwrite
            if isatty(STDIN_FILENO) == 0 {
                return .overwrite
            }
            return promptUserOnTTY(destinationPath: destinationPath)
        }
    }
    
    private func createBackupFile(at targetPath: String) {
        let fm = FileManager.default
        let bakPath = "\(targetPath).bak"
        if fm.fileExists(atPath: bakPath) {
            let timestamp = Int(Date().timeIntervalSince1970)
            let uniqueBakPath = "\(targetPath).\(timestamp).bak"
            try? fm.moveItem(atPath: targetPath, toPath: uniqueBakPath)
        } else {
            try? fm.moveItem(atPath: targetPath, toPath: bakPath)
        }
    }
    
    private func promptUserOnTTY(destinationPath: String) -> FileCollisionAction {
        let baseName = (destinationPath as NSString).lastPathComponent
        guard let tty = fopen("/dev/tty", "r") else {
            return .overwrite
        }
        defer { fclose(tty) }
        
        FileHandle.standardError.write(
            Data("replace \(baseName)? [y]es, [n]o, [A]ll, [N]one, [b]ackup, [q]uit: ".utf8)
        )
        
        var charBuf = [CChar](repeating: 0, count: 64)
        if fgets(&charBuf, 64, tty) != nil {
            let resp = charBuf.withUnsafeBufferPointer { ptr in
                ptr.baseAddress.map { String(cString: $0) } ?? ""
            }.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            switch resp {

            case "y", "yes":
                return .overwrite
            case "n", "no":
                return .skip
            case "a", "all":
                activePolicy = .always
                return .overwrite
            case "none":
                activePolicy = .never
                return .skip
            case "b", "backup":
                createBackupFile(at: destinationPath)
                return .overwrite
            case "q", "quit":
                return .abort
            default:
                return .skip
            }
        }
        return .skip
    }
}
