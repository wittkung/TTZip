// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation
import CTTZipBridge

/// 平台硬件热状态异步协调器与 DVFS 防抖调度器 (Swift 6 Isolated Actor)
public actor HardwareThermalCoordinator {
    public static let shared = HardwareThermalCoordinator()
    private init() {}

    private var isMonitoring: Bool = false
    private var monitorTask: Task<Void, Never>?

    public var currentThermalState: ProcessInfo.ThermalState {
        return ProcessInfo.processInfo.thermalState
    }

    /// 启动后台热状态监听 (基于 AsyncSequence 零线程阻塞)
    public func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        // 初始化更新一次底层 C 运行时状态
        let initialRaw = Int32(ProcessInfo.processInfo.thermalState.rawValue)
        ttzip_bridge_set_thermal_state(initialRaw)

        monitorTask = Task.detached(priority: .utility) { [weak self] in
            let notifications = NotificationCenter.default.notifications(
                named: ProcessInfo.thermalStateDidChangeNotification,
                object: nil
            )
            for await _ in notifications {
                let state = ProcessInfo.processInfo.thermalState
                let rawVal = Int32(state.rawValue)
                ttzip_bridge_set_thermal_state(rawVal)
                await self?.handleThermalStateChange(state)
            }
        }
    }

    /// 停止监听
    public func stopMonitoring() {
        isMonitoring = false
        monitorTask?.cancel()
        monitorTask = nil
    }

    private func handleThermalStateChange(_ state: ProcessInfo.ThermalState) {
        // 内部状态同步
    }

    /// 执行自适应硬件冷却等待 (如果热压力过高)
    /// - Parameter maxWaitSeconds: 最大等待超时上限
    /// - Returns: 是否触发了冷却暂停
    @discardableResult
    public func performAdaptiveCooldownIfNeeded(maxWaitSeconds: Double = 30.0) async -> Bool {
        let state = ProcessInfo.processInfo.thermalState
        guard state == .serious || state == .critical else {
            return false
        }

        let startNanos = PlatformMonotonicTimer.nowNanoseconds()
        let maxWaitNanos = UInt64(maxWaitSeconds * 1_000_000_000)

        // 循环检测直到恢复到 .nominal 或超时
        while ProcessInfo.processInfo.thermalState != .nominal {
            let elapsed = PlatformMonotonicTimer.nowNanoseconds() - startNanos
            if elapsed >= maxWaitNanos {
                break
            }
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms 探测一次
        }

        // 恢复到 nominal 后，追加 1.5 秒尾部稳定延迟让 DVFS 稳频
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        return true
    }
}
