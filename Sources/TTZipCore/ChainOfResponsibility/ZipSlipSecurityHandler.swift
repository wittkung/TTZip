// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// Zip Slip, path traversal, and symlink escape security validation handler.
public final class ZipSlipSecurityHandler: BaseArchiveValidationHandler, @unchecked Sendable {
    public override init(nextHandler: ArchiveValidationHandlerProtocol? = nil) {
        super.init(nextHandler: nextHandler)
    }
    
    override public func process(context: ArchiveValidationContext) throws -> ArchiveValidationResult {
        for path in context.sourcePaths {
            if let error = checkPathSecurity(path) {
                return .failure(error)
            }
        }
        
        if let dest = context.destinationPath, !dest.isEmpty {
            if let error = checkPathSecurity(dest) {
                return .failure(error)
            }
            
            let destURL = URL(fileURLWithPath: dest)
            let resolvedDest = destURL.resolvingSymlinksInPath().path
            let standardizedDest = destURL.standardized.path
            
            if resolvedDest.contains("/../") || standardizedDest.contains("/../") || hasSymlinkEscapeToRoot(resolvedDest) {
                return .failure(.symlinkEscapeDetected(path: dest))
            }
        }
        
        return .success
    }
    
    private func checkPathSecurity(_ path: String) -> ArchiveValidationError? {
        if path.contains("\0") || path.lowercased().contains("%00") {
            return .zipSlipDetected(path: path, detail: "Null byte injection detected (\\0 or %00)")
        }
        
        var decoded = path
        var iterations = 0
        while iterations < 3, let next = decoded.removingPercentEncoding, next != decoded {
            decoded = next
            iterations += 1
        }
        
        if decoded.contains("\0") {
            return .zipSlipDetected(path: path, detail: "Null byte injection detected after URL decode (\\0)")
        }
        
        let normalized = decoded.replacingOccurrences(of: "\\", with: "/")
        
        if normalized.contains("../") || normalized.hasSuffix("/..") || normalized == ".." {
            return .zipSlipDetected(path: path, detail: "Path contains parent directory traversal component (../)")
        }
        let components = normalized.components(separatedBy: "/")
        if components.contains("..") {
            return .zipSlipDetected(path: path, detail: "Path hierarchy contains malformed traversal component (..)")
        }
        
        let lowerNormalized = normalized.lowercased()
        let sensitivePrefixes = ["/etc/", "/private/etc/", "/dev/", "/system/", "/var/root/", "/usr/bin/", "/usr/sbin/", "/bin/", "/sbin/"]
        let sensitiveExact = ["/etc/passwd", "/etc/shadow", "/etc/sudoers", "/private/etc/passwd", "/private/etc/shadow", "/private/etc/sudoers"]
        
        if sensitiveExact.contains(lowerNormalized) {
            return .zipSlipDetected(path: path, detail: "Attempted access to protected POSIX system file [\(path)]")
        }
        for prefix in sensitivePrefixes {
            if lowerNormalized.hasPrefix(prefix) {
                return .zipSlipDetected(path: path, detail: "Attempted access to protected system directory [\(prefix)]")
            }
        }
        
        return nil
    }
    
    private func hasSymlinkEscapeToRoot(_ resolvedPath: String) -> Bool {
        let lower = resolvedPath.lowercased()
        let protectedRoots = ["/etc", "/private/etc", "/dev", "/system", "/var/root", "/usr/bin", "/bin", "/sbin"]
        for root in protectedRoots {
            if lower == root || lower.hasPrefix(root + "/") {
                return true
            }
        }
        return false
    }
}
