// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import Foundation
@testable import TTZipCore

public enum TimeoutError: Error, CustomStringConvertible, Sendable {
    case timedOut(seconds: TimeInterval, description: String)
    public var description: String {
        switch self {
        case .timedOut(let seconds, let desc):
            return "🚨 [测试超时熔断] 任务 '\(desc)' 执行超过上限 \(seconds) 秒！强行熔断抛出失败，杜绝测试卡主死锁。"
        }
    }
}

extension XCTestCase {
    /// ， timeoutSeconds ( )
    public func withTimeout(
        seconds: TimeInterval = 30.0,
        description: String = "Async Test Operation",
        file: StaticString = #filePath,
        line: UInt = #line,
        _ block: @escaping @Sendable () async throws -> Void
    ) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await block()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError.timedOut(seconds: seconds, description: description)
            }
            
            defer { group.cancelAll() }
            do {
                if let _ = try await group.next() {
                    return
                }
            } catch let err as TimeoutError {
                XCTFail(err.description, file: file, line: line)
                throw err
            } catch {
                throw error
            }
        }
    }
}
