import Foundation

/// 2. ZipSlip 安全拦截与 Path Traversal / Symlink 逃逸校验处理者 (ZipSlipSecurityHandler)
public final class ZipSlipSecurityHandler: BaseArchiveValidationHandler, @unchecked Sendable {
    public override init(nextHandler: ArchiveValidationHandlerProtocol? = nil) {
        super.init(nextHandler: nextHandler)
    }
    
    override public func process(context: ArchiveValidationContext) throws -> ArchiveValidationResult {
        // 1. 检查所有源路径是否存在 Path Traversal 危险字符或畸形逃逸
        for path in context.sourcePaths {
            if let error = checkPathSecurity(path) {
                return .failure(error)
            }
        }
        
        // 2. 检查目标输出路径与解压目录逃逸
        if let dest = context.destinationPath, !dest.isEmpty {
            if let error = checkPathSecurity(dest) {
                return .failure(error)
            }
            
            // 校验 Symlink 符号链接越界逃逸
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
        // 1. NUL 字节截断校验 (\0 或 %00)
        if path.contains("\0") || path.lowercased().contains("%00") {
            return .zipSlipDetected(path: path, detail: "安全拦截: 检测到 NUL 字节截断攻击 (\\0 或 %00)")
        }
        
        // 2. 多重 URL 编码解码与规范化
        var decoded = path
        var iterations = 0
        while iterations < 3, let next = decoded.removingPercentEncoding, next != decoded {
            decoded = next
            iterations += 1
        }
        
        // 重新校验解码后的 NUL 字节
        if decoded.contains("\0") {
            return .zipSlipDetected(path: path, detail: "安全拦截: URL 解码后检测到 NUL 字节截断攻击 (\\0)")
        }
        
        // 3. 统一分隔符为 POSIX /
        let normalized = decoded.replacingOccurrences(of: "\\", with: "/")
        
        // 4. Path Traversal (../ 或 ..\) 模式匹配
        if normalized.contains("../") || normalized.hasSuffix("/..") || normalized == ".." {
            return .zipSlipDetected(path: path, detail: "安全拦截: 路径包含相对父目录穿越符 (../ 或 ..\\)")
        }
        let components = normalized.components(separatedBy: "/")
        if components.contains("..") {
            return .zipSlipDetected(path: path, detail: "安全拦截: 路径层级包含畸形 .. 穿越组件")
        }
        
        // 5. POSIX 敏感系统根路径拦截
        let lowerNormalized = normalized.lowercased()
        let sensitivePrefixes = ["/etc/", "/private/etc/", "/dev/", "/system/", "/var/root/", "/usr/bin/", "/usr/sbin/", "/bin/", "/sbin/"]
        let sensitiveExact = ["/etc/passwd", "/etc/shadow", "/etc/sudoers", "/private/etc/passwd", "/private/etc/shadow", "/private/etc/sudoers"]
        
        if sensitiveExact.contains(lowerNormalized) {
            return .zipSlipDetected(path: path, detail: "安全拦截: 尝试访问/越界敏感 POSIX 系统文件 [\(path)]")
        }
        for prefix in sensitivePrefixes {
            if lowerNormalized.hasPrefix(prefix) {
                return .zipSlipDetected(path: path, detail: "安全拦截: 尝试越界写/读 POSIX 受保护系统根目录 [\(prefix)]")
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
