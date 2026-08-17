// SPDX-License-Identifier: BSD-3-Clause
//
// Copyright (c) 2026, Weitao Kung (Witt Kung) <kevintungs@163.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

/// 异步分块文件过滤清单加载器 (Asynchronous File Filter Manifest Loader)
public enum FileFilterListLoader: Sendable {
    
    /// 从文件路径或标准输入加载过滤路径清单
    /// - Parameters:
    ///   - filePath: 文件路径（支持 "-" 代表标准输入）
    ///   - nullDelimiter: 是否采用 \0 空字符分隔（--null / -0）
    /// - Returns: 解析后的非空路径字符串数组
    public static func loadPaths(from filePath: String, nullDelimiter: Bool = false) async throws -> [String] {
        let trimmedPath = filePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else { return [] }
        
        let handle: FileHandle
        let shouldClose: Bool
        
        if StreamPipeAdapter.isStandardStream(trimmedPath) {
            handle = FileHandle.standardInput
            shouldClose = false
        } else {
            guard FileManager.default.fileExists(atPath: trimmedPath) else {
                throw NSError(
                    domain: "TTZipFileFilterList",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Filter manifest file not found: \(trimmedPath)"]
                )
            }
            guard let fileHandle = FileHandle(forReadingAtPath: trimmedPath) else {
                throw NSError(
                    domain: "TTZipFileFilterList",
                    code: 13,
                    userInfo: [NSLocalizedDescriptionKey: "Cannot open filter manifest file: \(trimmedPath)"]
                )
            }
            handle = fileHandle
            shouldClose = true
        }
        
        defer {
            if shouldClose {
                try? handle.close()
            }
        }
        
        var results: [String] = []
        results.reserveCapacity(512)
        
        if nullDelimiter {
            // NUL-delimited 分隔读取
            let data = handle.readDataToEndOfFile()
            let paths = data.split(separator: 0).compactMap { chunk -> String? in
                guard !chunk.isEmpty else { return nil }
                return String(data: Data(chunk), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            }.filter { !$0.isEmpty }
            return paths
        } else {
            // 行流式读取 (支持 AsyncLineSequence)
            for try await line in handle.bytes.lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                // 忽略空行与以 # 开头的注释行
                if trimmed.isEmpty || trimmed.hasPrefix("#") {
                    continue
                }
                results.append(trimmed)
            }
        }
        
        return results
    }
}
