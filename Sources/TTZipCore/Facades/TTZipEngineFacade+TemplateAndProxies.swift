// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

// MARK: - 【2.7 代理模式 (Proxy Pattern)】代理通道集成

extension TTZipEngineFacade {
    /// 开启安全保护代理 (Protection Proxy) 进行极速压缩/解压校验
    public var protected: SecurityProtectionProxy {
        SecurityProtectionProxy.shared
    }
    
    /// 开启热缓存代理 (Cache Proxy) 查询归档条目与结构
    public var cached: ArchiveInspectionCacheProxy {
        ArchiveInspectionCacheProxy.shared
    }
    
    /// 开启智能日志与并发审计代理 (Smart Logging Proxy)
    public var logged: SmartLoggingProxy {
        SmartLoggingProxy.shared
    }
    
    /// 热数据缓存版 inspectArchive API
    public func inspectArchiveCached(
        archivePath: String,
        password: String? = nil,
        autoVaultUnlock: Bool = true
    ) async throws -> ArchiveInspectionResult {
        return try await ArchiveInspectionCacheProxy.shared.inspectArchive(
            archivePath: archivePath,
            password: password,
            autoVaultUnlock: autoVaultUnlock
        )
    }
}
